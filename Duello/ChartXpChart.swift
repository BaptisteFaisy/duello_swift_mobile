//
//  ChartXpChart.swift
//  Duello
//
//  Courbe du total d'XP (lot D « Graphiques », préfixe `Chart`).
//
//  Fichier source Expo porté (libellés repris mot pour mot) :
//    - src/components/XpChart.tsx (`XpChart`, `formatPointDate`)
//
//  Réutilise `ChartSmoothLineChart` (`ChartLinePlot.swift`) et `ExGFormat.xp`
//  (`ExGXpFoundation.swift`) pour le formatage des XP. La variante « application
//  de bureau téléchargée » (`PLOT_HEIGHT` 196, `PLOT_INSET` 8) est conservée via
//  `downloadedDesktop`. Cible iOS 16.
//
import SwiftUI

/// `XpChart` de `src/components/XpChart.tsx` : courbe cumulée du total d'XP,
/// avec lecture tactile de chaque période.
struct ChartXpChart: View {
    /// Courbe cumulée, de la première à la dernière période.
    let points: [ChartXpSeriesPoint]
    let granularity: ChartTimeGranularity
    var showsDateRange: Bool = true
    /// `isDownloadedDesktopApp()` : tracé plus haut et marge de point élargie.
    var downloadedDesktop: Bool = false

    /// `TOOLTIP_WIDTH`.
    private static let tooltipWidth: CGFloat = 116

    var body: some View {
        if points.isEmpty { EmptyView() } else { content }
    }

    private var content: some View {
        let values = points.map(\.xp)
        let lowest = values.min() ?? 0
        let highest = values.max() ?? 0
        let padding = max((highest - lowest) * 0.2, 5)
        let lower = max(0, lowest - padding)
        let upper = highest + padding
        let last = points[points.count - 1]
        let linePoints = points.map { point in
            ChartLinePoint(
                value: point.xp,
                tooltip: "\(ExGFormat.xp(point.xp)) XP",
                tooltipAnnotation: " · \(ChartDateFormat.pointDate(point.at, granularity))"
            )
        }
        return ChartSmoothLineChart(
            points: linePoints,
            lower: lower,
            upper: upper,
            topAxisLabel: ExGFormat.xp(upper),
            bottomAxisLabel: ExGFormat.xp(lower),
            firstAxisLabel: ChartDateFormat.pointDate(points[0].at, granularity),
            lastAxisLabel: ChartDateFormat.pointDate(last.at, granularity),
            accessibility: "Évolution \(granularity.name) de l’XP, de \(ExGFormat.xp(points[0].xp)) à \(ExGFormat.xp(last.xp)) XP",
            height: downloadedDesktop ? 196 : 128,
            axisWidth: 40,
            showsDateRange: showsDateRange,
            tooltipLeading: 46,
            tooltipWidth: Self.tooltipWidth,
            xAxisLeading: 40,
            plotInset: downloadedDesktop ? 8 : nil
        )
    }
}
