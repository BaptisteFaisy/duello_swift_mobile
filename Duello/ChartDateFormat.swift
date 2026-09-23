//
//  ChartDateFormat.swift
//  Duello
//
//  Formatage des dates des graphiques (lot D « Graphiques », préfixe `Chart`).
//
//  Reprend les appels `toLocaleDateString('fr-FR', …)` de :
//    - src/components/XpChart.tsx            (`formatPointDate`)
//    - src/components/EloChart.tsx           (`formatPointDate`)
//    - src/components/CorrectionGradeChart.tsx (`shortDate`, `periodDate`)
//    - src/components/GradeChart.tsx         (`shortDate`)
//    - src/components/ExerciseMetricHistory.tsx (`historyDate`)
//
//  Cible iOS 16 ; locale `fr-FR` (mois abrégés à la française, virgule des
//  décimales). Aucune dépendance externe.
//
import Foundation

/// Formats de dates partagés par les graphiques `Chart…`.
enum ChartDateFormat {
    /// `formatPointDate` : « Départ », « juil. 2026 », « Sem. 15 juil. » ou « 15 juil. ».
    static func pointDate(_ at: Double, _ granularity: ChartTimeGranularity) -> String {
        if at <= 0 { return "Départ" }
        switch granularity {
        case .month: return monthYear(at)
        case .week: return "Sem. \(shortDate(ChartTimeSeries.date(at)))"
        case .day: return shortDate(ChartTimeSeries.date(at))
        }
    }

    /// `shortDate` : « 15 juil. ».
    static func shortDate(_ date: Date) -> String {
        shortDateFormatter.string(from: date)
    }

    /// `periodDate` de `CorrectionGradeChart.tsx` : « juil. 2026 », « Sem. 15 juil. » ou « 15 juil. ».
    static func periodDate(_ at: Double, _ granularity: ChartTimeGranularity) -> String {
        switch granularity {
        case .month: return monthYear(at)
        case .week: return "Sem. \(shortDate(ChartTimeSeries.date(at)))"
        case .day: return shortDate(ChartTimeSeries.date(at))
        }
    }

    /// `historyDate` de `ExerciseMetricHistory.tsx` :
    /// « 15 septembre 2026 à 14:05 ». La chaîne brute est rendue telle quelle si
    /// elle n'est pas datable.
    static func historyDate(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let parsed = parse(trimmed) else { return trimmed }
        return historyDateFormatter.string(from: parsed)
    }

    /// `monthYear` : « juil. 2026 ».
    private static func monthYear(_ at: Double) -> String {
        monthYearFormatter.string(from: ChartTimeSeries.date(at))
    }

    /// Analyse une date ISO 8601 (avec ou sans fraction de seconde).
    private static func parse(_ raw: String) -> Date? {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: raw) { return date }
        iso.formatOptions = [.withInternetDateTime]
        if let date = iso.date(from: raw) { return date }
        iso.formatOptions = [.withFullDate]
        return iso.date(from: raw)
    }

    /// Formateurs `fr-FR`, construits une seule fois (modèle `AdmFormat`) : les
    /// axes et infobulles des graphes les lisent à chaque évaluation de `body`.
    private static let shortDateFormatter = makeFormatter("d MMM")
    private static let historyDateFormatter = makeFormatter("dd MMMM yyyy 'à' HH:mm")
    private static let monthYearFormatter = makeFormatter("MMM yyyy")

    private static func makeFormatter(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = format
        return formatter
    }
}
