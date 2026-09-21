//
//  ExGCorrectionModels.swift
//  Duello
//
//  Modèles du bilan de correction : verdict par question, question et
//  progression de la correction (`SuccessSummary.types.ts`, `gradingScore.ts`).
//
//  Fichiers source Expo portés (libellés repris mot pour mot) :
//    - src/components/SuccessSummary.types.ts           (SuccessSummaryProps)
//    - src/utils/gradingScore.ts
//
//  Découpé de `ExerciseGradingViews.swift` (1 975 lignes) le 2026-09-21 : contenu
//  repris ligne pour ligne — aucun type, propriété, méthode ni signature renommé.
//  Spécification de référence : specs/exws_C.md (§0 socle commun, §1 à §5
//  composants, §6 récapitulatif animations, §7 dépendances non portables).
//  Cible : iOS 16, aucune API iOS 17.
//
import SwiftUI

// MARK: - Bilan de correction : modèles

/// `SuccessSummaryQuestionStatus` de `SuccessSummary.types.ts`.
enum ExGQuestionStatus: String, CaseIterable, Identifiable {
    case pending, perfect, correct, partial, incorrect, error, unanswered

    var id: String { rawValue }

    /// `QUESTION_STATUS` de `CorrectionQuestionList.tsx`.
    var label: String {
        switch self {
        case .pending: return "En correction"
        case .perfect: return "Parfait"
        case .correct: return "Correct"
        case .partial: return "À ajuster"
        case .incorrect: return "Incorrect"
        case .error: return "À relancer"
        case .unanswered: return "Non répondue"
        }
    }

    var foreground: Color {
        switch self {
        case .perfect, .correct: return Theme.gradingPerfectHex.color
        case .partial: return Theme.gradingPartialHex.color
        case .incorrect: return Theme.like
        case .pending, .error, .unanswered: return Theme.inkSoft
        }
    }

    var background: Color {
        switch self {
        case .perfect: return Theme.gradingPerfectLightHex.color
        case .correct: return Theme.progressLight
        case .partial: return Theme.gradingPartialLightHex.color
        case .incorrect: return exgLikeLight
        case .pending, .error, .unanswered: return Theme.surfaceMuted
        }
    }

    /// `VERDICT_SCORE_COEFFICIENT` de `utils/gradingScore.ts` : parfait 1,
    /// correct 0,8, partiel 0,4, incorrect 0. Les statuts sans verdict — en
    /// correction, à relancer, non répondue — ne rapportent rien.
    var pointsCoefficient: Double {
        switch self {
        case .perfect: return 1
        case .correct: return 0.8
        case .partial: return 0.4
        case .incorrect, .pending, .error, .unanswered: return 0
        }
    }
}

/// Une question du bilan (`SuccessSummaryQuestion`), augmentée du barème
/// quand l'écran le connaît : c'est ce qui permet d'afficher les points
/// obtenus critère par critère à côté du verdict.
struct ExGQuestion: Identifiable, Equatable {
    var id: String
    var label: String
    var status: ExGQuestionStatus
    var reportAvailable: Bool = false
    var feedback: String? = nil
    /// Points obtenus sur cette question, quand le barème est connu.
    var earnedPoints: Double? = nil
    /// Barème de la question, quand il est connu.
    var maximumPoints: Double? = nil

    /// `3 / 5 pts`, ou `nil` si le barème n'est pas connu.
    var pointsText: String? {
        guard let earned = earnedPoints, let maximum = maximumPoints, maximum > 0 else { return nil }
        return "\(ExGFormat.xp(earned)) / \(ExGFormat.xp(maximum)) pts"
    }
}

/// Progression d'une correction (`SuccessSummaryCorrection`).
struct ExGCorrection: Equatable {
    /// Instant de soumission, en millisecondes depuis l'époque.
    var startedAt: Double
    /// Durée prudente d'une réponse, apprise des corrections mesurées.
    var questionSeconds: Double
    var completed: Bool
    var done: Int
    var total: Int
    var questions: [ExGQuestion]
}
