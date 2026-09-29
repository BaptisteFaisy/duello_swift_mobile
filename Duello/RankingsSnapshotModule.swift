//
//  RankingsSnapshotModule.swift
//  Duello
//
//  API de module des instantanés de classement (port des fonctions exportées de
//  src/utils/rankingsCacheStorage.ts côté RN) : enveloppes fines autour du
//  store partagé `RankingsSnapshotCache.shared`.
//
//  Fichier séparé pour tenir le budget de fonctions de
//  `RankingSnapshotCache.swift` (ratchet Hermes) : les cinq fonctions de module
//  vivent ici, le store seul reste dans `RankingSnapshotCache.swift`.
//
//  Cible : iOS 16.
//
import Foundation

// MARK: - Fonctions de module (API de `rankingsCacheStorage.ts`)

/// Persiste la dernière réponse validée d'un classement (échecs ignorés).
func saveRankingsSnapshot(
    _ cache: RankingsSnapshotCacheName,
    key: String,
    entries: [LeaderboardEntry]
) {
    RankingsSnapshotCache.shared.save(cache, key: key, entries: entries)
}

/// Relit tous les instantanés persistés, ou `nil` si rien d'exploitable.
func loadRankingsSnapshots() async -> [RankingsSnapshotEntry]? {
    await RankingsSnapshotCache.shared.load()
}

/// Dernier classement connu en mémoire, sans attendre le réseau.
func cachedRankingsSnapshotEntries(
    _ cache: RankingsSnapshotCacheName,
    key: String
) -> [LeaderboardEntry]? {
    RankingsSnapshotCache.shared.cachedEntries(cache, key: key)
}

/// Dernier classement connu, mémoire puis disque (relecture d'un démarrage).
func restoreRankingsSnapshotEntries(
    _ cache: RankingsSnapshotCacheName,
    key: String
) async -> [LeaderboardEntry]? {
    await RankingsSnapshotCache.shared.restore(cache, key: key)
}

/// Efface les instantanés : le classement repart d'une copie réseau franche.
func clearRankingsSnapshots() async {
    await RankingsSnapshotCache.shared.clear()
}
