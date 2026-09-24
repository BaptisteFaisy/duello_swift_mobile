//
//  ProfTutorStreamDelegate.swift
//  Duello
//
//  Port de `src/utils/profTutorStream.ts` (RN) — collecteur du flux SSE.
//
//  Reçoit les morceaux du relais par le délégué `URLSessionDataDelegate`
//  (pendant du `xhr.onprogress` de la source), alimente le parseur SSE de
//  `ProfTutorSse` et publie chaque morceau à l'appelant. Une réponse non SSE est
//  accumulée puis lue d'un bloc (`parseProfJsonResponse`).
//
//  Découpage (limites de complexité) : `ProfTutorStream` garde la politique
//  (délai, reprise unique, requête) ; ce fichier ne porte que la réception.
//
//  Cible : iOS 16. Aucune dépendance externe.
//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Réception d'un flux : un collecteur par connexion, détruit à la fin.
///
/// `@unchecked Sendable` : l'état mutable n'est touché que sur la file du
/// délégué `URLSession` (sérialisée) et la continuation n'est posée qu'une fois,
/// avant le démarrage de la tâche. Rien ne franchit deux files en même temps.
final class ProfStreamCollector: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    private let onToken: ProfTokenHandler
    private let idleTimeout: TimeInterval

    private var session: URLSession?
    private var continuation: CheckedContinuation<String, Error>?
    private var rawBody = Data()
    private var buffer = ""
    private var full = ""
    private var consumed = 0
    private var status = 200
    private var isEventStream = false
    private var settled = false

    init(onToken: @escaping ProfTokenHandler, idleTimeout: TimeInterval) {
        self.onToken = onToken
        self.idleTimeout = idleTimeout
    }

    /// Lance la requête et attend le flux complet (ou la première erreur).
    func run(request: URLRequest) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            let configuration = URLSessionConfiguration.default
            configuration.timeoutIntervalForRequest = idleTimeout
            let session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
            self.session = session
            session.dataTask(with: request).resume()
        }
    }

    // MARK: Délégué

    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        if let http = response as? HTTPURLResponse {
            status = http.statusCode
            isEventStream = (http.value(forHTTPHeaderField: "Content-Type") ?? "")
                .contains("text/event-stream")
        }
        completionHandler(.allow)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        rawBody.append(data)
        guard isEventStream else { return }
        feedEventStream()
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error {
            let timedOut = (error as? URLError)?.code == .timedOut
            finish(.failure(timedOut ? ProfTutorError.streamTimeout : error))
            return
        }
        guard (200..<300).contains(status) else {
            finish(.failure(httpError()))
            return
        }
        if isEventStream {
            finish(.success(full))
        } else {
            finishJSON()
        }
    }

    // MARK: Interne

    /// Décode le corps reçu (reliquat UTF-8 incomplet remis au morceau suivant)
    /// et publie les morceaux d'événements complets.
    private func feedEventStream() {
        guard let text = String(data: rawBody, encoding: .utf8) else { return }
        buffer += String(text.dropFirst(consumed))
        consumed = text.count
        let parsed = parseProfSse(buffer)
        buffer = parsed.rest
        for chunk in parsed.texts {
            full += chunk
            onToken(chunk)
        }
        if parsed.done { finish(.success(full)) }
    }

    /// `readProfHttpError` : refus d'accès, message serveur, ou libellé de statut.
    private func httpError() -> Error {
        if status == 401 || status == 403 || status == 429 {
            return profHttpErrorMessage(status)
        }
        if let text = String(data: rawBody, encoding: .utf8),
           let data = text.data(using: .utf8),
           let object = try? JSONSerialization.jsonObject(with: data),
           let dictionary = object as? [String: Any],
           let message = dictionary["error"] as? String,
           !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return ProfTutorError.relay(message)
        }
        return profHttpErrorMessage(status)
    }

    /// Réponse JSON non streamée : le relais a répondu d'un bloc.
    private func finishJSON() {
        guard let text = String(data: rawBody, encoding: .utf8) else {
            finish(.failure(ProfTutorError.unexpectedResponse))
            return
        }
        do {
            let parsed = try parseProfJsonResponse(text)
            onToken(parsed)
            finish(.success(parsed))
        } catch {
            finish(.failure(error))
        }
    }

    /// Résout la continuation une seule fois et libère la session.
    private func finish(_ result: Result<String, Error>) {
        guard !settled else { return }
        settled = true
        let continuation = self.continuation
        self.continuation = nil
        session?.invalidateAndCancel()
        session = nil
        continuation?.resume(with: result)
    }
}
