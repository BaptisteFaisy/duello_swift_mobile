//
//  ChartMetricEvolution.swift
//  Duello
//
//  Variations de métriques et fenêtre calendaire paginée (lot D « Graphiques »,
//  préfixe `Chart`).
//
//  Fichiers source Expo portés (noms et libellés repris) :
//    - src/utils/accountMetricEvolution.ts  (`relativeEvolutionPercentage`,
//      `latestRelativeEvolutionPercentage`, `absoluteEvolution`,
//      `latestAbsoluteEvolution`)
//    - src/utils/performanceChartWindow.ts  (`performanceChartWindow`,
//      `pointsInPerformanceWindow`)
//
//  Cible iOS 16 ; aucune dépendance externe.
//
import Foundation

/// `accountMetricEvolution.ts` : variations absolues et relatives des métriques.
enum ChartMetricEvolution {
    /// Variation relative entre deux valeurs, arrondie à l'entier.
    static func relativeEvolution(current: Double, previous: Double) -> Double? {
        guard current.isFinite, previous.isFinite else { return nil }
        if previous == 0 { return current == 0 ? 0 : 100 }
        return ((current - previous) / previous * 100).rounded()
    }

    /// Variation relative entre les deux derniers points de la période affichée.
    static func latestRelativeEvolution(_ values: [Double]) -> Double? {
        guard values.count >= 2 else { return nil }
        return relativeEvolution(
            current: values[values.count - 1],
            previous: values[values.count - 2]
        )
    }

    /// Écart absolu entre deux valeurs, dans l'unité propre à la métrique.
    static func absoluteEvolution(current: Double, previous: Double) -> Double? {
        guard current.isFinite, previous.isFinite else { return nil }
        return current - previous
    }

    /// Écart absolu entre les deux derniers points de la période affichée.
    static func latestAbsoluteEvolution(_ values: [Double]) -> Double? {
        guard values.count >= 2 else { return nil }
        return absoluteEvolution(
            current: values[values.count - 1],
            previous: values[values.count - 2]
        )
    }
}

/// Fenêtre calendaire semi-ouverte (`performanceChartWindow`).
struct ChartPerformanceWindowRange: Hashable {
    var start: Double
    var end: Double
    var granularity: ChartTimeGranularity
}

/// `performanceChartWindow.ts` : fenêtre paginée d'un graphique de performances.
enum ChartPerformanceWindow {
    /// `performanceChartWindow` : bornes à minuit local, mois calendaires réels.
    static func window(
        _ granularity: ChartTimeGranularity,
        page: Int,
        now: Double
    ) -> ChartPerformanceWindowRange {
        let count = ChartTimeSeries.bucketCounts
        let end = ChartTimeSeries.shift(
            ChartTimeSeries.bucketStart(now, granularity),
            granularity,
            page * count + 1
        )
        return ChartPerformanceWindowRange(
            start: ChartTimeSeries.shift(end, granularity, -count),
            end: end,
            granularity: granularity
        )
    }

    /// `pointsInPerformanceWindow` : points visibles, périodes vides complétées.
    static func points<T>(
        _ points: [T],
        in window: ChartPerformanceWindowRange,
        at: (T) -> Double,
        empty: ((Double) -> T)? = nil
    ) -> [T] {
        // Pré-calcul : l'abscisse de chaque point est évaluée une seule fois
        // (le filtre l'appelait deux fois par point, puis la boucle encore une).
        let dated = points.map { (value: at($0), point: $0) }
        let visible = dated.filter { $0.value >= window.start && $0.value < window.end }
        guard let empty else { return visible.map { $0.point } }

        var byPeriod: [Double: [T]] = [:]
        for entry in visible {
            byPeriod[ChartTimeSeries.bucketStart(entry.value, window.granularity), default: []]
                .append(entry.point)
        }

        var complete: [T] = []
        var cursor = window.start
        while cursor < window.end {
            complete.append(contentsOf: byPeriod[cursor] ?? [empty(cursor)])
            cursor = ChartTimeSeries.shift(cursor, window.granularity, 1)
        }
        return complete
    }
}
