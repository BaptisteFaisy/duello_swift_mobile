//
//  ChartGradeSeries.swift
//  Duello
//
//  Séries de notes et tracé lissé (lot D « Graphiques », préfixe `Chart`).
//
//  Fichiers source Expo portés (noms et libellés repris) :
//    - src/utils/gradeChart.ts      (`GradePoint`, `GradeSeries`,
//                                    `buildGradePoints`, `buildGradeSeries`)
//    - src/utils/smoothChartPath.ts (`ChartPathPoint`, `buildSmoothChartPath`)
//
//  Couleurs de `SERIES_COLORS` reprises de `GradeChart.tsx`. Cible iOS 16.
//
import SwiftUI

/// `GradeType` de `types.ts`.
enum ChartGradeType: String, CaseIterable, Hashable {
    case ds = "DS"
    case dm = "DM"
    case colle = "Colle"
    case tp = "TP"
    case autre = "Autre"

    /// Couleurs de `SERIES_COLORS` de `GradeChart.tsx`.
    var color: Color {
        switch self {
        case .ds: return Color(hex: 0x2563EB)
        case .dm: return Color(hex: 0xD97706)
        case .colle: return Color(hex: 0x7C3AED)
        case .tp: return Color(hex: 0x15803D)
        case .autre: return Color(hex: 0x6B7280)
        }
    }
}

/// `Grade` de `types.ts` réduit aux champs de la courbe.
struct ChartGradeEntry: Hashable {
    var id: String
    var subject: String
    var type: ChartGradeType
    var grade: Double
    var outOf: Double
    var date: Date
}

/// `GradePoint` de `utils/gradeChart.ts`.
struct ChartGradePoint: Identifiable, Hashable {
    var id: String
    var subject: String
    var type: ChartGradeType
    var value: Double
    var date: Date
}

/// `GradeSeries` de `utils/gradeChart.ts`.
struct ChartGradeSeriesGroup: Identifiable, Hashable {
    var type: ChartGradeType
    var points: [ChartGradePoint]
    var id: ChartGradeType { type }
}

/// `buildGradePoints`/`buildGradeSeries` de `utils/gradeChart.ts`.
enum ChartGradeSeries {
    /// Ordre des séries (`GRADE_TYPE_ORDER`).
    static let typeOrder: [ChartGradeType] = [.ds, .dm, .colle, .tp, .autre]

    /// Trie les notes valides, les ramène sur 20 et borne la courbe à 16 points.
    static func buildPoints(_ grades: [ChartGradeEntry]) -> [ChartGradePoint] {
        let mapped = grades
            .filter { $0.grade.isFinite && $0.outOf.isFinite && $0.outOf > 0 }
            .map {
                ChartGradePoint(
                    id: $0.id,
                    subject: $0.subject,
                    type: $0.type,
                    value: max(0, min(20, ($0.grade / $0.outOf) * 20)),
                    date: $0.date
                )
            }
            // `buildGradePoints` écarte aussi les dates non finies
            // (`gradeChart.ts:34`) ; une `Date` Swift l'est toujours, la garde
            // reste pour rester aligné sur la source.
            .filter { $0.date.timeIntervalSince1970.isFinite }
            .sorted { $0.date < $1.date }
        return Array(mapped.suffix(16))
    }

    /// Sépare les points par type sans perdre leur ordre chronologique.
    static func buildSeries(_ points: [ChartGradePoint]) -> [ChartGradeSeriesGroup] {
        var result: [ChartGradeSeriesGroup] = []
        for type in typeOrder {
            let matching = points.filter { $0.type == type }
            if !matching.isEmpty {
                result.append(ChartGradeSeriesGroup(type: type, points: matching))
            }
        }
        return result
    }
}

/// `ChartPathPoint` de `utils/smoothChartPath.ts`.
struct ChartPathPoint: Hashable {
    var x: Double
    var y: Double
}

/// `buildSmoothChartPath` de `utils/smoothChartPath.ts`.
enum ChartSmoothPath {
    /// Relie chaque mesure par une courbe cubique qui reste dans l'intervalle des
    /// deux points : tangentes horizontales partagées, sans dépassement.
    static func path(_ points: [ChartPathPoint]) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: CGPoint(x: first.x, y: first.y))
        guard points.count > 1 else { return path }

        for index in 1..<points.count {
            let start = points[index - 1]
            let end = points[index]
            let offset = (end.x - start.x) * 0.4
            path.addCurve(
                to: CGPoint(x: end.x, y: end.y),
                control1: CGPoint(x: start.x + offset, y: start.y),
                control2: CGPoint(x: end.x - offset, y: end.y)
            )
        }
        return path
    }
}
