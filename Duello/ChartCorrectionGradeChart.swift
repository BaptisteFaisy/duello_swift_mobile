//
//  ChartCorrectionGradeChart.swift
//  Duello
//
//  Moyenne des notes de correction par période (lot D « Graphiques »,
//  préfixe `Chart`).
//
//  Fichier source Expo porté (libellés repris mot pour mot) :
//    - src/components/CorrectionGradeChart.tsx (`CorrectionGradeChart`,
//      `ACTIVITY_LABELS`, `shortDate`, `periodDate`, `formatScore`)
//
//  Échelle fixe 0 à 20, courbe bornée aux 24 derniers points. Cible iOS 16.
//
import SwiftUI

/// `CorrectionGradeActivity` de `utils/correctionGradeHistory.ts`.
enum ChartCorrectionActivity: String, Hashable {
    case exercice
    case colle
    case annale
    case defi
    case entrainement

    /// `ACTIVITY_LABELS` de `CorrectionGradeChart.tsx`.
    var label: String {
        switch self {
        case .exercice: return "Exercice"
        case .colle: return "Colle"
        case .annale: return "Annale"
        case .defi: return "Défi"
        case .entrainement: return "Exercice ou colle"
        }
    }
}

/// `CorrectionGradeEntry` de `utils/correctionGradeHistory.ts` réduit au tracé.
struct ChartCorrectionEntry: Identifiable, Hashable {
    var id: String
    var activity: ChartCorrectionActivity
    var score: Double
    var submittedAt: Double
    var subject: String? = nil
    var title: String? = nil
}

/// `CorrectionGradePeriodPoint` de `utils/correctionGradeHistory.ts`.
struct ChartCorrectionPeriodPoint: Identifiable, Hashable {
    var at: Double
    var score: Double
    var entries: [ChartCorrectionEntry]
    var id: Double { at }
}

/// `CorrectionGradeChart` de `src/components/CorrectionGradeChart.tsx` :
/// moyenne des notes par période, sur une échelle fixe de 0 à 20.
struct ChartCorrectionGradeChart: View {
    let points: [ChartCorrectionPeriodPoint]
    let granularity: ChartTimeGranularity
    var showsDateRange: Bool = true

    /// `MAX_POINTS` : la courbe est bornée aux 24 dernières périodes.
    private let maxPoints = 24
    /// `TOOLTIP_WIDTH`.
    private static let tooltipWidth: CGFloat = 168

    var body: some View {
        if visible.isEmpty { EmptyView() } else { content }
    }

    private var visible: [ChartCorrectionPeriodPoint] {
        Array(points.suffix(maxPoints))
    }

    private var content: some View {
        let first = visible[0]
        let last = visible[visible.count - 1]
        let linePoints = visible.map { point in
            ChartLinePoint(
                value: point.score,
                tooltip: "\(ExGFormat.xp(point.score))/20",
                tooltipTitle: tooltipTitle(for: point),
                tooltipAnnotation: " · \(ChartDateFormat.periodDate(point.at, granularity))"
            )
        }
        return ChartSmoothLineChart(
            points: linePoints,
            lower: 0,
            upper: 20,
            topAxisLabel: "20",
            bottomAxisLabel: "0",
            firstAxisLabel: ChartDateFormat.periodDate(first.at, granularity),
            lastAxisLabel: ChartDateFormat.periodDate(last.at, granularity),
            accessibility: "Évolution \(granularity.name) des notes de correction sur 20, de \(ExGFormat.xp(first.score)) à \(ExGFormat.xp(last.score))",
            axisWidth: 32,
            showsDateRange: showsDateRange,
            middleAxisLabel: "10",
            tooltipWidth: Self.tooltipWidth,
            tooltipVerticalPadding: 5
        )
    }

    private func tooltipTitle(for point: ChartCorrectionPeriodPoint) -> String {
        point.entries.count == 1
            ? (point.entries[0].title ?? point.entries[0].activity.label)
            : "Moyenne de \(point.entries.count) corrections"
    }
}
