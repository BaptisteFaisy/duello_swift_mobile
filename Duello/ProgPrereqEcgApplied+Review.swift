//
//  ProgPrereqEcgApplied+Review.swift
//  Duello
//
//  Phase 1a — section extraite de `ProgPrereqEcgApplied.swift` : fabriques de
//  résultat de revue (`ExercisePrerequisiteReview`), partagées par la revue
//  d'exercice (`review`) et la revue d'annale (`annaleReview`).
//
//  Cible : iOS 16, aucune dépendance externe.
//
import Foundation

extension ProgPrereqEcgApplied {

    /// Revue en attente : l'exercice (ou l'annale) n'a pas été relu.
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

    /// Revue acquittée. `source` fixe l'origine par défaut de la ventilation ;
    /// `questionReviewSourceFor` la rabat sur `exerciseInheritance` si la
    /// ventilation est uniforme. Les dates diffèrent entre exercice
    /// (`2026-07-29`) et annale (`2026-08-12`).
    static func reviewedReview(
        prerequisites: [SubjChapterPrerequisite],
        questionPrerequisites: [String: [SubjChapterPrerequisite]]?,
        source: SubjQuestionReviewSource,
        reviewedAt: String = "2026-07-29",
        reviewer: String = "Duello"
    ) -> ProgPrereqReview {
        ProgPrereqReview(
            status: .reviewed,
            granularity: questionPrerequisites != nil ? .questions : .exercise,
            prerequisites: prerequisites,
            questionPrerequisites: questionPrerequisites,
            questionReviewSource: questionPrerequisites.map {
                SubjChapterPrerequisites.questionReviewSourceFor($0, editorialSource: source)
            },
            reviewedAt: reviewedAt,
            reviewer: reviewer
        )
    }
}
