import Foundation

// Découpage de `DuelloAPI.swift` — comptes et identité : identifiant public,
// charge utile de session et points d'entrée mot de passe
// (voir `serverSession.ts`). Aucun type, membre ni signature renommé.

extension DuelloAPI {
    /// Identifiant public d'un compte : FNV-1a 32 bits de l'e-mail normalisé,
    /// préfixé `member-` (aligné sur `publicProfileId` de `socialApi.ts`, qui
    /// hache les unités de code UTF-16 de `charCodeAt`).
    static func publicProfileId(email: String) -> String {
        let normalized = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let units = Array(normalized.utf16)
        var hash: UInt32 = 0x811c9dc5
        for unit in units {
            hash ^= UInt32(unit)
            hash = hash &* 0x01000193
        }
        return String(format: "member-%x", hash)
    }

    // MARK: Authentification (voir serverSession.ts)

    struct SessionPayload: Codable {
        var token: String
        var expiresAt: String
        var publicId: String
        var email: String
    }

    struct AuthResponse: Decodable {
        var session: SessionPayload?
        var account: AccountPayload?
        var error: String?
    }

    struct AccountPayload: Decodable {
        var email: String?
        var displayName: String?
        var profile: UserProfile?
    }

    /// Réponse d'authentification : session **et** profil serveur.
    ///
    /// `account.profile` porte `track`/`year` — la jeter (comme avant) laissait
    /// `SessionStore.profile` vide après une connexion, si bien que `RootView`
    /// renvoyait un élève pourtant inscrit vers l'onboarding
    /// (`needsOnboarding`). C'est le profil de la source Expo
    /// (`saveAccount(account)` de `login`/`authenticateWithGoogle`).
    struct AuthResult {
        var session: SessionPayload
        var profile: UserProfile?
    }

    /// `POST /auth/password/login`
    static func login(email: String, password: String) async throws -> AuthResult {
        let body = try encodeBody(["email": email, "password": password])
        let response = try await request(
            AuthResponse.self,
            "auth/password/login",
            method: "POST",
            body: body
        )
        guard let session = response.session else {
            throw DirectoryError(message: response.error ?? "Authentification Duello indisponible.")
        }
        return AuthResult(session: session, profile: response.account?.profile)
    }

    /// `POST /auth/password/register`
    static func register(email: String, password: String, displayName: String, deviceId: String) async throws -> AuthResult {
        let body = try encodeBody([
            "email": email,
            "password": password,
            "displayName": displayName,
            "deviceId": deviceId,
        ])
        let response = try await request(
            AuthResponse.self,
            "auth/password/register",
            method: "POST",
            body: body
        )
        guard let session = response.session else {
            throw DirectoryError(message: response.error ?? "La création du compte est momentanément indisponible.")
        }
        return AuthResult(session: session, profile: response.account?.profile)
    }

    /// `POST /auth/logout`
    static func logout(token: String) async {
        _ = try? await request("auth/logout", method: "POST", token: token, body: Data("{}".utf8))
    }
}
