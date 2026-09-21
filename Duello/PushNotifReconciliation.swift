import Foundation

// Réconciliation locale/distante des jetons de notification poussée.
//
// Source Expo portée : `src/utils/pushNotificationReconciliation.ts`.
//
// Pur et portable : les effets (réseau, persistance) sont injectés sous forme
// de fermetures, comme les `RegistrationActions` / `UnregistrationActions`
// d'Expo. Les décisions d'ordre — enregistrer d'abord, révoquer ensuite,
// confirmer localement en dernier — sont ici.

// MARK: - Modèles

/// Résolution d'un jeton (`PushNotificationTokenResolution`).
struct PushNotifTokenResolution: Equatable {
    var token: String?
    var staleTokens: [String]
}

/// Désinscription native (`PushNotificationUnregistration`).
struct PushNotifUnregistration: Equatable {
    var tokens: [String]
    var nativeUnregistered: Bool
}

/// Résultat d'une désinscription (`PushNotificationUnregistrationResult`).
struct PushNotifUnregistrationResult: Equatable {
    var nativeUnregistered: Bool
    var remoteUnregistered: Bool
    var retryNeeded: Bool
    var trackedTokenCount: Int
}

/// Actions d'enregistrement, injectées (`RegistrationActions`).
struct PushNotifRegistrationActions {
    var registerRemotely: (String) async throws -> Void
    var unregisterRemotely: (String) async throws -> Void
    var confirmLocally: (String) async throws -> Void
}

/// Actions de désinscription, injectées (`UnregistrationActions`).
struct PushNotifUnregistrationActions {
    var unregisterRemotely: (String) async throws -> Void
    var forgetLocally: () async throws -> Void
}

// MARK: - Réconciliation

/// Réconciliation pure, calquée sur `pushNotificationReconciliation.ts`.
enum PushNotifReconciliation {

    /// Enregistre le nouveau jeton, révoque ensuite les anciens, puis confirme
    /// localement. Renvoie `true` si une reprise est nécessaire : un échec
    /// conserve le curseur de reprise.
    static func commitRegistration(
        _ resolution: PushNotifTokenResolution,
        actions: PushNotifRegistrationActions
    ) async -> Bool {
        guard let token = resolution.token else { return false }
        do {
            try await actions.registerRemotely(token)
            for stale in resolution.staleTokens {
                try await actions.unregisterRemotely(stale)
            }
            try await actions.confirmLocally(token)
            return false
        } catch {
            return true
        }
    }

    /// Tente la révocation distante même si la native échoue ; n'oublie le
    /// jeton local qu'après le succès de toutes les opérations.
    static func commitUnregistration(
        _ unregistration: PushNotifUnregistration,
        actions: PushNotifUnregistrationActions
    ) async -> PushNotifUnregistrationResult {
        var remoteUnregistered = true
        for token in unregistration.tokens {
            do {
                try await actions.unregisterRemotely(token)
            } catch {
                remoteUnregistered = false
            }
        }

        let nativeUnregistered =
            unregistration.nativeUnregistered || unregistration.tokens.isEmpty
        let count = unregistration.tokens.count

        if !nativeUnregistered || !remoteUnregistered {
            return PushNotifUnregistrationResult(
                nativeUnregistered: nativeUnregistered,
                remoteUnregistered: remoteUnregistered,
                retryNeeded: true,
                trackedTokenCount: count
            )
        }

        do {
            try await actions.forgetLocally()
            return PushNotifUnregistrationResult(
                nativeUnregistered: nativeUnregistered,
                remoteUnregistered: remoteUnregistered,
                retryNeeded: false,
                trackedTokenCount: count
            )
        } catch {
            return PushNotifUnregistrationResult(
                nativeUnregistered: nativeUnregistered,
                remoteUnregistered: remoteUnregistered,
                retryNeeded: true,
                trackedTokenCount: count
            )
        }
    }
}
