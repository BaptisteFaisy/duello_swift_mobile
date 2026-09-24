//
//  ProgPrereq.swift
//  Duello
//
//  Phase 0 (socle) du chantier « graphe de prérequis » : contrat GELÉ de la
//  revue de prérequis par exercice, partagé par les modules de filière.
//
//  Port des types de revue RN (`ExercisePrerequisiteReview` de
//  src/data/tracks.ts, et les interfaces `Reviewable*Exercise` de
//  src/data/*Prerequisites.ts).
//
//  Réutilise sans les redéfinir (ne pas modifier) :
//    - `SubjChapterPrerequisite`, `SubjRequiredCourseStatus`,
//      `SubjQuestionReviewSource` (`SubjChapterPrerequisites.swift`) ;
//    - `SubjProgramYear` (`SubjFlashcardSelection.swift`).
//
//  ⚠️ Phase 1b : `ProgPrereq.review(_:)` **aiguille** par `bankId` vers la revue
//  portée de la filière (`ProgPrereqMpsi`, `ProgPrereqMp`, `ProgPrereqLycee`,
//  `ProgPrereqEcgApplied`, `ProgPrereqEcgAdvanced`). Un scope inconnu renvoie
//  `nil` — jamais d'état inventé pour une filière non servie.
//
//  Cible : iOS 16, aucune dépendance externe.
//
import Foundation

// MARK: - Revue de prérequis

/// `ExercisePrerequisiteReview` : résultat d'une revue de prérequis, au niveau
/// de l'exercice ou ventilé par question.
struct ProgPrereqReview {
    enum Status: String { case pending, reviewed }
    enum Granularity: String { case exercise, questions }
    var status: Status
    var granularity: Granularity
    var prerequisites: [SubjChapterPrerequisite]
    var questionPrerequisites: [String: [SubjChapterPrerequisite]]?
    var questionReviewSource: SubjQuestionReviewSource?
    var reviewedAt: String?
    var reviewer: String?
}

// MARK: - Aiguillage par filière

/// `ProgPrereq` : point d'entrée unique de la revue de prérequis. La filière
/// est choisie par le scope de `bankId` (`scope:exercice:chapterId`).
enum ProgPrereq {

    /// Port de `Reviewable*Exercise` (MPSI, MP, lycée, ECG).
    struct Exercise {
        var key: String
        var title: String
        var statement: String
        var solution: String?
        var prerequisiteBankSignature: String?
        var difficulty: Int?
    }

    /// Entrée d'une revue : la banque (empreinte + chapitre) et l'exercice.
    struct ReviewInput {
        var bankId: String                  // ex. "mpsi-1:exercice:suites"
        var bankSignature: String
        var chapterId: String
        var exercise: Exercise
        var questionIds: [String] = []
        var questionPrompts: [String: String] = [:]
        var questionSolutions: [String: String] = [:]
    }

    /// Scope d'une banque : premier segment de `bankId`
    /// (`scope:exercice:chapterId`). Un `bankId` sans « : » est son propre scope.
    private static func bankScope(of bankId: String) -> String {
        guard let separator = bankId.firstIndex(of: ":") else { return bankId }
        return String(bankId[bankId.startIndex..<separator])
    }

    /// Aiguillage par `bankId` vers la revue portée de la filière ; `nil` si la
    /// filière n'est pas portée (jamais d'état inventé).
    static func review(_ input: ReviewInput) -> ProgPrereqReview? {
        switch bankScope(of: input.bankId) {
        case "mpsi-1":
            return ProgPrereqMpsi.review(input)
        case "mp-2":
            return ProgPrereqMp.review(input)
        case "ecg-appliquees-1", "ecg-appliquees-2":
            return ProgPrereqEcgApplied.review(input)
        case "ecg-approfondies-1", "ecg-approfondies-2":
            return ProgPrereqEcgAdvanced.review(input)
        case "seconde", "premiere", "terminale":
            return ProgPrereqLycee.review(input)
        default:
            return nil
        }
    }
}
