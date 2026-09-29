//
//  DevRegBiometricRegister.swift
//  Duello
//
//  Port de `registerServerBiometric` de `src/utils/serverSession.ts` :
//  inscription biométrique du compte (`POST /auth/biometric/register`). La
//  preuve de reconnexion d'appareil est délivrée ici (`createSecret: true`),
//  puis transmise au serveur avec l'e-mail et le nom d'affichage.
//
//  Limite : la source persiste la session reçue (`saveServerSession`) ; ici la
//  session est renvoyée à l'appelant, `SessionStore` restant la seule autorité
//  sur la session active — même choix que `DevRegRecoveryNetwork.swift`
//  (`restore`).
//
//  Fichier source Expo porté : src/utils/serverSession.ts — registerServerBiometric
//  Cible : iOS 16, aucune dépendance externe.
//
import Foundation

extension DevRegRecovery {

    /// Réponse de `POST /auth/biometric/register` (`{ session? }`).
    struct DevRegBiometricSessionPayload: Decodable {
        var session: ServerSession?
    }

    /// Corps de `POST /auth/biometric/register` (`{ email, displayName,
    /// deviceId, recoverySecret }`).
    struct DevRegBiometricRegisterRequest: Encodable {
        var email: String
        var displayName: String
        var deviceId: String
        var recoverySecret: String?
    }

    /// Inscription biométrique du compte (`registerServerBiometric`). Délivre
    /// (ou retrouve) le secret d'appareil du compte, appelle le serveur, et
    /// renvoie la session validée à l'appelant.
    static func registerServerBiometric(
        email: String,
        displayName: String,
        localAccountId: String
    ) async throws -> ServerSession {
        let deviceRecovery = proof(
            createSecret: true,
            accountId: localAccountId,
            accountEmail: email
        )
        let body = try DuelloAPI.encodeBody(
            DevRegBiometricRegisterRequest(
                email: email,
                displayName: displayName,
                deviceId: deviceRecovery.deviceId,
                recoverySecret: deviceRecovery.recoverySecret
            )
        )
        let request = biometricRegisterRequest(body: body)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw biometricNetworkError(error)
        }

        // `payload` : `response.clone().json().catch(() => ({}))` de la source,
        // un corps illisible retombe sur un objet vide (`session` absent).
        let payload = (try? DuelloAPI.decoder.decode(
            DevRegBiometricSessionPayload.self,
            from: data
        )) ?? DevRegBiometricSessionPayload(session: nil)

        let http = response as? HTTPURLResponse
        guard let http, (200..<300).contains(http.statusCode), let session = payload.session else {
            throw biometricRequestError(http: http, data: data)
        }
        return session
    }

    // MARK: Requête

    /// `POST /auth/biometric/register`, délai de 8 s (`AbortSignal.timeout(8_000)`).
    private static func biometricRegisterRequest(body: Data) -> URLRequest {
        var request = URLRequest(
            url: DuelloAPI.baseURL.appendingPathComponent("auth/biometric/register")
        )
        request.httpMethod = "POST"
        request.timeoutInterval = 8
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        return request
    }

    // MARK: Échecs

    /// `serverSessionNetworkError(error, 'création')` : expiration du délai ou
    /// serveur injoignable, sans statut HTTP.
    private static func biometricNetworkError(_ error: Error) -> DirectoryError {
        let timedOut = (error as? URLError)?.code == .timedOut
            || error.localizedDescription.lowercased().contains("timed out")
        let message = timedOut
            ? "Le serveur Duello met trop de temps pendant la création biométrique."
            : "Le serveur Duello est injoignable. Vérifie ta connexion puis réessaie."
        return DirectoryError(message: message, status: nil)
    }

    /// `serverSessionRequestError(response, …)` → `authHttpFailure` : quota 429,
    /// sinon l'`error` du corps (rognée), sinon le repli de création.
    private static func biometricRequestError(http: HTTPURLResponse?, data: Data) -> DirectoryError {
        let status = http?.statusCode
        if status == 429 {
            return DirectoryError(message: rateLimitMessage(retryAfterSeconds(http)), status: status)
        }
        if let payload = try? DuelloAPI.decoder.decode(DirectoryError.self, from: data) {
            return DirectoryError(message: payload.message, status: status)
        }
        return DirectoryError(
            message: "La création biométrique du compte est momentanément indisponible.",
            status: status
        )
    }

    /// `retryAfterSeconds` : en-tête `Retry-After` numérique ou date ISO.
    private static func retryAfterSeconds(_ http: HTTPURLResponse?) -> Int? {
        guard let raw = http?.value(forHTTPHeaderField: "Retry-After")?
            .trimmingCharacters(in: .whitespaces), !raw.isEmpty else { return nil }
        if let seconds = Double(raw), seconds.isFinite, seconds >= 0 {
            return Int(seconds.rounded(.up))
        }
        guard let date = ISO8601DateFormatter.date(fromISO: raw) else { return nil }
        return max(0, Int(date.timeIntervalSinceNow.rounded(.up)))
    }

    /// `rateLimitMessage`.
    private static func rateLimitMessage(_ seconds: Int?) -> String {
        guard let seconds else {
            return "Trop de demandes ont été envoyées. Réessaie dans quelques minutes."
        }
        if seconds < 60 {
            return "Trop de demandes ont été envoyées. Réessaie dans quelques secondes."
        }
        let minutes = max(1, Int((Double(seconds) / 60).rounded(.up)))
        return "Trop de demandes ont été envoyées. Réessaie dans \(minutes) minute\(minutes > 1 ? "s" : "")."
    }
}
