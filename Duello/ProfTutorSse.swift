//
//  ProfTutorSse.swift
//  Duello
//
//  Port de `src/utils/profTutor.ts` (RN) — lecture du flux SSE du relais,
//  réponse JSON non streamée, messages d'erreur HTTP et retentabilité.
//
//  Ces fonctions sont pures : elles ne touchent ni au réseau ni au stockage,
//  et restent donc vérifiables isolément (mêmes cas que `profTutor.test.ts`).
//
//  Cible : iOS 16. Aucune dépendance externe.
//

import Foundation

// MARK: - Lecture SSE

/// `ProfSseEvents` : texte(s) décodé(s), fin de flux et reliquat incomplet.
struct ProfSseEvents: Equatable {
    var texts: [String]
    var done: Bool
    var rest: String
}

/// `parseProfSse` : lit les événements SSE complets d'un tampon réseau.
///
/// Chaque événement tient sur une ou plusieurs lignes `data:`, séparé du suivant
/// par une ligne vide ; le reliquat incomplet est rendu tel quel pour être
/// complété par le morceau suivant. `data: "[DONE]"` termine le flux.
func parseProfSse(_ buffer: String) -> ProfSseEvents {
    var texts: [String] = []
    var done = false
    let normalized = buffer.replacingOccurrences(of: "\r\n", with: "\n")
    var rawEvents = normalized.components(separatedBy: "\n\n")
    let rest = rawEvents.popLast() ?? ""
    for rawEvent in rawEvents {
        for line in rawEvent.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.hasPrefix("data:") else { continue }
            let payload = String(trimmed.dropFirst("data:".count))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if payload == "\"[DONE]\"" || payload == "[DONE]" {
                done = true
                continue
            }
            if let chunk = profSseChunk(from: payload) { texts.append(chunk) }
        }
    }
    return ProfSseEvents(texts: texts, done: done, rest: rest)
}

/// Morceau de texte d'une charge SSE (`delta` d'abord, `text` sinon) ; un
/// événement étranger ou illisible est ignoré sans interrompre le flux.
private func profSseChunk(from payload: String) -> String? {
    guard let data = payload.data(using: .utf8),
          let object = try? JSONSerialization.jsonObject(with: data),
          let dictionary = object as? [String: Any]
    else { return nil }
    let chunk = (dictionary["delta"] as? String) ?? (dictionary["text"] as? String) ?? ""
    return chunk.isEmpty ? nil : chunk
}

// MARK: - Réponse JSON non streamée

/// `parseProfJsonResponse` : le relais peut répondre d'un bloc.
///
/// Rend le texte tel quel dès qu'il est non vide, lève le message d'erreur du
/// serveur s'il en porte un, sinon « Réponse inattendue du prof IA ».
func parseProfJsonResponse(_ raw: String) throws -> String {
    guard let data = raw.data(using: .utf8),
          let object = try? JSONSerialization.jsonObject(with: data),
          let dictionary = object as? [String: Any]
    else { throw ProfTutorError.unexpectedResponse }

    if let text = dictionary["text"] as? String,
       !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        return text
    }
    if let error = dictionary["error"] as? String,
       !error.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        throw ProfTutorError.relay(error)
    }
    throw ProfTutorError.unexpectedResponse
}

// MARK: - Statuts HTTP

/// `profHttpErrorMessage` : les statuts HTTP deviennent des erreurs parlantes.
func profHttpErrorMessage(_ status: Int) -> Error {
    if status == 401 || status == 403 { return ProfAuthenticationError() }
    if status == 429 { return ProfTutorError.rateLimited }
    return ProfTutorError.unavailable(status)
}

// MARK: - Retentabilité

/// `isProfStreamRetryable` : seule une panne réseau est retentée.
///
/// Côté source, `TypeError` et les messages « fetch failed », « network request
/// failed », « network error ». En Swift, ces pannes remontent en `URLError` :
/// le type est donc retenu comme équivalent, **sauf** `timedOut` (le silence
/// trop long du relais n'est pas une panne réseau, comme le `Error` de la source).
func isProfStreamRetryable(_ error: Error) -> Bool {
    if let urlError = error as? URLError {
        return urlError.code != .timedOut
    }
    let message = error.localizedDescription.lowercased()
    return message.contains("fetch failed")
        || message.contains("network request failed")
        || message.contains("network error")
}
