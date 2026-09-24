//
//  SubjChapterPrerequisites+Granularity.swift
//  Duello
//
//  Port de src/utils/questionPrerequisiteGranularity.ts (RN) — empreinte
//  canonique d'une ventilation par question, uniformité et origine honnête.
//
//  Découpage (24/09/2026) : section extraite de `SubjChapterPrerequisites.swift`
//  (porté du même fichier source).
//
//  Cible : iOS 16, aucune dépendance externe.
//
import Foundation

extension SubjChapterPrerequisites {

    /// `chapterPrerequisiteSignature` : empreinte canonique d'une liste
    /// d'exigences, indépendante de l'ordre et des doublons.
    static func chapterPrerequisiteSignature(
        _ prerequisites: [SubjChapterPrerequisite]?
    ) -> String {
        let tokens = Set((prerequisites ?? []).map { prerequisite in
            let status = prerequisite.requiredStatus ?? .completed
            return "\(prerequisite.year.rawValue):\(prerequisite.chapterId)@\(status.rawValue)"
        })
        return tokens.sorted().joined(separator: "|")
    }

    /// `questionRequirementsAreUniform` : vrai lorsque toutes les questions
    /// partagent la même exigence, donc lorsque le badge partiel est hors
    /// d'atteinte. Une ventilation portant sur moins de deux questions est
    /// uniforme par construction.
    static func questionRequirementsAreUniform(
        _ questionPrerequisites: [String: [SubjChapterPrerequisite]]?
    ) -> Bool {
        guard let questionPrerequisites else { return true }
        let signatures = Set(questionPrerequisites.values.map { chapterPrerequisiteSignature($0) })
        return signatures.count <= 1
    }

    /// `questionReviewSourceFor` : origine honnête d'une ventilation. Une
    /// ventilation uniforme est un héritage de l'exercice, même lorsqu'elle a
    /// été produite par une relecture : elle n'apporte aucune granularité.
    static func questionReviewSourceFor(
        _ questionPrerequisites: [String: [SubjChapterPrerequisite]]?,
        editorialSource: SubjQuestionReviewSource = .editorial
    ) -> SubjQuestionReviewSource {
        questionRequirementsAreUniform(questionPrerequisites) ? .exerciseInheritance : editorialSource
    }
}
