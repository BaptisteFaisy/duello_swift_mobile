//
//  RankingSubjectLeaderboard+Cache.swift
//  Duello
//
//  Relecture au montage d'un classement de matière depuis l'instantané
//  persisté (`restoreCachedSubjectLeaderboard` côté RN) : l'écran rend les
//  dernières lignes connues dès son apparition, le rafraîchissement réseau
//  restant maître derrière.
//
//  Fichier séparé pour tenir le budget de lignes de
//  `RankingSubjectLeaderboard.swift` (ratchet Hermes).
//
//  Cible : iOS 16.
//
import Foundation

/// Lignes d'un classement de matière relues depuis les instantanés persistés
/// (`loadRankingsSnapshots`), ou `nil` si aucun instantané ne correspond à la
/// clé de cache (matière + cohorte).
func subjectLeaderboardSnapshotEntries(
    subject: String,
    cohort: String? = nil
) async -> [LeaderboardEntry]? {
    guard let snapshots = await loadRankingsSnapshots() else { return nil }
    let key = rankingsSubjectLeaderboardCacheKey(subject: subject, cohort: cohort)
    return snapshots.first {
        $0.cache == .subjectLeaderboard && $0.key == key
    }?.entries
}
