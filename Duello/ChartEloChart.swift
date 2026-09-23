//
//  ChartEloChart.swift
//  Duello
//
//  Courbe d'Elo (lot D « Graphiques », préfixe `Chart`).
//
//  Fichier source Expo porté (libellés repris mot pour mot) :
//    - src/components/EloChart.tsx (`EloChart`, `formatPointDate`)
//
//  `EloSeriesPoint` provient de `utils/subjectElo.ts` ; la valeur est une
//  clôture par période. Réutilise `ChartSmoothLineChart`. Cible iOS 16.
//
import SwiftUI

/// `EloSeriesPoint` de `utils/subjectElo.ts` réduit à la courbe.
struct ChartEloSeriesPoint: Identifiable, Hashable {
    let id = UUID()
    var elo: Double
    var at: Double
}

/// `EloChart` de `src/components/EloChart.tsx` : une valeur de clôture par
/// jour, semaine ou mois.
struct ChartEloChart: View {
    /// Courbe à tracer, de la première à la dernière période.
    let points: [ChartEloSeriesPoint]
    let granularity: ChartTimeGranularity
    var showsDateRange: Bool = true

    /// Amplitude minimale de l'axe (`MIN_ELO_PADDING`).
    private static let minimumPadding = 20.0
    /// `TOOLTIP_WIDTH`.
    private static let tooltipWidth: CGFloat = 104

    var body: some View {
        if points.isEmpty { EmptyView() } else { content }
    }

    private var content: some View {
        let values = points.map(\.elo)
        let lowest = values.min() ?? 0
        let highest = values.max() ?? 0
        let padding = max(((highest - lowest) * 0.2).rounded(), Self.minimumPadding)
        let lower = lowest - padding
        let upper = highest + padding
        let last = points[points.count - 1]
        let linePoints = points.map { point in
            ChartLinePoint(
                value: point.elo,
                tooltip: "\(eloText(point.elo)) Elo",
                tooltipAnnotation: " · \(ChartDateFormat.pointDate(point.at, granularity))"
            )
        }
        return ChartSmoothLineChart(
            points: linePoints,
            lower: lower,
            upper: upper,
            topAxisLabel: eloText(upper),
            bottomAxisLabel: eloText(lower),
            firstAxisLabel: ChartDateFormat.pointDate(points[0].at, granularity),
            lastAxisLabel: ChartDateFormat.pointDate(last.at, granularity),
            accessibility: "Évolution \(granularity.name) de l’Elo, de \(eloText(points[0].elo)) à \(eloText(last.elo))",
            axisWidth: 32,
            showsDateRange: showsDateRange,
            tooltipLeading: 38,
            tooltipWidth: Self.tooltipWidth,
            xAxisTopPadding: 8,
            xAxisLeading: 38
        )
    }

    /// Un Elo s'affiche en entier, sans décimale (la source l'arrondit déjà).
    private func eloText(_ value: Double) -> String {
        String(Int(value.rounded()))
    }
}
