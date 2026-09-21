//
//  ChartTimeNavigation.swift
//  Duello
//
//  Pagination du graphique de temps par matière (lot D « Graphiques »,
//  préfixe `Chart`).
//
//  Fichier source Expo porté (noms et libellés repris) :
//    - src/utils/timeChartNavigation.ts (`TIME_CHART_WINDOW_SIZE`,
//      `timeChartPageCount`, `timeChartWindow`, `timeChartPageLabel`,
//      `resolveTimeChartSwipePage`, `minuteAxisMaximum`)
//
//  Cible iOS 16 ; aucune dépendance externe.
//
import Foundation

/// `timeChartNavigation.ts` : fenêtres de sept périodes, gestes et axe des minutes.
enum ChartTimeNavigation {
    /// `TIME_CHART_WINDOW_SIZE` : sept périodes par page.
    static let windowSize = 7

    private static let swipeDistance = 24.0
    private static let swipeMinFlickDistance = 6.0
    private static let swipeVelocity = 220.0

    /// `timeChartPageCount` : nombre de pages nécessaires pour l'historique.
    static func pageCount(_ buckets: [ChartTimeBucket], windowSize: Int = 7) -> Int {
        let size = max(1, windowSize)
        return max(1, Int(ceil(Double(buckets.count) / Double(size))))
    }

    /// `timeChartWindow` : conserve toujours sept périodes, même avant une
    /// inscription récente (les colonnes manquantes sont remplies à zéro).
    static func window(
        _ buckets: [ChartTimeBucket],
        _ granularity: ChartTimeGranularity,
        pageIndex: Int,
        windowSize: Int = 7
    ) -> [ChartTimeBucket] {
        let size = max(1, windowSize)
        let safePage = max(0, pageIndex)
        let latest = buckets.last?.start ?? ChartTimeSeries.milliseconds(Date())
        let end = ChartTimeSeries.shift(latest, granularity, -safePage * size)
        let byStart = Dictionary(
            buckets.map { ($0.start, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        return (0..<size).map { index in
            let start = ChartTimeSeries.shift(end, granularity, index - size + 1)
            return byStart[start]
                ?? ChartTimeBucket(start: start, minutesBySubject: [:], minutes: 0)
        }
    }

    /// `timeChartPageLabel` : « Période actuelle » ou « Il y a N jours ».
    static func pageLabel(_ granularity: ChartTimeGranularity, pageIndex: Int) -> String {
        if pageIndex == 0 { return "Période actuelle" }
        let count = pageIndex * windowSize
        let unit: String
        switch granularity {
        case .day: unit = "jours"
        case .week: unit = "semaines"
        case .month: unit = "mois"
        }
        return "Il y a \(count) \(unit)"
    }

    /// `resolveTimeChartSwipePage` : page atteinte après un geste horizontal.
    static func resolveSwipePage(
        pageCount: Int,
        currentPage: Int,
        translationX: Double,
        velocityX: Double
    ) -> Int {
        let lastPage = max(0, pageCount - 1)
        let safePage = max(0, min(lastPage, currentPage))
        let distance = abs(translationX)
        let isFlick = distance > swipeMinFlickDistance && abs(velocityX) > swipeVelocity
        if distance <= swipeDistance && !isFlick { return safePage }
        let direction = distance > 2 ? translationX : velocityX
        return max(0, min(lastPage, safePage + (direction > 0 ? 1 : -1)))
    }

    /// `minuteAxisMaximum` : ordonnée supérieure arrondie à 1, 2 ou 5 × 10ⁿ.
    static func minuteAxisMaximum(_ minutes: Double) -> Double {
        let safeMinutes = max(1, minutes)
        let magnitude = pow(10, floor(log10(safeMinutes)))
        let normalized = safeMinutes / magnitude
        let step: Double
        if normalized <= 1 {
            step = 1
        } else if normalized <= 2 {
            step = 2
        } else if normalized <= 5 {
            step = 5
        } else {
            step = 10
        }
        return step * magnitude
    }
}
