import Foundation

// Port des appels réseau de reconnexion d'appareil de `src/utils/serverSession.ts` :
// `enrollServerDeviceRecovery` (`POST /auth/device/enroll`) et
// `restoreServerSessionFromDevice` (`POST /auth/device/restore`). Les chemins
// d'endpoint sont repris tels quels de la source.

/// Corps partagé des appels d'appareil (`{ deviceId, recoverySecret, email? }`).
struct DevRegDeviceProof: Encodable {
    var deviceId: String
    var recoverySecret: String?
    var email: String?
}

/// Compte renvoyé par `POST /auth/device/restore` (`RecoveredServerAccount`).
struct DevRegRecoveryRestoredAccount: Decodable {
    var email: String
    var displayName: String?
    var googleSubject: String?
    var appleSubject: String?
    var createdAt: Double?
    var profile: UserProfile?
}

/// Réponse de `POST /auth/device/restore` (`{ session?, account? }`).
struct DevRegRecoveryRestorePayload: Decodable {
    var session: ServerSession?
    var account: DevRegRecoveryRestoredAccount?
}

/// Erreur d'appareil, alignée sur `ServerSessionRequestError` de la source.
enum DevRegRecoveryError: LocalizedError {
    case sessionRequired
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .sessionRequired:
            return "Ta session Duello doit être reconnectée avant d’activer la biométrie."
        case .invalidResponse:
            return "Le serveur n’a pas renvoyé le compte biométrique attendu."
        }
    }
}

extension DevRegRecovery {
    /// Active la reconnexion biométrique de l'appareil pour un compte
    /// (`enrollServerDeviceRecovery`, `POST /auth/device/enroll`). Une session
    /// serveur valide est requise : sans elle, le serveur répond 401.
    static func enroll(deviceId: String, recoverySecret: String?, token: String) async throws {
        let body = try DuelloAPI.encodeBody(
            DevRegDeviceProof(deviceId: deviceId, recoverySecret: recoverySecret, email: nil)
        )
        _ = try await DuelloAPI.request(
            "auth/device/enroll",
            method: "POST",
            token: token,
            body: body
        )
    }

    /// Rejoue la session d'un compte à partir de la preuve locale
    /// (`restoreServerSessionFromDevice`, `POST /auth/device/restore`).
    ///
    /// Limite : la source persiste la session reçue (`saveServerSession`) ; ici
    /// la session est renvoyée à l'appelant, `SessionStore` (fichier partagé,
    /// non modifiable) restant la seule autorité sur la session active.
    static func restore(
        deviceId: String,
        recoverySecret: String?,
        email: String?
    ) async throws -> (session: ServerSession, account: DevRegRecoveryRestoredAccount) {
        let body = try DuelloAPI.encodeBody(
            DevRegDeviceProof(deviceId: deviceId, recoverySecret: recoverySecret, email: email)
        )
        let payload = try await DuelloAPI.request(
            DevRegRecoveryRestorePayload.self,
            "auth/device/restore",
            method: "POST",
            body: body
        )
        guard let session = payload.session,
              let account = payload.account,
              !account.email.isEmpty else {
            throw DevRegRecoveryError.invalidResponse
        }
        return (session, account)
    }
}
