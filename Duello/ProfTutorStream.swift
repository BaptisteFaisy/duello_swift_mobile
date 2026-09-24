//
//  ProfTutorStream.swift
//  Duello
//
//  Port de `src/utils/profTutorStream.ts` (RN) — transport du flux « Prof IA »
//  vers le relais, morceau par morceau.
//
//  La source choisit `fetch` (web, corps exposé au fil de l'eau) ou `XHR`
//  (natif, `onprogress` relit le texte accumulé). Sur iOS, `URLSession` livre le
//  corps par morceaux via un délégué `URLSessionDataDelegate` — le pendant exact
//  du transport XHR natif — et le même parseur SSE que `ProfTutorSse`. Une
//  réponse `application/json` d'un bloc est lue d'un coup, comme
//  `parseProfJsonResponse`.
//
//  Approché (24/09/2026) :
//    - `PROF_STREAM_IDLE_TIMEOUT_MS` (60 s) est porté par
//      `timeoutIntervalForRequest` : URLSession le traite comme un délai **entre
//      deux paquets**, soit le silence maximal entre deux morceaux de la source ;
//    - le `AbortSignal` de la source devient l'annulation de la `Task` appelante
//      (`Task.isCancelled`) ; un flux annulé rend la chaîne vide, comme la source ;
//    - `URLSession.bytes(for:)` n'existe pas sous la chaîne d'outils Linux de
//      contrôle (FoundationNetworking) : le délégué le remplace et fonctionne à
//      l'identique sur Apple.
//
//  Cible : iOS 16. Aucune dépendance externe.
//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Rappel d'un morceau de texte reçu, appelé dans l'ordre du flux.
typealias ProfTokenHandler = (String) -> Void

/// `postProfStream` : envoie le corps au relais et lit le flux SSE.
enum ProfTutorStream {
    /// `PROF_STREAM_IDLE_TIMEOUT_MS` : silence maximal avant relais perdu.
    static let idleTimeout: TimeInterval = 60
    /// `PROF_STREAM_RETRY_DELAY_MS` : pause avant la reprise unique.
    static let retryDelay: TimeInterval = 0.7

    /// Panne réseau avant le premier jeton : retentée une fois.
    static func post(
        endpoint: URL,
        token: String,
        body: Data,
        onToken: @escaping ProfTokenHandler
    ) async throws -> String {
        do {
            return try await streamOnce(endpoint: endpoint, token: token, body: body, onToken: onToken)
        } catch {
            if Task.isCancelled { return "" }
            guard isProfStreamRetryable(error) else { throw error }
            try? await Task.sleep(nanoseconds: UInt64(retryDelay * 1_000_000_000))
            return try await streamOnce(endpoint: endpoint, token: token, body: body, onToken: onToken)
        }
    }

    // MARK: Une passe

    /// Une connexion, un flux : le collecteur porte l'état de réception.
    private static func streamOnce(
        endpoint: URL,
        token: String,
        body: Data,
        onToken: @escaping ProfTokenHandler
    ) async throws -> String {
        let collector = ProfStreamCollector(onToken: onToken, idleTimeout: idleTimeout)
        return try await collector.run(request: makeRequest(endpoint: endpoint, token: token, body: body))
    }

    /// Requête locale au relais, authentifiée par la session Duello.
    private static func makeRequest(endpoint: URL, token: String, body: Data) -> URLRequest {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        if !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = body
        return request
    }
}
