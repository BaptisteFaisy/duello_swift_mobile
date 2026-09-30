import Foundation

// Découpage de `DuelloAPI.swift` — socle du client HTTP : déclaration de
// `DuelloAPI`, configuration (`baseURL`, codeurs JSON), requête générique et
// erreur de transport partagée. Aucun type, membre ni signature renommé.
//
// Écarts assumés (29/09/2026, écarts 17 #1 à #4) :
//   - l'adresse de base suit la variante `development` du RN
//     (`config/duello-development.json` : Tailscale `…:8445/api`) ;
//   - `Content-Type` n'est plus posé : la source (`adminApi.ts`) ne pose que
//     `Accept` + `Authorization`. Résidu : `URLSession` n'ajoute aucun
//     `Content-Type`, là où `fetch` (RN) en pose un `text/plain;charset=UTF-8`
//     implicite pour un corps texte ;
//   - le délai par défaut est de 10 s (`REQUEST_TIMEOUT` de `adminApi.ts`) ;
//     il reste surchargeable par appel (`timeout:`), ce dont la transcription
//     photo a besoin (OCR à effort maximal, 180 s — `mathOcr.ts:76`) ;
//   - le repli HTTP sans `error` exploitable rend « Service indisponible (n). »,
//     que `AdmAPITransport` remappe vers « Serveur indisponible (n) ».

/// Erreur de l'annuaire, alignée sur `DirectoryError` côté Expo.
struct DirectoryError: LocalizedError, Decodable {
    let message: String
    let status: Int?

    var errorDescription: String? { message }

    enum CodingKeys: String, CodingKey { case message = "error" }

    init(message: String, status: Int? = nil) {
        self.message = message
        self.status = status
    }

    /// Un corps sans `error` exploitable (clé absente ou vide) **échoue** : le
    /// repli HTTP de `request` (« Service indisponible (statut). ») prend alors
    /// le relais, comme `adminApi.ts` qui ne retient le message du corps que si
    /// `body.error?.trim()` est vrai.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let raw = (try? c.decode(String.self, forKey: .message)) ?? ""
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw DecodingError.valueNotFound(
                String.self,
                DecodingError.Context(
                    codingPath: c.codingPath,
                    debugDescription: "Corps sans `error` exploitable."
                )
            )
        }
        message = trimmed
        status = nil
    }
}

/// Client HTTP du backend Duello (voir `src/utils/socialApi.ts`).
/// Adresse figée dans le bundle : relais **de développement** du RN, la même
/// que `config/duello-development.json` (`apiUrl`, Tailscale `…:8445/api`) et
/// que la surcharge `EXPO_PUBLIC_DUELLO_API_URL` du profil EAS `development`.
/// Bascule prod : reprendre `https://duello-api-relay.duello.workers.dev/api`.
enum DuelloAPI {
    /// `apiUrl` de `config/duello-development.json` (profil `development`).
    static let baseURL = URL(string: "https://baptiste-zenbook-ux362fa-ux362fa.tail3a8bdf.ts.net:8445/api")!

    static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        return d
    }()

    static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        return e
    }()

    // MARK: Requête générique

    static func request(
        _ path: String,
        method: String = "GET",
        token: String? = nil,
        body: Data? = nil,
        query: [URLQueryItem] = [],
        timeout: TimeInterval = 10
    ) async throws -> Data {
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        if !query.isEmpty {
            components.queryItems = query
        }
        var request = URLRequest(url: components.url!)
        request.httpMethod = method
        request.timeoutInterval = timeout
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw DirectoryError(message: "Le serveur Duello est injoignable.")
        }
        guard (200..<300).contains(http.statusCode) else {
            let payload = try? decoder.decode(DirectoryError.self, from: data)
            throw DirectoryError(
                message: payload?.message ?? "Service indisponible (\(http.statusCode)).",
                status: http.statusCode
            )
        }
        return data
    }

    static func request<T: Decodable>(
        _ type: T.Type,
        _ path: String,
        method: String = "GET",
        token: String? = nil,
        body: Data? = nil,
        query: [URLQueryItem] = [],
        timeout: TimeInterval = 10
    ) async throws -> T {
        let data = try await request(path, method: method, token: token, body: body, query: query, timeout: timeout)
        return try decoder.decode(T.self, from: data)
    }

    static func encodeBody<T: Encodable>(_ value: T) throws -> Data {
        try encoder.encode(value)
    }
}
