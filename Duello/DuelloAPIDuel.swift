import Foundation

// Découpage de `DuelloAPI.swift` — résultat d'un défi : remise de copie, suivi
// du verdict, abandon et décodage de l'enveloppe. Aucun type, membre ni
// signature renommé.

extension DuelloAPI {
    // MARK: Résultat d'un défi

    /// Copie adverse dévoilée après la remise des deux copies. Décodée
    /// souplement : le serveur peut l'envoyer incomplète selon l'état du défi.
    struct OpponentSubmission: Decodable {
        var score: Int?
        var note: String?
        var graded: Bool?
        var answers: [String: String]?
    }

    struct DuelResultEnvelope: Decodable {
        var state: String?
        var deadline: Double?
        var opponent: OpponentSubmission?
        var reason: String?
        var before: Int?
        var after: Int?
        var delta: Int?
        var outcome: String?
        var error: String?
    }

    private static func duelResultState(from envelope: DuelResultEnvelope) -> DuelResultState {
        switch envelope.state {
        case "waiting":
            return .waiting(deadline: envelope.deadline ?? 0)
        case "settled":
            let opponent: DuelSubmission? = envelope.opponent.map { submission in
                DuelSubmission(
                    score: submission.score ?? 0,
                    note: submission.note ?? "",
                    graded: submission.graded ?? false,
                    answers: submission.answers ?? [:]
                )
            }
            let elo: EloResult? = {
                guard let before = envelope.before, let after = envelope.after,
                      let delta = envelope.delta, let outcome = envelope.outcome else { return nil }
                return EloResult(before: before, after: after, delta: delta, outcome: outcome)
            }()
            return .settled(opponent: opponent, reason: envelope.reason, elo: elo)
        default:
            return .expired
        }
    }

    /// `POST /duel` — dépose la note de sa copie.
    static func submitDuelGrade(matchId: String, userId: String, grade: DuelSubmission, token: String) async throws -> DuelResultState {
        struct Body: Encodable {
            var matchId: String
            var userId: String
            var score: Int
            var note: String
            var graded: Bool
            var answers: [String: String]
        }
        let body = try encodeBody(Body(
            matchId: matchId,
            userId: userId,
            score: grade.score,
            note: grade.note,
            graded: grade.graded,
            answers: grade.answers
        ))
        let envelope = try await request(DuelResultEnvelope.self, "duel", method: "POST", token: token, body: body)
        return duelResultState(from: envelope)
    }

    /// `GET /duel?match=…&user=…` — prend des nouvelles du résultat.
    static func pollDuelResult(matchId: String, userId: String, token: String) async throws -> DuelResultState {
        let envelope = try await request(
            DuelResultEnvelope.self,
            "duel",
            token: token,
            query: [
                URLQueryItem(name: "match", value: matchId),
                URLQueryItem(name: "user", value: userId),
            ]
        )
        return duelResultState(from: envelope)
    }

    /// `DELETE /duel?match=…&user=…` — abandonne le défi.
    static func abandonDuel(matchId: String, userId: String, token: String) async {
        _ = try? await request(
            "duel",
            method: "DELETE",
            token: token,
            query: [
                URLQueryItem(name: "match", value: matchId),
                URLQueryItem(name: "user", value: userId),
            ]
        )
    }
}
