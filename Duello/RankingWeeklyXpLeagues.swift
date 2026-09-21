import Foundation

// MARK: - Ligues XP hebdo (weeklyXpLeaderboard.ts)

/// Ligue hebdo : identifiant, libellé et seuil d'accès en XP.
///
/// Extrait de l'ancien `RankingsView.swift` : était `private`, élargi à
/// `internal` car `RankingWeeklyXp` manipule le type — mêmes propriétés.
struct WeeklyXpLeague: Identifiable, Hashable {
    let id: String
    let label: String
    let minimumXp: Int
}

/// Ligues de la semaine (`WEEKLY_XP_LEAGUES`), du plus bas au plus haut.
///
/// Extrait de l'ancien `RankingsView.swift` : était `private`, élargi à
/// `internal` car `RankingWeeklyXp` parcourt la série — même contenu.
let weeklyXpLeagues: [WeeklyXpLeague] = [
    WeeklyXpLeague(id: "ecricome", label: "ECRICOME", minimumXp: 0),
    WeeklyXpLeague(id: "emlyon", label: "emlyon", minimumXp: 100),
    WeeklyXpLeague(id: "edhec", label: "EDHEC", minimumXp: 250),
    WeeklyXpLeague(id: "escp", label: "ESCP", minimumXp: 500),
    WeeklyXpLeague(id: "essec", label: "ESSEC", minimumXp: 900),
    WeeklyXpLeague(id: "hec", label: "HEC", minimumXp: 1500),
]

/// Ligue atteinte avec les XP de la semaine courante (`weeklyXpLeagueFor`).
///
/// Extrait de l'ancien `RankingsView.swift` : était `private`, élargi à
/// `internal` car appelé par `RankingWeeklyXp` — corps inchangé.
func weeklyXpLeague(for xp: Int) -> WeeklyXpLeague {
    let total = max(0, xp)
    return weeklyXpLeagues.reversed().first { total >= $0.minimumXp } ?? weeklyXpLeagues[0]
}

/// Progression bornée dans la ligue hebdo courante, jusqu'au seuil suivant.
///
/// Extrait de l'ancien `RankingsView.swift` : était `private`, élargi à
/// `internal` car `RankingWeeklyXp` lit ses champs — mêmes propriétés.
struct WeeklyXpLeagueProgress {
    let league: WeeklyXpLeague
    let nextLeague: WeeklyXpLeague?
    let xpToNext: Int
    let fraction: Double
}

/// Progression d'un total d'XP vers la ligue suivante
/// (`weeklyXpLeagueProgress`) : fraction 1 une fois la plus haute atteinte.
///
/// Extrait de l'ancien `RankingsView.swift` : était `private`, élargi à
/// `internal` car appelé par `RankingWeeklyXp` — corps inchangé.
func weeklyXpLeagueProgress(for xp: Int) -> WeeklyXpLeagueProgress {
    let total = max(0, xp)
    let league = weeklyXpLeague(for: total)
    guard let index = weeklyXpLeagues.firstIndex(where: { $0.id == league.id }),
          index + 1 < weeklyXpLeagues.count
    else {
        return WeeklyXpLeagueProgress(league: league, nextLeague: nil, xpToNext: 0, fraction: 1)
    }

    let next = weeklyXpLeagues[index + 1]
    let span = next.minimumXp - league.minimumXp
    let earned = min(span, max(0, total - league.minimumXp))
    return WeeklyXpLeagueProgress(
        league: league,
        nextLeague: next,
        xpToNext: max(0, next.minimumXp - total),
        fraction: span > 0 ? Double(earned) / Double(span) : 1
    )
}
