//
//  RewRemoteAccountData+Transport.swift
//  Duello
//
//  Port de src/storage/remoteAccountData.ts (RN) — transport HTTP minimal du
//  client `/account-data` (`fetch` + `AbortSignal.timeout` de la source).
//
//  Découpage (24/09/2026) : section extraite de `RewRemoteAccountData.swift`
//  (porté du même fichier source).
//
//  Cible : iOS 16, aucune dépendance externe.
//
import Foundation

// MARK: - Transport

/// Échec HTTP brut d'un transport : porte le code de statut, équivalent du
/// test `!response.ok` de la source.
struct RewRemoteHTTPError: Error, Equatable {
    var status: Int
}

/// Transport HTTP minimal (couture réseau). L'implémentation de production
/// parle à `DuelloAPI.baseURL`.
protocol RewRemoteAccountDataTransport {
    func send(
        path: String,
        method: String,
        token: String,
        query: [URLQueryItem],
        body: Data?,
        timeout: TimeInterval
    ) async throws -> Data
}

/// Transport réel : `URLSession` + `URLRequest.timeoutInterval`, équivalent iOS
/// de `fetch` + `AbortSignal.timeout`. Lève `RewRemoteHTTPError` sur un statut
/// hors 2xx.
struct RewURLSessionAccountDataTransport: RewRemoteAccountDataTransport {
    func send(
        path: String,
        method: String,
        token: String,
        query: [URLQueryItem],
        body: Data?,
        timeout: TimeInterval
    ) async throws -> Data {
        var components = URLComponents(
            url: DuelloAPI.baseURL.appendingPathComponent(path),
            resolvingAgainstBaseURL: false
        )!
        if !query.isEmpty { components.queryItems = query }

        var request = URLRequest(url: components.url!)
        request.httpMethod = method
        request.timeoutInterval = timeout
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if body != nil {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw RewRemoteHTTPError(status: 0)
        }
        guard (200..<300).contains(http.statusCode) else {
            throw RewRemoteHTTPError(status: http.statusCode)
        }
        return data
    }
}
