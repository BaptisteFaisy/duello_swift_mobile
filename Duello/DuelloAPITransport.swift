import Foundation

// Découpage de `DuelloAPI.swift` — socle du client HTTP : déclaration de
// `DuelloAPI`, configuration (`baseURL`, codeurs JSON), requête générique et
// erreur de transport partagée. Aucun type, membre ni signature renommé.

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

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        message = (try? c.decode(String.self, forKey: .message)) ?? "Service indisponible"
        status = nil
    }
}

/// Client HTTP du backend Duello (voir `src/utils/socialApi.ts`).
/// Adresse figée dans le bundle : relay Cloudflare de **développement**.
/// Correspond à la variante `development` de l'app Expo (`eas.json` +
/// `config/duello-development.json` : `apiUrl`). Bascule prod : reprendre
/// `https://duello-api-relay.duello.workers.dev/api`.
enum DuelloAPI {
    /// `EXPO_PUBLIC_DUELLO_API_URL` de `eas.json` (profil `development`).
    static let baseURL = URL(string: "https://duello-development-api-relay.duello.workers.dev/api")!

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
        query: [URLQueryItem] = []
    ) async throws -> Data {
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        if !query.isEmpty {
            components.queryItems = query
        }
        var request = URLRequest(url: components.url!)
        request.httpMethod = method
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if body != nil {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
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
        query: [URLQueryItem] = []
    ) async throws -> T {
        let data = try await request(path, method: method, token: token, body: body, query: query)
        return try decoder.decode(T.self, from: data)
    }

    static func encodeBody<T: Encodable>(_ value: T) throws -> Data {
        try encoder.encode(value)
    }
}
