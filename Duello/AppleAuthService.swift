//
//  AppleAuthService.swift
//  Duello
//
//  Échange de la preuve Apple contre une session Duello, porté depuis l'app
//  Expo. Fichiers source :
//    - src/utils/appleAuth.ts            (`verifyAppleIdentityToken`,
//                                         `APPLE_AUTH_TIMEOUT_MS`,
//                                         `responseError`, `networkError`,
//                                         `requireCompleteProof`)
//    - src/components/AppleAuthButton.tsx (`Crypto.randomUUID()`, ordre des
//                                         scopes `FULL_NAME` puis `EMAIL`)
//
//  L'appel natif (SDK Apple) est isolé derrière `AppleAuthService.signIn()`,
//  qui délègue à `AppleAuthProvider` sous `#if canImport(AuthenticationServices)`.
//  La partie serveur (`verify`) est portable et testable : elle n'a besoin
//  d'aucune API Apple.
//
//  Cible : iOS 16. Aucune dépendance externe.
//

import Foundation

/// Résultat complet d'une connexion Apple : identité nettoyée par le serveur
/// et session Duello à ouvrir (`ServerSession` côté `SessionStore`).
struct AppleAuthResult {
    var identity: AppleAuthIdentity
    var session: DuelloAPI.SessionPayload
}

/// Envelope de `POST /auth/apple`, calquée sur `GoogleAuthEnvelope`.
struct AppleAuthEnvelope: Decodable {
    var identity: AppleAuthIdentityEnvelope?
    var session: DuelloAPI.SessionPayload?
    var error: String?
}

/// Connexion Apple (`AppleAuthButton.tsx` + `utils/appleAuth.ts`). Le SDK
/// Apple fournit la preuve, le serveur Duello la transforme en session : le
/// jeton part à `POST /auth/apple` et seul le serveur décide de l'identité.
enum AppleAuthService {
    /// Délai serveur, comme `APPLE_AUTH_TIMEOUT_MS` (10 s) côté Expo.
    private static let timeout: TimeInterval = 10

    /// Ouvre la boîte de dialogue native et renvoie la preuve Apple
    /// (`nonce` = UUID, scopes nom + e-mail, comme le bouton Expo).
    ///
    /// Limite assumée : `AuthenticationServices` n'existe pas hors Apple.
    /// Quand la brique manque, une erreur claire et documentée est renvoyée.
    static func signIn() async throws -> AppleAuthCredential {
        #if canImport(AuthenticationServices)
        return try await AppleAuthProvider.requestCredential()
        #else
        throw AppleAuthError.unavailable("La connexion Apple nécessite iOS : l’authentification native est indisponible sur cette plateforme.")
        #endif
    }

    /// Échange la preuve contre une session (`POST /auth/apple`), exactement
    /// comme `verifyAppleIdentityToken` (Expo, délai 10 s). Le serveur
    /// contrôle le jeton, puis arbitre les comptes en transaction.
    static func verify(
        _ credential: AppleAuthCredential,
        username: String? = nil
    ) async throws -> AppleAuthResult {
        try requireCompleteProof(credential)
        let request = try appleAuthRequest(credential, username: username)
        let (data, http) = try await appleAuthTransport(request)
        let envelope = try? DuelloAPI.decoder.decode(AppleAuthEnvelope.self, from: data)

        guard (200..<300).contains(http.statusCode) else {
            let message = (envelope?.error ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            throw AppleAuthError.server(
                message.isEmpty ? "Connexion Apple indisponible (\(http.statusCode))." : message,
                status: http.statusCode
            )
        }
        guard let identityEnvelope = envelope?.identity else {
            let message = (envelope?.error ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if !message.isEmpty {
                throw AppleAuthError.server(message, status: http.statusCode)
            }
            throw AppleAuthError.invalidIdentity("Apple n’a pas renvoyé une identité exploitable.")
        }
        guard let session = envelope?.session else {
            throw AppleAuthError.server("Le serveur n’a pas créé de session Duello.", status: http.statusCode)
        }
        return AppleAuthResult(identity: try AppleAuthIdentity.parse(identityEnvelope), session: session)
    }

    /// Parcours complet du bouton : preuve native puis vérification serveur.
    static func authenticate(username: String? = nil) async throws -> AppleAuthResult {
        let credential = try await signIn()
        return try await verify(credential, username: username)
    }

    // MARK: Transport

    /// `requireCompleteProof` : le serveur exige code, jeton et nonce.
    private static func requireCompleteProof(_ proof: AppleAuthCredential) throws {
        guard !proof.authorizationCode.trimmingCharacters(in: .whitespaces).isEmpty,
              !proof.identityToken.trimmingCharacters(in: .whitespaces).isEmpty,
              !proof.nonce.trimmingCharacters(in: .whitespaces).isEmpty
        else {
            throw AppleAuthError.invalidIdentity("Apple n’a pas fourni de preuve de connexion.")
        }
    }

    /// Construit la requête `POST /auth/apple` : preuve + `deviceId` +
    /// `username` facultatif, comme le corps JSON d'`appleAuth.ts`.
    private static func appleAuthRequest(_ credential: AppleAuthCredential, username: String?) throws -> URLRequest {
        struct Body: Encodable {
            var authorizationCode: String
            var identityToken: String
            var nonce: String
            var firstName: String?
            var lastName: String?
            var deviceId: String
            var username: String?
        }
        let body = try DuelloAPI.encodeBody(Body(
            authorizationCode: credential.authorizationCode,
            identityToken: credential.identityToken,
            nonce: credential.nonce,
            firstName: credential.firstName,
            lastName: credential.lastName,
            deviceId: SessionStore.deviceId(),
            username: username
        ))

        var request = URLRequest(url: DuelloAPI.baseURL.appendingPathComponent("auth/apple"))
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        return request
    }

    /// Transport de `verify` : toute panne réseau devient une
    /// `AppleAuthError.network`, y compris la réponse non HTTP
    /// (`URLError.badServerResponse`), comme `networkError` côté Expo.
    private static func appleAuthTransport(_ request: URLRequest) async throws -> (data: Data, http: HTTPURLResponse) {
        do {
            let (payload, response) = try await URLSession.shared.data(for: request)
            guard let urlResponse = response as? HTTPURLResponse else {
                throw URLError(.badServerResponse)
            }
            return (payload, urlResponse)
        } catch let error as URLError where error.code == .timedOut {
            throw AppleAuthError.network("Le serveur Duello met trop de temps à vérifier Apple.")
        } catch {
            throw AppleAuthError.network("Le serveur Duello est injoignable. Vérifie ta connexion.")
        }
    }
}
