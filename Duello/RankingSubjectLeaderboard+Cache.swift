//
//  RankingSubjectLeaderboard+Cache.swift
//  Duello
//
//  Relecture au montage d'un classement de matière depuis l'instantané
//  persisté (`restoreCachedSubjectLeaderboard` côté RN) : mémoire d'abord,
//  puis disque (quelques millisecondes), avant le réseau. L'écran rend les
//  dernières lignes connues dès son apparition, le rafraîchissement réseau
//  restant maître derrière.
//
//  Fichier séparé pour tenir le budget de lignes de
//  `RankingSubjectLeaderboard.swift` (ratchet Hermes).
//
//  Cible : iOS 16.
//
import Foundation

/// Dernier classement de matière connu, **mémoire d'abord** puis disque
/// (`cachedSubjectLeaderboard` / `restoreCachedSubjectLeaderboard`) : `nil` si
/// aucun instantané ne correspond à la clé de cache (matière + cohorte).
func subjectLeaderboardSnapshotEntries(
    subject: String,
    cohort: String? = nil
) async -> [LeaderboardEntry]? {
    let key = rankingsSubjectLeaderboardCacheKey(subject: subject, cohort: cohort)
    return await restoreRankingsSnapshotEntries(.subjectLeaderboard, key: key)
}

/// Dernier classement de matière connu en mémoire seule, sans toucher au
/// disque (`cachedSubjectLeaderboard`), pour un premier rendu immédiat.
func cachedSubjectLeaderboardSnapshotEntries(
    subject: String,
    cohort: String? = nil
) -> [LeaderboardEntry]? {
    let key = rankingsSubjectLeaderboardCacheKey(subject: subject, cohort: cohort)
    return cachedRankingsSnapshotEntries(.subjectLeaderboard, key: key)
}

/// Dernier classement hebdo connu, mémoire d'abord puis disque
/// (`restoreCachedWeeklyXpLeaderboard`).
func weeklyXpLeaderboardSnapshotEntries(
    subject: String,
    week: String
) async -> [LeaderboardEntry]? {
    let key = rankingsWeeklyXpLeaderboardCacheKey(subject: subject, week: week)
    return await restoreRankingsSnapshotEntries(.weeklyXpLeaderboard, key: key)
}

/// Dernier classement hebdo connu en mémoire seule (`cachedWeeklyXpLeaderboard`).
func cachedWeeklyXpLeaderboardSnapshotEntries(
    subject: String,
    week: String
) -> [LeaderboardEntry]? {
    let key = rankingsWeeklyXpLeaderboardCacheKey(subject: subject, week: week)
    return cachedRankingsSnapshotEntries(.weeklyXpLeaderboard, key: key)
}
