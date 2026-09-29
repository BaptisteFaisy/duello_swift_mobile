//
//  RankingPerformance.swift
//  Duello
//
//  Moyenne et tendance des notes du profil.
//
//  Fichier source Expo porté (mêmes seuils que la source) :
//    - src/utils/performance.ts
//        `validPerformanceGrade`, `calculateGradeAverage`, `calculateGradeTrend`.
//    - src/types.ts (`Grade` : `grade`, `outOf`, `coefficient`, `date`).
//
//  À raccorder (vague 5) : `buildOwnPerformance` assemble ces deux calculs avec
//  les tâches de programme, la série d'activité et le résumé d'XP
//  (`buildXpSummary`) ; ses entrées (`Task`, `XpActivity`) ne sont pas portées
//  dans ce lot — la publication du profil (`ReportLocalSnapshot.swift:159`)
//  reste donc au repli `average: "—"` tant que le store de notes n'est pas lu.
//
//  Cible : iOS 16, aucune dépendance externe.
//
import Foundation

/// `Grade` de `types.ts` réduit aux notes du profil.
struct RankingGrade: Equatable {
    /// Note obtenue.
    var grade: Double
    /// Barème de la note (`outOf`).
    var outOf: Double
    /// Poids de la note dans la moyenne.
    var coefficient: Double
    /// Date de la note, en texte (ISO ou `AAAA-MM-JJ`).
    var date: String
}

/// `utils/performance.ts` : moyenne et tendance des notes du profil.
enum RankingPerformance {

    /// `validPerformanceGrade` : note, barème et coefficient exploitables.
    static func isValid(_ grade: RankingGrade) -> Bool {
        grade.grade.isFinite
            && grade.outOf.isFinite && grade.outOf > 0
            && grade.coefficient.isFinite && grade.coefficient > 0
    }

    /// `calculateGradeAverage` : moyenne pondérée ramenée sur 20, `nil` sans note
    /// valide ni coefficient.
    static func calculateGradeAverage(_ grades: [RankingGrade]) -> Double? {
        let valid = grades.filter(isValid)
        guard !valid.isEmpty else { return nil }
        let coefficientTotal = valid.reduce(0) { $0 + $1.coefficient }
        guard coefficientTotal > 0 else { return nil }
        let weighted = valid.reduce(0) {
            $0 + ($1.grade / $1.outOf) * 20 * $1.coefficient
        }
        let average = weighted / coefficientTotal
        return average.isFinite ? average : nil
    }

    /// `calculateGradeTrend` : variation relative entre la seconde moitié et la
    /// première des notes triées par date, `nil` sans au moins deux notes valides
    /// ni moyenne antérieure exploitable.
    static func calculateGradeTrend(_ grades: [RankingGrade]) -> Double? {
        let valid = grades.filter(isValid)
        guard valid.count >= 2 else { return nil }
        let sorted = valid.sorted { parseDate($0.date) < parseDate($1.date) }
        let splitIndex = sorted.count / 2
        guard let firstAverage = calculateGradeAverage(Array(sorted[0..<splitIndex])),
              let secondAverage = calculateGradeAverage(Array(sorted[splitIndex...])),
              firstAverage != 0
        else { return nil }
        return ((secondAverage - firstAverage) / firstAverage) * 100
    }

    /// Millisecondes d'une date ; une date illisible vaut zéro (comme le `NaN`
    /// de `Date.parse` côté RN, qui laisse l'ordre inchangé).
    private static func parseDate(_ value: String) -> Double {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: trimmed) { return date.timeIntervalSince1970 * 1000 }
        iso.formatOptions = [.withInternetDateTime]
        if let date = iso.date(from: trimmed) { return date.timeIntervalSince1970 * 1000 }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        if let date = formatter.date(from: trimmed) { return date.timeIntervalSince1970 * 1000 }
        return 0
    }
}
