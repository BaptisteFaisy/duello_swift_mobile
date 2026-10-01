//
//  CorrectionGradeHistory.swift
//  Duello
//
//  Notes rendues par les corrections : types, identifiants et normalisation.
//
//  Fichier source Expo porté (libellés et seuils repris mot pour mot) :
//    - src/utils/correctionGradeHistory.ts
//        `CorrectionGradeActivity`, `CorrectionGradeEntry`,
//        `CorrectionGradeInput`, `CorrectionGradePeriodPoint`,
//        `trainingCorrectionGradeId`, `annaleCopyCorrectionGradeId`,
//        `duelCorrectionGradeId`, `normalizeCorrectionGradeEntry`,
//        `mergeCorrectionGradeEntries`, `chronologicalCorrectionGrades`.
//
//  La lecture et l'écriture (`parseCorrectionGradeHistory`,
//  `loadCorrectionGradeHistory`, `recordCorrectionGrade`,
//  `groupCorrectionGradesByPeriod`, `formatCorrectionGradeScore`) vivent dans
//  `CorrectionGradeStore.swift`.
//
//  À raccorder (vague 5) : `legacyCorrectionGradeEntries` et
//  `loadCorrectionGradeTimeline` dépendent de `loadAnnaleAttempts`
//  (`utils/annaleAttempt.ts`) et de `loadAnnaleCopyCorrectionJobs`
//  (`utils/annaleCopyCorrection.ts`), non portés dans ce lot.
//
//  Cible : iOS 16, aucune dépendance externe.
//
import Foundation

/// `CorrectionGradeActivity` : activité d'une note de correction
/// (`TrainingActivity` élargi à « entrainement »).
enum CorrectionGradeActivity: String, Codable, CaseIterable {
    case exercice
    case colle
    case annale
    case defi
    case entrainement
    /// Les événements filtrent la moyenne : aucune écriture ne les produit
    /// encore (`correctionGradeHistory.ts:15`).
    case evenement
}

/// `CorrectionGradeEntry` : note définitive rendue par une correction, toujours
/// ramenée sur 20.
struct CorrectionGradeEntry: Codable, Equatable, Identifiable {
    /// Identifiant idempotent de la correction à l'origine de la note.
    var id: String
    var activity: CorrectionGradeActivity
    var score: Double
    var submittedAt: Double
    var subject: String?
    var title: String?
    /// Sujets concernés, afin qu'un changement de programme puisse les retirer.
    var itemIds: [String]

    init(
        id: String,
        activity: CorrectionGradeActivity,
        score: Double,
        submittedAt: Double,
        subject: String? = nil,
        title: String? = nil,
        itemIds: [String] = []
    ) {
        self.id = id
        self.activity = activity
        self.score = score
        self.submittedAt = submittedAt
        self.subject = subject
        self.title = title
        self.itemIds = itemIds
    }
}

/// `CorrectionGradeInput` : note à enregistrer (`activity` est une activité
/// d'entraînement, jamais « entrainement »).
struct CorrectionGradeInput {
    var id: String
    var activity: CollTrainingActivity
    var score: Double
    var submittedAt: Double
    var subject: String?
    var title: String?
    var itemIds: [String] = []
}

/// `CorrectionGradePeriodPoint` : moyenne des notes rendues sur une période.
struct CorrectionGradePeriodPoint: Identifiable, Equatable {
    var at: Double
    var score: Double
    var entries: [CorrectionGradeEntry]
    var id: Double { at }
}

/// Identifiants idempotents et normalisation des notes de correction
/// (`utils/correctionGradeHistory.ts`).
enum CorrectionGradeHistory {

    // MARK: - Identifiants idempotents

    /// `trainingCorrectionGradeId`.
    static func trainingCorrectionGradeId(_ submissionId: String) -> String {
        "training:\(submissionId)"
    }

    /// `annaleCopyCorrectionGradeId`.
    static func annaleCopyCorrectionGradeId(_ jobId: String) -> String {
        "annale-copy:\(jobId)"
    }

    /// `duelCorrectionGradeId`.
    static func duelCorrectionGradeId(_ matchId: String) -> String {
        "duel:\(matchId)"
    }

    // MARK: - Normalisation

    /// `normalizeCorrectionGradeEntry` : écarte toute note sans identifiant,
    /// activité connue, score sur 20 ou horodatage exploitable.
    static func normalize(_ value: CorrectionGradeEntry?) -> CorrectionGradeEntry? {
        guard let value else { return nil }
        guard let id = cleanText(value.id, limit: 300),
              let score = cleanScore(value.score),
              let submittedAt = cleanTimestamp(value.submittedAt)
        else { return nil }
        return CorrectionGradeEntry(
            id: id,
            activity: value.activity,
            score: score,
            submittedAt: submittedAt,
            subject: cleanText(value.subject, limit: 120),
            title: cleanText(value.title, limit: 240),
            itemIds: cleanItemIds(value.itemIds)
        )
    }

    /// `mergeCorrectionGradeEntries` : les groupes placés à droite remplacent
    /// les replis historiques homonymes (même identifiant).
    static func merge(_ groups: [[CorrectionGradeEntry]]) -> [CorrectionGradeEntry] {
        var byId: [String: CorrectionGradeEntry] = [:]
        for group in groups {
            for value in group {
                if let entry = normalize(value) { byId[entry.id] = entry }
            }
        }
        return chronological(Array(byId.values))
    }

    /// `chronologicalCorrectionGrades` : du plus ancien au plus récent, à rang
    /// stable (départage par identifiant, comparaison sensible à la locale,
    /// comme `id.localeCompare` de la source).
    static func chronological(_ entries: [CorrectionGradeEntry]) -> [CorrectionGradeEntry] {
        entries.sorted { first, second in
            if first.submittedAt != second.submittedAt {
                return first.submittedAt < second.submittedAt
            }
            return first.id.localizedCompare(second.id) == .orderedAscending
        }
    }

    // MARK: - Assainissement des champs

    /// `cleanText` : texte réduit à sa longueur maximale, vide écarté.
    static func cleanText(_ value: String?, limit: Int) -> String? {
        guard let value else { return nil }
        let cleaned = String(
            value.trimmingCharacters(in: .whitespacesAndNewlines).prefix(limit)
        )
        return cleaned.isEmpty ? nil : cleaned
    }

    /// `cleanScore` : note bornée à [0, 20], arrondie au dixième.
    static func cleanScore(_ value: Double?) -> Double? {
        guard let value, value.isFinite, value >= 0, value <= 20 else { return nil }
        return (value * 10).rounded() / 10
    }

    /// `cleanTimestamp` : horodatage fini et positif.
    static func cleanTimestamp(_ value: Double?) -> Double? {
        guard let value, value.isFinite, value >= 0 else { return nil }
        return value
    }

    /// `cleanItemIds` : identifiants de sujets assainis, sans doublon.
    static func cleanItemIds(_ value: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for item in value {
            guard let cleaned = cleanText(item, limit: 240) else { continue }
            if seen.insert(cleaned).inserted { result.append(cleaned) }
        }
        return result
    }
}
