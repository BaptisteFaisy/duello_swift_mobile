import Foundation

// Découpage de `DuelloAPI.swift` — classements (matière et hebdomadaire).
// Aucun type, membre ni signature renommé.

extension DuelloAPI {
    // MARK: Classements

    struct LeaderboardResponse: Decodable {
        var entries: [LeaderboardEntry]?
    }

    /// `GET /leaderboard?subject=…[&cohort=…]` — classement d'une matière.
    /// Le filtre de cohorte est rejoué sur les lignes reçues (`subjectLeaderboard.ts`).
    static func subjectLeaderboard(
        subject: String,
        cohort: String? = nil,
        token: String?
    ) async throws -> [LeaderboardEntry] {
        var query = [URLQueryItem(name: "subject", value: subject)]
        if let cohort, !cohort.isEmpty {
            query.append(URLQueryItem(name: "cohort", value: cohort))
        }
        let response = try await request(
            LeaderboardResponse.self,
            "leaderboard",
            token: token,
            query: query
        )
        return filterSubjectLeaderboardEntriesByCohort(
            response.entries ?? [],
            cohort: cohort
        )
    }

    /// `GET /weekly-xp?subject=…&week=…` — classement hebdo d'une matière.
    static func weeklyXpLeaderboard(subject: String, week: String, token: String?) async throws -> [LeaderboardEntry] {
        let response = try await request(
            LeaderboardResponse.self,
            "weekly-xp",
            token: token,
            query: [
                URLQueryItem(name: "subject", value: subject),
                URLQueryItem(name: "week", value: week),
            ]
        )
        return response.entries ?? []
    }
}
