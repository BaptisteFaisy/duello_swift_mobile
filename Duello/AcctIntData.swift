//
//  AcctIntData.swift
//  Duello
//
//  LOT 17 — intégration de l'onglet « Mon compte » (préfixe `AcctInt`).
//
//  Fabrique les données de la vitrine à partir de `SessionStore` et
//  `ProgressStore`. Reprend la composition de
//  `src/screens/AccountScreen.tsx` : `viewedOverviewStats` (l. 1841-1872),
//  `viewedDetailStats` (l. 1873-1902), `viewedXpSummary` (l. 1710,
//  `summaryFromTotal`), `viewedOverallElo` (l. 1838), `viewedLeague` (l. 1839)
//  et `showcasePath` (l. 2773-2790).
//
//  Replis documentés — donnée absente du portage local (jamais inventée) :
//    - XP totale : aucun store d'XP n'est exposé → `unavailableXp` (0) ; le
//      niveau affiché est donc celui du palier 1.
//    - Complétion de programme : `ProgressStore` ne publie pas la couverture du
//      programme menant aux concours → `unavailableProgramPercent` (0).
//    - Succès par matière : le regroupement item → matière dépend du catalogue
//      d'exercices, non relié ici → liste vide côté vitrine (état vide affiché).
//    - Séries XP / Elo horodatées : `ProgressStore` ne conserve pas d'historique
//      → listes vides (les sections affichent leur état vide).
//
//  Cible : iOS 16, aucune API iOS 17.
//
import Foundation

/// Données de la vitrine de l'onglet « Mon compte », dérivées de l'état local.
enum AcctIntData {
    /// XP totale : non suivie par le portage local (voir en-tête).
    static let unavailableXp: Double = 0
    /// Complétion de programme : non exposée par `ProgressStore` (voir en-tête).
    static let unavailableProgramPercent: Int = 0

    /// Lignes du parcours publié (`showcasePath` : filière, année, option).
    static func pathLines(_ profile: UserProfile) -> [String] {
        [profile.track, profile.year, profile.specialty]
    }

    /// Elo global (`viewedElo.overall.current`) : moyenne des Elo de matière,
    /// ramenée à la cote initiale quand aucune matière n'est classée.
    static func overallElo(_ progress: ProgressStore) -> Int {
        let values = Array(progress.subjectElos.values)
        guard !values.isEmpty else { return ProgressStore.initialElo }
        let average = Double(values.reduce(0, +)) / Double(values.count)
        return Int(average.rounded())
    }

    /// Matières classées (`eloSubjects`) : une puce par matière, ordre stable.
    static func eloSubjects(_ progress: ProgressStore) -> [String] {
        progress.subjectElos.keys.sorted()
    }

    /// Résumé de niveau d'XP (`viewedXpSummary` = `summaryFromTotal(xp)`).
    static func xpSummary(totalXp: Double) -> ChartXpSummary {
        let level = ExGXp.describe(totalXp)
        return ChartXpSummary(
            level: level.level,
            total: totalXp,
            progress: level.progress,
            intoLevel: level.intoLevel,
            levelSpan: level.levelSpan,
            toNextLevel: level.toNextLevel,
            isMaxLevel: level.isMaxLevel
        )
    }

    /// Repères généraux de la vitrine (`viewedOverviewStats`).
    static func overviewStats(
        totalXp: Double,
        elo: Int,
        streakDays: Int,
        programPercent: Int
    ) -> [ChartPerformanceOverviewStat] {
        let xpText = ExGFormat.xp(totalXp)
        return [
            ChartPerformanceOverviewStat(
                icon: "sparkles", value: xpText, label: "XP",
                accessibilityLabel: "\(xpText) XP",
                color: ChartGoogleGColors.blue),
            ChartPerformanceOverviewStat(
                icon: "trophy", value: "\(elo)", label: "ELO",
                accessibilityLabel: "\(elo) Elo moyen",
                color: ChartGoogleGColors.green),
            ChartPerformanceOverviewStat(
                icon: "flame", value: "\(streakDays) j", label: "SÉRIE",
                accessibilityLabel: streakAccessibility(streakDays),
                color: ChartGoogleGColors.yellow),
            ChartPerformanceOverviewStat(
                icon: "chart.pie", value: "\(programPercent) %", label: "PROGRAMME",
                accessibilityLabel: "\(programPercent) % du programme menant aux concours",
                color: ChartGoogleGColors.red),
        ]
    }

    /// Repères détaillés de la vitrine (`viewedDetailStats`).
    static func detailStats(
        level: Int,
        progress: ProgressStore
    ) -> [ChartPerformanceOverviewStat] {
        let timeText = ProgressStore.formatTrainingTime(minutes: progress.exerciseMinutes)
        return [
            ChartPerformanceOverviewStat(
                icon: "ribbon", value: "\(level)", label: "NIVEAU",
                accessibilityLabel: "Niveau \(level)",
                color: ChartGoogleGColors.blue),
            ChartPerformanceOverviewStat(
                icon: "bolt", value: "\(progress.challengesCompleted)", label: "DÉFIS",
                accessibilityLabel: "\(progress.challengesCompleted) défis terminés",
                color: ChartGoogleGColors.green),
            ChartPerformanceOverviewStat(
                icon: "checkmark.circle", value: "\(progress.exercisesCompleted)",
                label: "EXERCICES",
                accessibilityLabel: "\(progress.exercisesCompleted) exercices terminés",
                color: ChartGoogleGColors.yellow),
            ChartPerformanceOverviewStat(
                icon: "timer", value: timeText, label: "ENTRAÎNEMENT",
                accessibilityLabel: "\(timeText) d’entraînement",
                color: ChartGoogleGColors.red),
        ]
    }

    /// Libellé VoiceOver de la série (« 1 jour » / « N jours »).
    private static func streakAccessibility(_ days: Int) -> String {
        "\(days) jour\(days > 1 ? "s" : "") de série"
    }
}
