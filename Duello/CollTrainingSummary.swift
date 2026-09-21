//
//  CollTrainingSummary.swift
//  Duello
//
//  Bilan d'une soumission d'entraînement et décomptes de la fiche Maths de
//  démarrage.
//
//  Fichiers source Expo portés :
//    - src/utils/trainingSubmissionSummary.ts
//        `TrainingCorrectionSubmission`, `TrainingSuccessSummary`,
//        `scoreImprovementPercentage`, `isAnnaleAttemptFlawless`,
//        `submissionXpProgress`.
//    - src/utils/trainingStartupSummary.ts
//        `MATHS_SUBJECT_TOTALS`, `trainingStartupMathsSubjectTotal`,
//        `isAppliedMaths`.
//
//  Limite documentée : la source orchestre aussi des écritures persistées
//  (`recordExerciseCompletionReward`, `recordAnnaleScoreSubmission`,
//  `recordCorrectionGrade`). Ces effets restent portés par `ProgressStore` et le
//  bilan de correction ; ce fichier n'expose que les valeurs dérivées pures.
//  Cible : iOS 16, aucune dépendance externe.
//
import Foundation

/// Soumission d'une correction (`TrainingCorrectionSubmission`).
struct CollCorrectionSubmission: Equatable {
    var submissionId: String
    var startedAt: Double
    var submittedQuestionIds: [String]
    var spentSeconds: Double
}

/// Progression d'XP entre deux totaux (`XpProgressSnapshot`).
struct CollXpProgressSnapshot: Equatable {
    var totalBefore: Double
    var totalAfter: Double
}

/// Bilan d'une soumission réussie (`TrainingSuccessSummary`).
struct CollTrainingSuccessSummary: Equatable {
    var xp: Double
    var seconds: Double
    /// Bonus d'exercice reçu, quand il y en a un.
    var bonusXp: Double?
    var xpProgress: CollXpProgressSnapshot?
}

/// `scoreImprovementPercentage`, `isAnnaleAttemptFlawless` et le bilan.
enum CollTrainingSummary {
    /// `scoreImprovementPercentage` : progression relative, `nil` sans note
    /// précédente.
    static func improvementPercentage(score: Double, previous: Double?) -> Int? {
        guard let previous else { return nil }
        if previous == 0 { return score == 0 ? 0 : 100 }
        return Int((((score - previous) / previous) * 100).rounded())
    }

    /// `isAnnaleAttemptFlawless` : aucune mauvaise réponse, et première
    /// soumission.
    static func firstTry(submissionCount: Int, wrongAnswers: Int) -> Bool {
        submissionCount == 0 && wrongAnswers == 0
    }

    /// `submissionXpProgress` : la lecture reste stricte, une panne ne doit pas
    /// afficher un faux niveau 1.
    static func xpProgress(total: Double, gained: Double) -> CollXpProgressSnapshot {
        CollXpProgressSnapshot(totalBefore: max(0, total - gained), totalAfter: total)
    }

    /// `TrainingSuccessSummary` : XP total (questions + bonus) et durée passée.
    static func summary(
        questionXp: Double,
        bonusXp: Double,
        seconds: Double,
        xpProgress: CollXpProgressSnapshot?
    ) -> CollTrainingSuccessSummary {
        CollTrainingSuccessSummary(
            xp: questionXp + bonusXp,
            seconds: seconds,
            bonusXp: bonusXp > 0 ? bonusXp : nil,
            xpProgress: xpProgress
        )
    }
}

/// `trainingStartupMathsSubjectTotal` : décompte définitif de la fiche Maths.
enum CollTrainingStartup {
    /// `MATHS_SUBJECT_TOTALS` : compteurs canoniques du socle embarqué, repris
    /// tels quels de la source (données calibrées sur le catalogue complet).
    private static let mathsTotals: [String: Int] = [
        "ecg-approfondies-1": 6597,
        "ecg-approfondies-2": 3319,
        "ecg-appliquees-1": 4522,
        "ecg-appliquees-2": 3143,
        "mpsi-1": 3743,
        "mp-2": 1566,
        "psi-2": 0,
    ]

    /// Nombre définitif de sujets annoncé sur la fiche Maths de démarrage.
    static func mathsSubjectTotal(
        track: String,
        specialty: String,
        programTrack: String,
        year: Int
    ) -> Int {
        if track == "ECG" {
            let option = isAppliedMaths(specialty) ? "appliquees" : "approfondies"
            return mathsTotals["ecg-\(option)-\(year)"] ?? 0
        }
        if year == 1 { return mathsTotals["mpsi-1"] ?? 0 }
        return mathsTotals[programTrack == "PSI" ? "psi-2" : "mp-2"] ?? 0
    }

    /// `isAppliedMaths` : option appliquée de l'ECG.
    private static func isAppliedMaths(_ specialty: String) -> Bool {
        specialty.lowercased().contains("appliqu")
    }
}
