//
//  DictAsrEvent.swift
//  Duello
//
//  Portage de `src/utils/realtimeAsr.ts` : événements du moteur temps réel
//  (`RealtimeAsrEvent`), décodage (`parseRealtimeAsrEvent`), URL du relais
//  (`realtimeAsrWebSocketUrl`) et mixage PCM (`monoPcm16`).
//
//  Cible : iOS 16. Aucune dépendance externe.
//

import Foundation

/// Erreurs de dictée (relais, permission, moteur, réponse).
enum DictError: LocalizedError {
    case invalidRelay
    case permissionDenied
    case engineUnavailable
    case badResponse(String)

    var errorDescription: String? {
        switch self {
        case .invalidRelay: return "Le relais vocal doit utiliser http ou https."
        case .permissionDenied: return "Autorise le micro et la reconnaissance vocale pour dicter ta réponse."
        case .engineUnavailable: return "La dictée IA est indisponible : reconnaissance du téléphone utilisée."
        case let .badResponse(message): return message
        }
    }
}

/// Événement du moteur temps réel — `RealtimeAsrEvent` de la source.
enum DictAsrEvent {
    case authorized
    case ready(model: String, sampleRate: Double)
    case transcript(text: String, isFinal: Bool, sentenceId: Int, beginTime: Double, endTime: Double)
    case refining(model: String)
    case fullTranscript(text: String, model: String)
    case refinementError(message: String)
    case done(refined: Bool, model: String?)
    case error(code: String, message: String)
}

extension DictPolicy {
    /// Ajoute la route vocale au relais HTTP sans changer son hôte permanent.
    static func realtimeAsrUrl(_ relayEndpoint: String) throws -> String {
        guard var composants = URLComponents(string: relayEndpoint), let scheme = composants.scheme else {
            throw DictError.invalidRelay
        }
        switch scheme {
        case "https": composants.scheme = "wss"
        case "http": composants.scheme = "ws"
        default: throw DictError.invalidRelay
        }
        var chemin = composants.path
        while chemin.hasSuffix("/") { chemin.removeLast() }
        composants.path = chemin.hasSuffix("/asr") ? chemin : chemin + "/asr"
        guard let url = composants.url else { throw DictError.invalidRelay }
        return url.absoluteString
    }

    /// Décode un événement brut du relais, ou rend `nil` — `parseRealtimeAsrEvent`.
    static func parseEvent(_ json: String) -> DictAsrEvent? {
        guard let data = json.data(using: .utf8),
              let objet = try? JSONSerialization.jsonObject(with: data),
              let event = objet as? [String: Any],
              let type = event["type"] as? String else { return nil }

        switch type {
        case "authorized":
            return .authorized
        case "done":
            return .done(refined: (event["refined"] as? Bool) == true, model: event["model"] as? String)
        case "refining":
            guard let model = event["model"] as? String else { return nil }
            return .refining(model: model)
        case "full-transcript":
            guard let text = event["text"] as? String, let model = event["model"] as? String,
                  isSupportedTranscript(text) else { return nil }
            return .fullTranscript(text: text.trimmingCharacters(in: .whitespacesAndNewlines), model: model)
        case "refinement-error":
            guard let message = event["message"] as? String else { return nil }
            return .refinementError(message: message)
        case "ready":
            guard let model = event["model"] as? String, let rate = event["sampleRate"] as? Double else { return nil }
            return .ready(model: model, sampleRate: rate)
        case "error":
            guard let code = event["code"] as? String, let message = event["message"] as? String else { return nil }
            return .error(code: code, message: message)
        case "transcript":
            guard let text = event["text"] as? String, let isFinal = event["isFinal"] as? Bool,
                  let sentenceId = event["sentenceId"] as? Int, isSupportedTranscript(text) else { return nil }
            return .transcript(
                text: text, isFinal: isFinal, sentenceId: sentenceId,
                beginTime: (event["beginTime"] as? Double) ?? 0,
                endTime: (event["endTime"] as? Double) ?? 0
            )
        default:
            return nil
        }
    }

    /// Mixe plusieurs canaux PCM16 en mono, moyennés sans écrêtage — `monoPcm16`.
    static func monoPcm16(_ data: Data, channels: Int) -> Data {
        if channels <= 1 { return data }
        let octets = [UInt8](data)
        let tailleTrame = 2 * channels
        let trames = octets.count / tailleTrame
        var sortie = Data(capacity: trames * 2)

        for trame in 0..<trames {
            var somme = 0
            for canal in 0..<channels {
                let offset = trame * tailleTrame + canal * 2
                let valeur = UInt16(octets[offset]) | (UInt16(octets[offset + 1]) << 8)
                somme += Int(Int16(bitPattern: valeur))
            }
            let moyenne = Int16(clamping: Int((Double(somme) / Double(channels)).rounded()))
            let brut = UInt16(bitPattern: moyenne)
            sortie.append(UInt8(brut & 0xFF))
            sortie.append(UInt8((brut >> 8) & 0xFF))
        }
        return sortie
    }
}
