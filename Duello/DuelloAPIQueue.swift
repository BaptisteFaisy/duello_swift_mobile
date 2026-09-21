import Foundation

// Découpage de `DuelloAPI.swift` — file d'attente des défis : entrée, suivi,
// sortie et décodage de l'état de file. Aucun type, membre ni signature renommé.

extension DuelloAPI {
    // MARK: File d'attente des défis

    struct QueueEnvelope: Decodable {
        var state: String?
        var ticket: String?
        var waitedMs: Double?
        var eloWindow: Int?
        var queued: Int?
        var match: MatchView?
        var error: String?
    }

    /// `POST /queue` — entre dans la file d'attente partagée.
    static func joinQueue(_ entry: QueueRequest, token: String) async throws -> QueueState {
        let body = try encodeBody(entry)
        let envelope = try await request(QueueEnvelope.self, "queue", method: "POST", token: token, body: body)
        return Self.queueState(from: envelope)
    }

    /// `GET /queue?ticket=…` — prend des nouvelles de la file.
    static func pollQueue(ticket: String, token: String) async throws -> QueueState {
        let envelope = try await request(
            QueueEnvelope.self,
            "queue",
            token: token,
            query: [URLQueryItem(name: "ticket", value: ticket)]
        )
        return Self.queueState(from: envelope)
    }

    /// `DELETE /queue?ticket=…` — quitte la file.
    static func leaveQueue(ticket: String, token: String) async {
        _ = try? await request("queue", method: "DELETE", token: token, query: [URLQueryItem(name: "ticket", value: ticket)])
    }

    private static func queueState(from envelope: QueueEnvelope) -> QueueState {
        switch envelope.state {
        case "matched":
            if let ticket = envelope.ticket, let match = envelope.match {
                return .matched(ticket: ticket, match: match)
            }
            return .expired
        case "waiting":
            if let ticket = envelope.ticket {
                return .waiting(
                    ticket: ticket,
                    waitedMs: envelope.waitedMs ?? 0,
                    eloWindow: envelope.eloWindow ?? 80,
                    queued: envelope.queued ?? 1
                )
            }
            return .expired
        default:
            return .expired
        }
    }
}
