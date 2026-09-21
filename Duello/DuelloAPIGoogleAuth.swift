import Foundation

// Découpage de `DuelloAPI.swift` — connexion Google : échange du jeton Google
// contre une session Duello. Aucun type, membre ni signature renommé.

extension DuelloAPI {
    // MARK: Connexion Google

    /// Envelope de la réponse `POST /auth/google`.
    struct GoogleAuthEnvelope: Decodable {
        var identity: GoogleIdentityEnvelope?
        var session: SessionPayload?
        var error: String?
    }

    /// Identité telle que renvoyée par le serveur, avant la revalidation
    /// stricte de `GoogleIdentity.parse` (miroir de `parseGoogleIdentity`).
    struct GoogleIdentityEnvelope: Decodable {
        var subject: String?
        var email: String?
        var displayName: String?
        var firstName: String?
        var lastName: String?
        var photoUrl: String?
    }

    /// `POST /auth/google` — échange le jeton Google contre une session
    /// Duello, exactement comme `verifyGoogleIdToken` (Expo, délai 10 s).
    /// Le serveur contrôle la signature, les audiences, l'émetteur,
    /// l'expiration et l'e-mail vérifié avant d'ouvrir la session ; le
    /// client ne décode jamais le jeton lui-même.
    static func googleAuth(
        idToken: String,
        deviceId: String,
        username: String?
    ) async throws -> (identity: GoogleIdentity, session: SessionPayload) {
        struct Body: Encodable {
            var idToken: String
            var deviceId: String
            var username: String?
        }
        guard !idToken.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw GoogleAuthError.invalidIdentity("Google n'a pas fourni de preuve de connexion.")
        }
        let body = try encodeBody(Body(idToken: idToken, deviceId: deviceId, username: username))

        var request = URLRequest(url: baseURL.appendingPathComponent("auth/google"))
        request.httpMethod = "POST"
        request.timeoutInterval = 10
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body

        let (data, http) = try await googleAuthTransport(request)

        let envelope = try? decoder.decode(GoogleAuthEnvelope.self, from: data)
        guard (200..<300).contains(http.statusCode) else {
            let serverMessage = envelope?.error?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let message = serverMessage.isEmpty ? "Connexion Google indisponible (\(http.statusCode))." : serverMessage
            throw GoogleAuthError.server(message, status: http.statusCode)
        }
        guard let identityEnvelope = envelope?.identity else {
            if let message = envelope?.error?.trimmingCharacters(in: .whitespacesAndNewlines), !message.isEmpty {
                throw GoogleAuthError.server(message, status: http.statusCode)
            }
            throw GoogleAuthError.invalidIdentity("Google n'a pas renvoyé une identité exploitable.")
        }
        let identity = try GoogleIdentity.parse(identityEnvelope)
        guard let session = envelope?.session else {
            throw GoogleAuthError.server("Le serveur n'a pas créé de session Duello.", status: http.statusCode)
        }
        return (identity, session)
    }

    /// Transport de `googleAuth` : toute panne réseau devient une
    /// `GoogleAuthError.network`, y compris la réponse non HTTP
    /// (`URLError.badServerResponse`), comme dans le `do/catch` d'origine.
    private static func googleAuthTransport(_ request: URLRequest) async throws -> (data: Data, http: HTTPURLResponse) {
        do {
            let (payload, response) = try await URLSession.shared.data(for: request)
            guard let urlResponse = response as? HTTPURLResponse else {
                throw URLError(.badServerResponse)
            }
            return (payload, urlResponse)
        } catch let error as URLError where error.code == .timedOut {
            throw GoogleAuthError.network("Le serveur Duello met trop de temps à vérifier Google.")
        } catch {
            throw GoogleAuthError.network("Le serveur Duello est injoignable. Vérifie ta connexion.")
        }
    }
}
