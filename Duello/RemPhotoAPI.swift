import Foundation

// Porté depuis `src/utils/remotePhotoApiClient.ts` (lot N, photo à distance).
// Transport local du protocole : jeton de session, en-têtes personnalisés
// (appairage, nom de photo, demande de capture), délais et traduction des
// erreurs. `DuelloAPI.request` ne permet pas d'en-têtes arbitraires : ce
// helper local les ajoute sans modifier `DuelloAPI.swift`.

/// Helper réseau local + endpoints exacts de la connexion photo à distance.
enum RemPhotoAPI {
    /// `REMOTE_PHOTO_UPLOAD_TIMEOUT_MS` : 45 s pour un envoi d'octets.
    static let uploadTimeout: TimeInterval = 45
    /// `REMOTE_PHOTO_REQUEST_TIMEOUT_MS` : 10 s pour les appels courts.
    static let requestTimeout: TimeInterval = 10

    // Chemins exacts (`remotePhotoSessions.ts`, `remotePhotoUploads.ts`,
    // `remotePhotoCaptureApi.ts`), relatifs à `DuelloAPI.baseURL`.
    static let sessionPath = "remote-photo/session"
    static let currentSessionPath = "remote-photo/current-session"
    static let claimPath = "remote-photo/claim"
    static let photoPath = "remote-photo/photo"
    static let capturePhotoPath = "remote-photo/capture-photo"
    static let captureRequestPath = "remote-photo/capture-request"

    // En-têtes exacts.
    static let pairingHeader = "X-Duello-Pairing-Token"
    static let photoNameHeader = "X-Duello-Photo-Name"
    static let captureHeader = "X-Duello-Capture-Request"

    /// Requête authentifiée : construit l'appel, puis traduit toute défaillance
    /// (HTTP ou transport) en `RemPhotoError`.
    static func request(
        path: String,
        method: String = "GET",
        token: String?,
        headers: [String: String] = [:],
        body: Data? = nil,
        query: [URLQueryItem] = [],
        timeout: TimeInterval = requestTimeout
    ) async throws -> Data {
        let request = try buildRequest(
            path: path, method: method, token: token,
            headers: headers, body: body, query: query, timeout: timeout
        )
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw RemPhotoError(
                    message: "Le serveur Duello est injoignable.",
                    status: nil,
                    code: "remote-photo-network"
                )
            }
            guard (200..<300).contains(http.statusCode) else {
                throw failure(from: data, status: http.statusCode)
            }
            return data
        } catch let error as RemPhotoError {
            throw error
        } catch {
            throw transportError(error)
        }
    }

    /// Charge utile JSON sous forme de dictionnaire (jamais d'échec).
    static func dictionary(_ data: Data) -> [String: Any] {
        (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
    }

    /// Sérialise un corps JSON minimal.
    static func jsonBody(_ object: [String: Any]) -> Data? {
        try? JSONSerialization.data(withJSONObject: object)
    }

    /// Assemble l'`URLRequest` (jeton obligatoire, en-têtes, délai).
    private static func buildRequest(
        path: String,
        method: String,
        token: String?,
        headers: [String: String],
        body: Data?,
        query: [URLQueryItem],
        timeout: TimeInterval
    ) throws -> URLRequest {
        guard let token, !token.isEmpty else {
            throw RemPhotoError(
                message: "Connecte-toi à Duello sur cet appareil pour utiliser la connexion PC.",
                status: 401,
                code: "authentication-required"
            )
        }
        var components = URLComponents(
            url: DuelloAPI.baseURL.appendingPathComponent(path),
            resolvingAgainstBaseURL: false
        )!
        if !query.isEmpty { components.queryItems = query }
        var request = URLRequest(url: components.url!)
        request.httpMethod = method
        request.timeoutInterval = timeout
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        if body != nil { request.setValue("application/json", forHTTPHeaderField: "Content-Type") }
        for (key, value) in headers { request.setValue(value, forHTTPHeaderField: key) }
        request.httpBody = body
        return request
    }

    /// `failureFromResponse` : message `error` du serveur, sinon repli localisé.
    private static func failure(from data: Data, status: Int) -> RemPhotoError {
        let payload = dictionary(data)
        let text = ((payload["error"] as? String) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return RemPhotoError(
            message: text.isEmpty ? "Connexion au PC indisponible (\(status))." : text,
            status: status,
            code: payload["code"] as? String
        )
    }

    /// Traduit une panne de transport (délai dépassé ou réseau injoignable).
    private static func transportError(_ error: Error) -> RemPhotoError {
        if let urlError = error as? URLError, urlError.code == .timedOut {
            return RemPhotoError(
                message: "La connexion PC met trop de temps à répondre.",
                status: nil,
                code: "remote-photo-timeout"
            )
        }
        return RemPhotoError(
            message: "Le serveur Duello est injoignable.",
            status: nil,
            code: "remote-photo-network"
        )
    }
}
