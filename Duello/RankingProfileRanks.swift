//
//  RankingProfileRanks.swift
//  Duello
//
//  Rangs affichés sur le profil consulté (tuiles NIVEAU et DÉFIS).
//
//  Fichier source Expo porté (libellés et mêmes fusions que les écrans de
//  classements) :
//    - src/utils/profileLeaderboardRanks.ts
//        `PROFILE_RANK_SUBJECT`, `PROFILE_RANK_PENDING_VALUE`,
//        `mathEloFromSubjects`, `publishedWeeklyXp`, `ViewedRankEntry`,
//        `resolveViewedEloRank`, `resolveViewedXpRank`, `profileRankTile`.
//    - src/utils/subjectLeaderboard.ts (`leaderboardRankForElo`,
//      `formatLeaderboardRank` — déjà porté : `leaderboardRankLabel`).
//    - src/utils/weeklyXpLeaderboard.ts (`weeklyXpRank` — déjà porté :
//      `RankingWeeklyXp.weeklyXpRank`).
//
//  La tuile devient le rang au classement XP de la semaine (NIVEAU) ou au
//  classement Elo (DÉFIS), calculés sur le classement de mathématiques en portée
//  « Moi », avec exactement les mêmes fusions score local / lignes distantes que
//  les écrans de classements.
//
//  À raccorder (vague 5) : `AcctIntData.rankTile` (`AcctIntData.swift:222`)
//  garde aujourd'hui le repli « — » ; il appellera `profileRankTile` quand la
//  cohorte locale sera chargée sur cet écran.
//
//  Cible : iOS 16, aucune dépendance externe.
//
import SwiftUI

/// Cote d'une matière publiée sur un profil (`Pick<PublicEloSeries, label|current>`).
struct RankingEloSeries: Equatable {
    var label: String
    var current: Double
}

/// `utils/profileLeaderboardRanks.ts` : rangs du profil consulté.
enum RankingProfileRanks {

    /// `PROFILE_RANK_SUBJECT` : seule matière classée pour le moment.
    static let subject = "Mathématiques"

    /// `PROFILE_RANK_PENDING_VALUE` : valeur affichée tant que le rang est
    /// inconnu.
    static let pendingValue = "—"

    /// `ViewedRankEntry` : identité minimale de la personne affichée.
    struct Viewed: Equatable {
        var id: String
        var displayName: String
        var prepName: String
    }

    /// `mathEloFromSubjects` : cote de maths de la personne affichée, `nil` quand
    /// elle manque.
    static func mathElo(fromSubjects series: [RankingEloSeries]?) -> Double? {
        guard let current = series?.first(where: { $0.label == subject })?.current,
              current.isFinite
        else { return nil }
        return current
    }

    /// `publishedWeeklyXp` : XP publiés dans la matière classée pour la semaine
    /// donnée, `nil` sinon.
    static func publishedWeeklyXp(_ weeklyXp: [WeeklySubjectXp]?, week: String) -> Double? {
        guard let entry = weeklyXp?.first(where: { $0.subject == subject && $0.week == week }),
              Double(entry.xp).isFinite
        else { return nil }
        return Double(entry.xp)
    }

    /// `leaderboardRankForElo` : rang déduit de la seule cote — chaque ligne à
    /// cote strictement supérieure compte, rangs individuels même à cote égale.
    static func leaderboardRankForElo(_ entries: [LeaderboardEntry], elo: Double) -> Int {
        let rounded = max(0, Int((elo.isFinite ? elo : 0).rounded()))
        let higher = entries.filter { entry in
            guard let value = entry.elo else { return false }
            return max(0, value) > rounded
        }.count
        return higher + 1
    }

    /// `resolveViewedEloRank` : rang Elo de la personne affichée dans sa
    /// cohorte. Un compte identifiable est fusionné comme sur l'écran de
    /// classements ; un compte privé ne peut pas identifier sa ligne anonyme,
    /// son rang se déduit du score seul.
    static func resolveViewedEloRank(
        _ remoteEntries: [LeaderboardEntry],
        viewed: Viewed,
        elo: Double,
        hideIdentity: Bool
    ) -> Int {
        let others = remoteEntries.filter { $0.id != viewed.id }
        if hideIdentity { return leaderboardRankForElo(others, elo: elo) }

        let currentUser = RankingCurrentUser(
            id: viewed.id,
            displayName: viewed.displayName,
            prepName: viewed.prepName,
            track: nil,
            currentTrack: nil,
            specialty: nil,
            year: nil,
            score: max(0, Int(elo.rounded())),
            photoUri: nil
        )
        let ranked = rankedSubjectRows(
            remoteEntries,
            currentUser: currentUser,
            currentUserScoreLoaded: true
        )
        // Identifiant tenu hors classement (compte d'équipe) : repli sur le score.
        return ranked.first(where: { $0.isCurrentUser })?.rank
            ?? leaderboardRankForElo(others, elo: elo)
    }

    /// `resolveViewedXpRank` : rang XP de la personne affichée sur la semaine
    /// classée. Même contrat que le rang Elo.
    static func resolveViewedXpRank(
        _ remoteEntries: [LeaderboardEntry],
        viewed: Viewed,
        xp: Double,
        hideIdentity: Bool
    ) -> Int {
        let others = remoteEntries.filter { $0.id != viewed.id }
        if hideIdentity { return RankingWeeklyXp.weeklyXpRank(others, xp: xp) }

        let currentUser = RankingCurrentUser(
            id: viewed.id,
            displayName: viewed.displayName,
            prepName: viewed.prepName,
            track: nil,
            currentTrack: nil,
            specialty: nil,
            year: nil,
            score: max(0, Int(xp.rounded())),
            photoUri: nil
        )
        let ranked = rankedWeeklyRows(
            remoteEntries,
            currentUser: currentUser,
            currentUserScoreLoaded: true
        )
        return ranked.first(where: { $0.isCurrentUser })?.rank
            ?? RankingWeeklyXp.weeklyXpRank(others, xp: xp)
    }

    /// `profileRankTile` : tuile de rang, ou tiret tant que le rang n'est pas
    /// connu (l'accessibilité dit alors « en cours de chargement » ou
    /// « indisponible »).
    static func profileRankTile(
        rank: Int?,
        loading: Bool,
        label: String,
        icon: String,
        color: Color,
        leaderboardName: String
    ) -> ChartPerformanceOverviewStat {
        guard let rank else {
            return ChartPerformanceOverviewStat(
                icon: icon,
                value: pendingValue,
                label: label,
                accessibilityLabel: "Rang au \(leaderboardName) "
                    + (loading ? "en cours de chargement" : "indisponible"),
                color: color
            )
        }
        let formatted = leaderboardRankLabel(rank)
        return ChartPerformanceOverviewStat(
            icon: icon,
            value: formatted,
            label: label,
            accessibilityLabel: "Rang \(formatted) au \(leaderboardName)",
            color: color
        )
    }
}
