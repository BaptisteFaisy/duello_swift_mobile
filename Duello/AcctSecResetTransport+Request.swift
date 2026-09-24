//
//  AcctSecResetTransport+Request.swift
//  Duello
//
//  Port de src/utils/passwordResetHttp.ts (RN) — requête
//  `POST /auth/password/reset` (délai de 8 s, classification des issues) et
//  lecture des réponses.
//
//  Découpage (24/09/2026) : section extraite de `AcctSecResetTransport.swift`
//  (porté du même fichier source). Les messages d'échec HTTP
//  (`authHttpFailureMessage`, `+Failures.swift`) restent appelables ici.
//
//  Cible : iOS 16, aucune dépendance externe.
//
import Foundation

extension AcctSecResetTransport {

    /// `resetServerPassword` : POST puis contrôle d'identité.
    static func resetServerPassword(
        email: String,
        token: String,
        password: String
    ) async throws -> PasswordResetAuthentication {
        let response = try await passwordResetHttp(
            body: ["email": email, "token": token, "password": password]
        )
        return try requirePasswordResetAuthentication(expectedEmail: email, response: response)
    }

    // MARK: Requête et classification

    /// `passwordResetHttp(apiUrl, 'reset', body, { outcomeMayHaveCommitted: true })`.
    private static func passwordResetHttp(body: [String: String]) async throws -> PasswordResetResponse {
        let data: Data
        let http: HTTPURLResponse
        do {
            (data, http) = try await post(body: body)
        } catch let error as URLError {
            throw outcomeUnknownForNetwork(error)
        } catch {
            throw outcomeUnknownForNetwork(nil)
        }

        if (200..<300).contains(http.statusCode) {
            let payload = try successfulPayload(data)
            if payload.session == nil || payload.account == nil {
                throw PasswordResetAuthenticationUnavailableError()
            }
            return payload
        }
        if http.statusCode >= 500 {
            throw PasswordResetOutcomeUnknownError(
                "Le service a perdu la réponse. Le mot de passe a peut-être déjà changé."
            )
        }
        throw DirectoryError(
            message: authHttpFailureMessage(http: http, data: data),
            status: http.statusCode
        )
    }

    /// `postPasswordReset` : POST JSON ; ne lève que sur panne de transport.
    private static func post(body: [String: String]) async throws -> (Data, HTTPURLResponse) {
        let url = DuelloAPI.baseURL.appendingPathComponent("auth/password/reset")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = timeoutSeconds
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        return (data, http)
    }

    /// Panne ou délai dépassé : la réponse a pu committer côté serveur
    /// (`outcomeMayHaveCommitted` pour `reset`), donc issue inconnue.
    private static func outcomeUnknownForNetwork(_ error: URLError?) -> PasswordResetOutcomeUnknownError {
        let message = error?.code == .timedOut
            ? "Le serveur Duello met trop de temps à répondre. Réessaie dans un instant."
            : "Le serveur Duello est injoignable. Vérifie ta connexion puis réessaie."
        return PasswordResetOutcomeUnknownError("\(message) Le mot de passe a peut-être déjà changé.")
    }

    // MARK: Lecture des réponses

    /// `successfulPayload` : une charge utile illisible rend la session
    /// inutilisable (chemin `reset`).
    private static func successfulPayload(_ data: Data) throws -> PasswordResetResponse {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw PasswordResetAuthenticationUnavailableError()
        }
        return PasswordResetResponse(
            accepted: root["accepted"] as? Bool ?? false,
            session: validResetSession(root["session"]),
            account: validRecoveredAccount(root["account"])
        )
    }

    /// `validResetSession` : jeton `dus_`, expiration future, identifiants non vides.
    private static func validResetSession(_ value: Any?) -> ServerSession? {
        guard let dict = value as? [String: Any],
              let token = dict["token"] as? String, token.hasPrefix("dus_"),
              let expiresAt = dict["expiresAt"] as? String,
              let expires = ISO8601DateFormatter.date(fromISO: expiresAt), expires > Date(),
              let publicId = dict["publicId"] as? String, !publicId.isEmpty,
              let email = dict["email"] as? String, !email.isEmpty else {
            return nil
        }
        return ServerSession(token: token, expiresAt: expiresAt, publicId: publicId, email: email)
    }

    /// `validRecoveredAccount` : e-mail et nom non vides, sujets Google/Apple
    /// nuls ou chaînes, date de création finie, profil présent. Le profil n'est
    /// pas modélisé ici (lu par le rattachement au compte côté appelant).
    private static func validRecoveredAccount(_ value: Any?) -> RecoveredServerAccount? {
        guard let dict = value as? [String: Any],
              let email = dict["email"] as? String, !email.isEmpty,
              let displayName = dict["displayName"] as? String, !displayName.isEmpty,
              isNullableString(dict["googleSubject"]),
              isNullableString(dict["appleSubject"]),
              let createdAt = dict["createdAt"] as? Double, createdAt.isFinite,
              dict["profile"] is [String: Any] else {
            return nil
        }
        return RecoveredServerAccount(
            email: email,
            displayName: displayName,
            googleSubject: dict["googleSubject"] as? String,
            appleSubject: dict["appleSubject"] as? String,
            createdAt: createdAt
        )
    }

    /// `googleSubject`/`appleSubject` : `null` ou chaîne (`String?`).
    private static func isNullableString(_ value: Any?) -> Bool {
        value == nil || value is NSNull || value is String
    }
}
