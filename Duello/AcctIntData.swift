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
//  `summaryFromTotal`), `viewedOverallElo` (l. 1838), `viewedLeague` (l. 1839),
//  `showcasePath` (l. 2773-2790) et `buildEloSeries`/`groupEloSeriesByPeriod`
//  (`utils/subjectElo.ts`, l. 380/164).
//
//  Repli documenté — donnée absente du portage local (jamais inventée) :
//    - Succès par matière : le regroupement item → matière dépend du catalogue
//      d'exercices, non relié ici → liste vide côté vitrine (la section n'est
//      toutefois plus rendue, la source la masquant).
//
//  Vague 6 (lot S04, 2026-09-30) : les notes de correction, le temps par période
//  et les rangs « Moi » sont désormais fabriqués ailleurs — les deux premiers
//  dans `AcctIntShowcaseData.swift`, les rangs par `AcctProfileRanksController`
//  (`AcctIntShowcase.swift`), qui passe les tuiles à `detailStats`.
//
//  XP totale, complétion de programme, courbes XP et Elo proviennent de
//  `ProgressStore` (`totalXp`, `competitionProgramPercent`, `xpHistory`,
//  `eloHistory`), comme `buildOwnPerformance`/`competitionProgramPercent` de la
//  source.
//
//  Cible : iOS 16, aucune API iOS 17.
//
import SwiftUI

/// Données de la vitrine de l'onglet « Mon compte », dérivées de l'état local.
enum AcctIntData {
    /// Lignes du parcours publié (`showcasePath` : filière, année, option).
    ///
    /// `currentTrackForProfile` remplace le champ historique `track` (qui perd
    /// BCPST et B/L derrière MPSI) ; l'option passe par
    /// `accountAcademicOptionLabel`, qui rend la forme courte en ECG.
    static func pathLines(_ profile: UserProfile) -> [String] {
        let track = profile.followedTrack
        // `normalizeAcademicPath(own).currentOption` : option actuelle relue
        // d'abord de `academicPath.currentOption`, puis du champ historique.
        let savedOption = OnbFlowAcademic.normalizedOption(
            track: track,
            candidate: profile.academicPath?.currentOption ?? "",
            firstYear: false
        )
        let legacyOption = OnbFlowAcademic.normalizedOption(
            track: track, candidate: profile.specialty, firstYear: false
        )
        var option = savedOption.isEmpty ? legacyOption : savedOption
        // `accountAcademicOptionLabel` : en ECG, la forme courte « Maths
        // appliquées » / « Maths approfondies » ; ailleurs, l'option reste telle
        // quelle (chaîne vide quand elle n'est pas reconnue, la carte masquant
        // les lignes vides).
        if track == "ECG", !option.isEmpty {
            let normalized = option.lowercased()
            if normalized.contains("appliqu") {
                option = "Maths appliquées"
            } else if normalized.contains("approfond") {
                option = "Maths approfondies"
            }
        }
        return [track, profile.year, option]
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
                icon: "sparkles-outline", value: xpText, label: "XP",
                accessibilityLabel: "\(xpText) XP",
                color: ChartGoogleGColors.blue),
            ChartPerformanceOverviewStat(
                icon: "trophy-outline", value: "\(elo)", label: "ELO",
                accessibilityLabel: "\(elo) Elo moyen",
                color: ChartGoogleGColors.green),
            ChartPerformanceOverviewStat(
                icon: "flame-outline", value: "\(streakDays) j", label: "SÉRIE",
                accessibilityLabel: streakAccessibility(streakDays),
                color: ChartGoogleGColors.yellow),
            ChartPerformanceOverviewStat(
                icon: "pie-chart-outline", value: "\(programPercent) %", label: "PROGRAMME",
                accessibilityLabel: "\(programPercent) % du programme menant aux concours",
                color: ChartGoogleGColors.red),
        ]
    }

    /// Repères détaillés de la vitrine (`viewedDetailStats`).
    ///
    /// Sur la variante de développement (`USE_REFINED_OVERVIEW`), les deux
    /// premières tuiles deviennent les rangs « Moi » (RANG XP, RANG ELO) : le
    /// site d'appel les fabrique (`RankingProfileRanks.profileRankTile`) et les
    /// passe ici ; sans tuiles fournies, le repli reste le niveau et les défis.
    static func detailStats(
        level: Int,
        progress: ProgressStore,
        rankTiles: (xp: ChartPerformanceOverviewStat, elo: ChartPerformanceOverviewStat)? = nil
    ) -> [ChartPerformanceOverviewStat] {
        let timeText = ProgressStore.formatTrainingTime(minutes: progress.exerciseMinutes)
        let head: [ChartPerformanceOverviewStat]
        if AcctEvoConstants.useRefinedOverview, let rankTiles {
            head = [rankTiles.xp, rankTiles.elo]
        } else {
            head = [
                ChartPerformanceOverviewStat(
                    icon: "ribbon-outline", value: "\(level)", label: "NIVEAU",
                    accessibilityLabel: "Niveau \(level)",
                    color: ChartGoogleGColors.blue),
                ChartPerformanceOverviewStat(
                    icon: "flash-outline", value: "\(progress.challengesCompleted)",
                    label: "DÉFIS",
                    accessibilityLabel: "\(progress.challengesCompleted) défis terminés",
                    color: ChartGoogleGColors.green),
            ]
        }
        return head + [
            ChartPerformanceOverviewStat(
                icon: "checkmark-done-outline", value: "\(progress.exercisesCompleted)",
                label: "EXERCICES",
                accessibilityLabel: "\(progress.exercisesCompleted) exercices terminés",
                color: ChartGoogleGColors.yellow),
            ChartPerformanceOverviewStat(
                icon: "timer-outline", value: timeText, label: "ENTRAÎNEMENT",
                accessibilityLabel: "\(timeText) d’entraînement",
                color: ChartGoogleGColors.red),
        ]
    }

    /// Courbe d'Elo (`buildEloSeries` puis `groupEloSeriesByPeriod`) : un point
    /// par défi joué, valeur = moyenne arrondie des Elo des matières déjà
    /// jouées, puis une valeur de clôture par période.
    static func eloSeries(
        _ history: [ProgressEloEntry],
        subject: String?,
        granularity: ChartTimeGranularity
    ) -> [ChartEloSeriesPoint] {
        // `registeredAt` est absent du portage local : la série démarre au
        // premier point daté (repli documenté, comme `ChartXpSeries.build`).
        let played = history
            .filter { subject == nil || $0.subject == subject }
            .sorted { $0.at < $1.at }
        guard !played.isEmpty else { return [] }

        var latest: [String: Int] = [:]
        var raw: [ChartEloSeriesPoint] = [
            ChartEloSeriesPoint(elo: Double(ProgressStore.initialElo), at: 0)
        ]
        for entry in played {
            latest[entry.subject] = entry.elo
            let values = Array(latest.values)
            let average = Double(values.reduce(0, +)) / Double(values.count)
            raw.append(ChartEloSeriesPoint(elo: Double(Int(average.rounded())), at: entry.at))
        }

        // `groupEloSeriesByPeriod` : clôture par période ; le point non daté
        // (Elo d'inscription) reste en tête.
        let undatedStart = raw.first { $0.at <= 0 }
        var closingByPeriod: [Double: ChartEloSeriesPoint] = [:]
        for point in raw where point.at > 0 {
            let start = ChartTimeSeries.bucketStart(point.at, granularity)
            closingByPeriod[start] = ChartEloSeriesPoint(elo: point.elo, at: start)
        }
        var result: [ChartEloSeriesPoint] = []
        if let undatedStart { result.append(undatedStart) }
        result.append(contentsOf: closingByPeriod.values.sorted { $0.at < $1.at })
        return result
    }

    /// Libellé VoiceOver de la série (« 1 jour » / « N jours »).
    private static func streakAccessibility(_ days: Int) -> String {
        "\(days) jour\(days > 1 ? "s" : "") de série"
    }
}
