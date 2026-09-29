//
//  CollCorrectionGrade.swift
//  Duello
//
//  Journal des notes rendues par une correction (`utils/correctionGradeHistory.ts`).
//
//  Fichier source Expo porté (libellés repris mot pour mot) :
//    - src/utils/correctionGradeHistory.ts
//        `CorrectionGradeActivity`, `CorrectionGradeEntry`,
//        `CorrectionGradePeriodPoint`, `trainingCorrectionGradeId`,
//        `annaleCopyCorrectionGradeId`, `duelCorrectionGradeId`,
//        `mergeCorrectionGradeEntries`, `groupCorrectionGradesByPeriod`,
//        `chronologicalCorrectionGrades`, `formatCorrectionGradeScore`.
//
//  La lecture tolérante (`normalizeCorrectionGradeEntry`,
//  `parseCorrectionGradeHistory`) vit dans `CollCorrectionGradeParsing.swift` ;
//  la persistance (`load`/`record`/`timeline`) dans
//  `CollCorrectionGradeStore.swift`. Cible : iOS 16.
//
import Foundation

/// `CorrectionGradeActivity` : origine d'une note. `entrainement` couvre les
/// anciens bilans d'exercices et de colles, indistincts avant le journal.
enum CollCorrectionActivity: String, Codable, CaseIterable {
    case exercice
    case colle
    case annale
    case defi
    case entrainement
}

/// `CorrectionGradeEntry` : note définitive rendue par une correction, toujours
/// ramenée sur 20.
struct CollCorrectionGradeEntry: Codable, Equatable, Identifiable {
    /// Identifiant idempotent de la correction à l'origine de la note.
    var id: String
    var activity: CollCorrectionActivity
    var score: Double
    var submittedAt: Double
    var subject: String?
    var title: String?
    /// Sujets concernés, afin qu'un changement de programme puisse les retirer.
    var itemIds: [String]
}

/// `CorrectionGradeInput` : note à enregistrer ; `itemIds` vaut vide par défaut.
struct CollCorrectionGradeInput {
    var id: String
    var activity: CollCorrectionActivity
    var score: Double
    var submittedAt: Double
    var subject: String?
    var title: String?
    var itemIds: [String] = []
}

/// `CorrectionGradePeriodPoint` : moyenne des notes d'une période.
struct CollCorrectionGradePeriod: Equatable {
    var at: Double
    var score: Double
    var entries: [CollCorrectionGradeEntry]
}

/// Identifiants idempotents d'une note (`trainingCorrectionGradeId`,
/// `annaleCopyCorrectionGradeId`, `duelCorrectionGradeId`).
enum CollCorrectionGradeIds {
    static func training(_ submissionId: String) -> String { "training:\(submissionId)" }
    static func annaleCopy(_ jobId: String) -> String { "annale-copy:\(jobId)" }
    static func duel(_ matchId: String) -> String { "duel:\(matchId)" }
}

/// Fusion, agrégation et formatage du journal (`utils/correctionGradeHistory.ts`).
enum CollCorrectionGrades {
    /// `mergeCorrectionGradeEntries` : les groupes placés à droite remplacent
    /// les replis historiques homonymes, puis tri chronologique.
    static func merge(_ groups: [[CollCorrectionGradeEntry]]) -> [CollCorrectionGradeEntry] {
        var byId: [String: CollCorrectionGradeEntry] = [:]
        for group in groups {
            for value in group {
                if let entry = CollCorrectionGradeParsing.normalizeEntry(value) {
                    byId[entry.id] = entry
                }
            }
        }
        return chronological(Array(byId.values))
    }

    /// `groupCorrectionGradesByPeriod` : une moyenne par période, à la même
    /// granularité que les autres courbes.
    static func groupByPeriod(
        _ entries: [CollCorrectionGradeEntry],
        granularity: ChartTimeGranularity
    ) -> [CollCorrectionGradePeriod] {
        var byPeriod: [Double: [CollCorrectionGradeEntry]] = [:]
        for entry in chronological(entries) {
            let start = ChartTimeSeries.bucketStart(entry.submittedAt, granularity)
            byPeriod[start, default: []].append(entry)
        }
        return byPeriod.keys.sorted().map { at in
            let period = byPeriod[at] ?? []
            let sum = period.reduce(0.0) { $0 + $1.score }
            let average = period.isEmpty ? 0 : sum / Double(period.count)
            return CollCorrectionGradePeriod(
                at: at,
                score: (average * 10).rounded() / 10,
                entries: period
            )
        }
    }

    /// `chronologicalCorrectionGrades` : par date, puis par identifiant.
    static func chronological(
        _ entries: [CollCorrectionGradeEntry]
    ) -> [CollCorrectionGradeEntry] {
        entries.sorted { first, second in
            first.submittedAt == second.submittedAt
                ? first.id < second.id
                : first.submittedAt < second.submittedAt
        }
    }

    /// `formatCorrectionGradeScore` : un chiffre après la virgule.
    static func formatScore(_ score: Double) -> String {
        ExGFormat.xp(score)
    }
}
