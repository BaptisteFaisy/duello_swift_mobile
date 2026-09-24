//
//  ProgPrereqEcgAdvanced+Review.swift
//  Duello
//
//  Phase 1a — section extraite de `ProgPrereqEcgAdvanced.swift` : fabriques de
//  résultat de revue (`ExercisePrerequisiteReview`), partagées par la revue
//  d'exercice (`review`) et la revue d'annale (`annaleReview`).
//
//  Cible : iOS 16, aucune dépendance externe.
//
import Foundation

extension ProgPrereqEcgAdvanced {

    /// Revue en attente : l'empreinte de la banque n'a pas été relue.
    static func pendingReview(prerequisites: [SubjChapterPrerequisite]) -> ProgPrereqReview {
        ProgPrereqReview(
            status: .pending,
            granularity: .exercise,
            prerequisites: prerequisites,
            questionPrerequisites: nil,
            questionReviewSource: nil,
            reviewedAt: nil,
            reviewer: nil
        )
    }

    /// Revue acquittée : `reviewedAt`/`reviewer` figés, origine de la
    /// ventilation calculée depuis la source fournie (`semantic` pour un
    /// exercice de chapitre, `editorial` pour une annale).
    static func reviewedReview(
        prerequisites: [SubjChapterPrerequisite],
        questionPrerequisites: [String: [SubjChapterPrerequisite]]?,
        source: SubjQuestionReviewSource
    ) -> ProgPrereqReview {
        ProgPrereqReview(
            status: .reviewed,
            granularity: questionPrerequisites != nil ? .questions : .exercise,
            prerequisites: prerequisites,
            questionPrerequisites: questionPrerequisites,
            questionReviewSource: questionPrerequisites.map {
                SubjChapterPrerequisites.questionReviewSourceFor($0, editorialSource: source)
            },
            reviewedAt: "2026-07-29",
            reviewer: "Duello"
        )
    }
}
