import Foundation

// Découpage de `DuelloAPI.swift` — classements (matière et hebdomadaire).
// Aucun type, membre ni signature renommé.

extension DuelloAPI {
    // MARK: Classements

    struct LeaderboardResponse: Decodable {
        var entries: [LeaderboardEntry]?
    }

    /// `GET /leaderboard?subject=…` — classement d'une matière.
    static func subjectLeaderboard(subject: String, token: String?) async throws -> [LeaderboardEntry] {
        let response = try await request(
            LeaderboardResponse.self,
            "leaderboard",
            token: token,
            query: [URLQueryItem(name: "subject", value: subject)]
        )
        return response.entries ?? []
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
