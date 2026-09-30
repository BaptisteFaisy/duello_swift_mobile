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
    /// `refined` : tracé unique façon Trade Republic (`TrendCurve`), sans
    /// quadrillage ni axe, bord gauche touché.
    var refined: Bool = false

    /// Amplitude minimale de l'axe (`MIN_ELO_PADDING`).
    private static let minimumPadding = 20.0
    /// `TOOLTIP_WIDTH`.
    private static let tooltipWidth: CGFloat = 104

    var body: some View {
        if refined {
            refinedCurve
        } else if points.isEmpty {
            EmptyView()
        } else {
            content
        }
    }

    /// `refined` d'`EloChart.tsx` : la courbe affinée montre un point à zéro
    /// plutôt qu'un vide quand aucune mesure n'est disponible.
    private var refinedCurve: some View {
        let visible = ChartTimeSeries.windowGroupedPoints(points, granularity)
        let curvePoints: [TrendCurvePoint] = visible.isEmpty
            ? [TrendCurvePoint(at: ChartTimeSeries.milliseconds(Date()), value: 0)]
            : visible.map { TrendCurvePoint(at: $0.at, value: $0.elo) }
        let first = visible.first?.elo ?? 0
        let last = visible.last?.elo ?? 0
        return TrendCurve(
            points: curvePoints,
            formatValue: { "\(Int($0.rounded())) Elo" },
            formatDate: { ChartDateFormat.pointDate($0, granularity) },
            accessibilityLabel: "Évolution de l’Elo, de \(Int(first.rounded())) à \(Int(last.rounded()))"
        )
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
