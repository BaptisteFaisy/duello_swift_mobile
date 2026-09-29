//
//  PushNotifLogout.swift
//  Duello
//
//  Lot T06 (vague 4 « couche transverse ») — TR-06 : révocation des
//  notifications poussées à la déconnexion.
//
//  Fichier source Expo porté (ordre et règles repris mot pour mot) :
//    - src/utils/pushNotificationSync.ts
//        · `revokePushNotificationInstallationNow` (désinscription native puis
//          révocation distante de chaque jeton, oubli local en dernier) ;
//        · `revokePushNotificationInstallation` (file sérialisée du compte) ;
//        · `preparePushNotificationLogout` (suspend, révoque, reprend sur échec) ;
//        · `detachPushNotificationsForLogout` (suspend, révoque en tâche de fond
//          puis révoque la session, sans retarder l'interface).
//
//  `SessionStore.signOut()` ne faisait que `DuelloAPI.logout` ; ce module apporte
//  la révocation des jetons. `PushNotifCoordinator.revokeNow` reste privé : ce
//  fichier recompose la même séquence à partir de `PushNotifNative`,
//  `PushNotifAPI`, `PushNotifReconciliation` et `PushNotifTokenStore`.
//
//  Cible : iOS 16, aucune API iOS 17.
//
import Foundation

/// Révocation push à la déconnexion (`pushNotificationSync.ts`).
enum PushNotifLogout {

    /// `revokePushNotificationInstallationNow` : désinscription native, puis
    /// révocation distante de chaque jeton suivi, puis oubli local.
    @MainActor
    static func revokeNow(
        store: PushNotifTokenStore,
        profile: UserProfile,
        registerRemotely: @escaping () -> Bool,
        sessionToken: @escaping () -> String?
    ) async -> PushNotifUnregistrationResult {
        let nativeUnregistered: Bool = await PushNotifNative.unregisterNative()
        let unregistration = PushNotifUnregistration(
            tokens: store.state.trackedTokens,
            nativeUnregistered: nativeUnregistered
        )
        let actions = PushNotifUnregistrationActions(
            unregisterRemotely: { token in
                guard registerRemotely() else { return }
                try await PushNotifAPI.unregisterToken(
                    profile: profile,
                    token: token,
                    sessionToken: sessionToken()
                )
            },
            forgetLocally: { store.forget() }
        )
        return await PushNotifReconciliation.commitUnregistration(
            unregistration,
            actions: actions
        )
    }

    /// `revokePushNotificationInstallation` : révoque dans la file sérialisée du
    /// compte, en forçant malgré une suspension.
    @MainActor
    static func revokeInstallation(
        queue: PushNotifOperationQueue,
        accountId: String,
        store: PushNotifTokenStore,
        profile: UserProfile,
        registerRemotely: @escaping () -> Bool,
        sessionToken: @escaping () -> String?
    ) async throws -> PushNotifUnregistrationResult {
        let result = try await queue.enqueue(accountId, allowWhileSuspended: true) {
            await revokeNow(
                store: store,
                profile: profile,
                registerRemotely: registerRemotely,
                sessionToken: sessionToken
            )
        }
        guard let result else { throw DirectoryError(message: "Révocation push interrompue.") }
        return result
    }

    /// `preparePushNotificationLogout` : suspend, révoque, et ne reprend qu'en cas
    /// d'échec — les notifications du téléphone restent inscrites sinon.
    @MainActor
    static func prepareLogout(
        queue: PushNotifOperationQueue,
        accountId: String,
        store: PushNotifTokenStore,
        profile: UserProfile,
        registerRemotely: @escaping () -> Bool,
        sessionToken: @escaping () -> String?
    ) async throws {
        queue.suspend(accountId)
        do {
            let cleanup = try await revokeInstallation(
                queue: queue, accountId: accountId, store: store, profile: profile,
                registerRemotely: registerRemotely, sessionToken: sessionToken
            )
            if cleanup.retryNeeded && cleanup.trackedTokenCount > 0 {
                throw DirectoryError(message: "Les notifications du téléphone restent inscrites.")
            }
        } catch {
            queue.resume(accountId)
            throw error
        }
    }

    /// `detachPushNotificationsForLogout` : détache le téléphone du compte sans
    /// retarder l'interface — suspension immédiate, puis révocation des jetons et
    /// de la session en tâche de fond. Un échec réseau ne bloque pas la
    /// déconnexion déjà affichée.
    @MainActor
    static func detachForLogout(
        queue: PushNotifOperationQueue,
        accountId: String,
        store: PushNotifTokenStore,
        profile: UserProfile,
        sessionToken: String?,
        registerRemotely: @escaping () -> Bool
    ) {
        queue.suspend(accountId)
        Task { @MainActor in
            defer { queue.resume(accountId) }
            let cleanup = await revokeNow(
                store: store,
                profile: profile,
                registerRemotely: registerRemotely,
                sessionToken: { sessionToken }
            )
            if cleanup.retryNeeded && cleanup.trackedTokenCount > 0 { return }
            if let sessionToken, !sessionToken.isEmpty {
                await DuelloAPI.logout(token: sessionToken)
            }
        }
    }
}
