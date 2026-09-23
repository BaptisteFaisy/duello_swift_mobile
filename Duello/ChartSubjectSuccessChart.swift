//
//  ChartSubjectSuccessChart.swift
//  Duello
//
//  Taux d'exercices réussis par matière (lot D « Graphiques », préfixe `Chart`).
//
//  Fichier source Expo porté (libellés repris mot pour mot) :
//    - src/components/SubjectSuccessChart.tsx (`SubjectSuccessChart`,
//      `successPercent`, `accessibilityLabel`)
//
//  Échelle fixe 0 à 100 %, un point tactile par matière. La source relie les
//  points par des **segments droits** (vues pivotées) : `straightSegments`.
//  Cible iOS 16.
//
import SwiftUI

/// `SubjectSuccess` de `src/components/SubjectSuccessChart.tsx`.
struct ChartSubjectSuccess: Identifiable, Hashable {
    var subject: String
    /// Sujets entièrement réussis : exercices, colles et annales.
    var succeeded: Int
    /// Sujets disponibles dans la matière.
    var total: Int
    var id: String { subject }

    /// `successPercent` : arrondi du pourcentage de réussite.
    var percent: Double {
        total > 0 ? ((Double(succeeded) / Double(total)) * 100).rounded() : 0
    }
}

/// `SubjectSuccessChart` de `src/components/SubjectSuccessChart.tsx` : courbe du
/// taux d'exercices réussis, avec un point tactile par matière.
struct ChartSubjectSuccessChart: View {
    let entries: [ChartSubjectSuccess]

    /// `TOOLTIP_WIDTH`.
    private static let tooltipWidth: CGFloat = 148

    var body: some View {
        if entries.isEmpty { EmptyView() } else { content }
    }

    private var content: some View {
        let first = entries[0]
        let last = entries[entries.count - 1]
        let linePoints = entries.map { entry in
            ChartLinePoint(
                value: entry.percent,
                tooltip: entry.total > 0 ? "\(Int(entry.percent)) %" : "À venir",
                tooltipTitle: entry.subject,
                tooltipAnnotation: entry.total > 0
                    ? " · \(entry.succeeded)/\(entry.total) réussis"
                    : nil
            )
        }
        return ChartSmoothLineChart(
            points: linePoints,
            lower: 0,
            upper: 100,
            topAxisLabel: "100 %",
            bottomAxisLabel: "0 %",
            firstAxisLabel: first.subject,
            lastAxisLabel: last.subject,
            accessibility: "Réussites par matière, de \(accessibility(first)) à \(accessibility(last))",
            dotSize: 8,
            axisWidth: 32,
            tooltipHeight: 46,
            tooltipLeading: 38,
            showsLastAxisLabel: entries.count > 1,
            strongLastDot: true,
            tooltipWidth: Self.tooltipWidth,
            xAxisTopPadding: 8,
            xAxisLeading: 38,
            straightSegments: true,
            tooltipTitleFont: .system(size: 10, weight: .black)
        )
    }

    private func accessibility(_ entry: ChartSubjectSuccess) -> String {
        guard entry.total > 0 else {
            return "\(entry.subject) : aucun exercice disponible"
        }
        let plural = entry.succeeded > 1 ? "s" : ""
        return "\(entry.subject) : \(entry.succeeded) exercice\(plural) réussi\(plural) sur \(entry.total), \(Int(entry.percent)) %"
    }
}
