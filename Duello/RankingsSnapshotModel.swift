//
//  RankingsSnapshotModel.swift
//  Duello
//
//  Modèle persisté des derniers classements reçus (port de
//  src/utils/rankingsCacheStorage.ts côté RN).
//
//  Fichier séparé pour tenir le budget de fonctions de
//  `RankingSnapshotCache.swift` (ratchet Hermes) : les types persistés
//  (`RankingsSnapshotCacheName`, `RankingsSnapshotEntry`) vivent ici, le
//  store seul reste dans `RankingSnapshotCache.swift`.
//
//  Cible : iOS 16.
//
import Foundation

// MARK: - Modèle persisté

/// Cache de classement persistable (`RANKINGS_SNAPSHOTTED_CACHES`).
enum RankingsSnapshotCacheName: String, CaseIterable, Codable {
    case subjectLeaderboard = "subject-leaderboard"
    case weeklyXpLeaderboard = "weekly-xp-leaderboard"
}

/// Réponse d'un classement persistée pour un démarrage suivant
/// (`RankingsSnapshotEntry`).
struct RankingsSnapshotEntry: Codable, Equatable {
    let cache: RankingsSnapshotCacheName
    let key: String
    /// Millisecondes epoch, comme `Date.now()` côté RN.
    let savedAt: Double
    let entries: [LeaderboardEntry]

    /// Date de sauvegarde, pour un éventuel affichage « il y a … ».
    var savedDate: Date { Date(timeIntervalSince1970: savedAt / 1000) }

    init(
        cache: RankingsSnapshotCacheName,
        key: String,
        savedAt: Double,
        entries: [LeaderboardEntry]
    ) {
        self.cache = cache
        self.key = key
        self.savedAt = savedAt
        self.entries = entries
    }

    enum CodingKeys: String, CodingKey {
        case cache, key, savedAt, entries
    }

    /// Format stocké : rejeter tout ce qui ne respecte pas exactement la v1
    /// (`parseStoredSnapshots`) — le décodage tolérant laisse `Lenient` écarter
    /// l'entrée sans faire échouer la relecture entière.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawCache = try container.decode(String.self, forKey: .cache)
        guard let cache = RankingsSnapshotCacheName(rawValue: rawCache) else {
            throw DecodingError.dataCorruptedError(
                forKey: .cache,
                in: container,
                debugDescription: "Cache de classement inconnu : \(rawCache)"
            )
        }
        let key = try container.decode(String.self, forKey: .key)
        let savedAt = try container.decode(Double.self, forKey: .savedAt)
        guard savedAt.isFinite else {
            throw DecodingError.dataCorruptedError(
                forKey: .savedAt,
                in: container,
                debugDescription: "savedAt non fini"
            )
        }
        let entries = try container.decode([LeaderboardEntry].self, forKey: .entries)
        self.init(cache: cache, key: key, savedAt: savedAt, entries: entries)
    }
}
