import Foundation
import Combine

// Coordinateur des notifications poussées : enregistrement du jeton d'appareil
// et envoi au serveur, avec file d'attente sérialisée et boucle de reprise.
//
// Sources Expo portées : `src/components/PushNotificationCoordinator.tsx`
// (cycle de vie + boucle), `src/utils/pushNotificationSync.ts` (synchronisation
// et révocation), `pushNotifications.ts` (`ensurePushNotificationToken`) et
// `pushNotificationTokenState.ts` (journal local).
//
// Le cœur est portable (Foundation/Combine). L'usage réel de
// `UNUserNotificationCenter` et d'APNs est isolé dans `PushNotifNative`
// (`PushNotifNative.swift`, non portable) : sous Linux il est absent, et le
// pré-contrôle de types le rapporte « hors couverture » sans échouer.

// MARK: - Coordinateur

/// Coordinateur d'enregistrement des notifications poussées.
@MainActor
final class PushNotifCoordinator: ObservableObject {

    /// Statut agrégé affiché par l'interface.
    @Published private(set) var status: PushNotifTrackerStatus = .loading
    /// Permission système courante.
    @Published private(set) var permission: PushNotifPermission = .undetermined
    /// Nombre de jetons encore suivis localement.
    @Published private(set) var trackedTokenCount: Int = 0
    /// Dernière erreur empêchant la synchronisation, s'il y en a une.
    @Published private(set) var lastError: String?

    private let store: PushNotifTokenStore
    private let queue = PushNotifOperationQueue()
    private let accountId: String
    private let preference: () -> Bool
    private let registerRemotely: () -> Bool
    private var profile: UserProfile
    private var loop: PushNotifRetryLoop?

    /// - Parameters:
    ///   - profile: profil courant, source de l'identifiant public.
    ///   - accountId: identifiant du compte, clé de la file sérialisée.
    ///   - preference: lit la préférence « notifications poussées ».
    ///   - registerRemotely: vrai si l'app doit inscrire le jeton au serveur.
    ///   - store: journal local des jetons.
    init(
        profile: UserProfile,
        accountId: String,
        preference: @escaping () -> Bool,
        registerRemotely: @escaping () -> Bool,
        store: PushNotifTokenStore = PushNotifTokenStore()
    ) {
        self.profile = profile
        self.accountId = accountId
        self.preference = preference
        self.registerRemotely = registerRemotely
        self.store = store
        refreshStatus()
    }

    // MARK: Lecture

    /// Jeton d'appareil courant, pour l'affichage.
    var currentToken: String? { store.state.currentToken }

    // MARK: Cycle de vie

    /// Démarre la boucle de synchronisation et lance une première passe.
    func start() {
        queue.resume(accountId)
        let loop = PushNotifRetryLoop { [weak self] in
            guard let self else { return false }
            return await self.synchronize()
        }
        self.loop = loop
        refreshStatus()
        loop.request()
    }

    /// Arrête la boucle et suspend la file (déconnexion en cours).
    func stop() {
        loop?.stop()
        loop = nil
        queue.suspend(accountId)
    }

    /// Enregistre un jeton d'appareil reçu du système, puis relance la
    /// synchronisation. Point d'entrée de l'`AppDelegate`.
    func acceptDeviceToken(_ hexToken: String) {
        guard PushNotifTokenJournal.isValidToken(hexToken) else { return }
        store.stage(token: hexToken)
        refreshStatus()
        loop?.request()
    }

    // MARK: Synchronisation

    /// Une passe : inscription si la préférence est active, révocation sinon.
    /// Renvoie `true` si une reprise est nécessaire.
    @discardableResult
    func synchronize() async -> Bool {
        let current: PushNotifPermission = await PushNotifNative.currentPermission()
        permission = current
        do {
            let retryNeeded = try await queue.enqueue(accountId, allowWhileSuspended: true) {
                try await self.reconcileNow()
            }
            lastError = nil
            refreshStatus()
            return retryNeeded ?? false
        } catch {
            lastError = (error as? LocalizedError)?.errorDescription
                ?? "Synchronisation des notifications interrompue."
            refreshStatus()
            return true
        }
    }

    // MARK: Interne

    /// Décide entre inscription et révocation, puis réconcilie local/distant.
    private func reconcileNow() async throws -> Bool {
        guard preference() else {
            let result = await revokeNow()
            return result.retryNeeded
        }
        let resolution = await ensureToken()
        let actions = PushNotifRegistrationActions(
            registerRemotely: { [profile, registerRemotely] token in
                guard registerRemotely() else { return }
                try await PushNotifAPI.registerToken(profile: profile, token: token)
            },
            unregisterRemotely: { [profile] token in
                try await PushNotifAPI.unregisterToken(profile: profile, token: token)
            },
            confirmLocally: { [store] token in
                store.confirm(token: token)
            }
        )
        let retryNeeded = await PushNotifReconciliation.commitRegistration(
            resolution,
            actions: actions
        )
        let undetermined: Bool = await PushNotifNative.isPermissionUndetermined()
        return retryNeeded || undetermined
    }

    /// Demande la permission puis résout le jeton d'appareil
    /// (`ensurePushNotificationToken`) : rien à faire sans permission accordée.
    private func ensureToken() async -> PushNotifTokenResolution {
        let granted: PushNotifPermission = await PushNotifNative.requestPermission()
        permission = granted
        guard granted == .granted else {
            return PushNotifTokenResolution(token: nil, staleTokens: [])
        }
        // Autorisation acquise : on demande l'enregistrement APNs ; le jeton
        // arrivera par l'`AppDelegate`, puis `acceptDeviceToken(_:)`.
        PushNotifNative.registerForRemoteNotifications()
        let deviceToken: String? = await PushNotifNative.currentDeviceToken()
        guard let token = deviceToken, PushNotifTokenJournal.isValidToken(token) else {
            return PushNotifTokenResolution(token: nil, staleTokens: [])
        }
        let staged = store.stage(token: token)
        return PushNotifTokenResolution(
            token: token,
            staleTokens: staged.trackedTokens.filter { $0 != token }
        )
    }

    /// Révoque l'inscription native puis chaque jeton suivi auprès du serveur.
    private func revokeNow() async -> PushNotifUnregistrationResult {
        let nativeUnregistered: Bool = await PushNotifNative.unregisterNative()
        let unregistration = PushNotifUnregistration(
            tokens: store.state.trackedTokens,
            nativeUnregistered: nativeUnregistered
        )
        let actions = PushNotifUnregistrationActions(
            unregisterRemotely: { [profile, registerRemotely] token in
                guard registerRemotely() else { return }
                try await PushNotifAPI.unregisterToken(profile: profile, token: token)
            },
            forgetLocally: { [store] in
                store.forget()
            }
        )
        return await PushNotifReconciliation.commitUnregistration(
            unregistration,
            actions: actions
        )
    }

    /// Recalcule le statut agrégé et le nombre de jetons suivis.
    private func refreshStatus() {
        trackedTokenCount = store.state.trackedTokens.count
        status = PushNotifPolicy.trackerStatus(
            preference: preference(),
            permission: permission
        )
    }
}
