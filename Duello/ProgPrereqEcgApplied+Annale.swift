//
//  ProgPrereqEcgApplied+Annale.swift
//  Duello
//
//  Phase 1a — revue des prérequis des annales ECG appliquées : port de
//  `appliedAnnalePrerequisiteReview` et de sa découpe en sections.
//
//  ⚠️ Couture documentée : la source prend un objet
//  `{ annaleId, statement, prerequisites, questionIds, questionPrompts }` ;
//  le port expose la même signature nommée. `ANNALE_EDITORIAL_SECTION_BASES` et
//  `ANNALE_EDITORIAL_RESETS` sont des couples ORDONNÉS (l'ordre d'insertion des
//  clés JS influe sur `selectAnnalePrerequisites`).
//
//  L'appariement par motifs vit dans `+Annale+Matching.swift`.
//
//  Cible : iOS 16, aucune dépendance externe.
//
import Foundation

extension ProgPrereqEcgApplied {

    /// `appliedAnnalePrerequisiteReview`.
    static func annaleReview(
        annaleId: String,
        statement: String,
        prerequisites: [SubjChapterPrerequisite],
        questionIds: [String],
        questionPrompts: [String: String] = [:]
    ) -> ProgPrereqReview {
        guard editoriallyReviewedAppliedAnnales.contains(annaleId) else {
            return pendingReview(prerequisites: prerequisites)
        }
        let ventilation = questionIds.count >= 2
            ? annaleQuestionPrerequisites(
                annaleId: annaleId,
                statement: statement,
                prerequisites: prerequisites,
                questionIds: questionIds,
                questionPrompts: questionPrompts
            )
            : nil
        return reviewedReview(
            prerequisites: prerequisites,
            questionPrerequisites: ventilation,
            source: .editorial,
            reviewedAt: "2026-08-12"
        )
    }

    /// Ventilation par question d'une annale relue.
    static func annaleQuestionPrerequisites(
        annaleId: String,
        statement: String,
        prerequisites: [SubjChapterPrerequisite],
        questionIds: [String],
        questionPrompts: [String: String]
    ) -> [String: [SubjChapterPrerequisite]] {
        let bases = annaleEditorialSectionBases[annaleId] ?? []
        let resets = annaleEditorialResets[annaleId] ?? []
        let editorial = selectAnnalePrerequisites(
            bases.flatMap { $0.chapters } + resets.flatMap { $0.chapters }, prerequisites
        )
        let candidates = dedupePrerequisites(prerequisites + editorial)
        var bySection: [String: [SubjChapterPrerequisite]] = [:]
        for section in annaleExerciseSections(statement) {
            let based = selectAnnalePrerequisites(sectionChapters(bases, section.id), prerequisites)
            bySection[section.id] = based.isEmpty
                ? annaleSectionPrerequisites(section.text, candidates)
                : based
        }
        var prompts: [String: [SubjChapterPrerequisite]] = [:]
        for questionId in questionIds {
            prompts[questionId] = matchingAnnalePrerequisites(
                questionPrompts[questionId] ?? "", candidates
            )
        }
        var previous: [String: [SubjChapterPrerequisite]] = [:]
        var result: [String: [SubjChapterPrerequisite]] = [:]
        for (index, questionId) in questionIds.enumerated() {
            let sectionId = annaleSectionId(of: questionId)
            let reset = selectAnnalePrerequisites(sectionChapters(resets, questionId), prerequisites)
            let next = previous[sectionId] == nil
                ? followingSectionPrompts(questionIds, from: index, sectionId: sectionId, prompts: prompts)
                : []
            let selected = selectQuestionPrerequisites(
                reset: reset,
                prompt: prompts[questionId] ?? [],
                previous: previous[sectionId],
                bySection: bySection[sectionId],
                nextPrompt: next,
                fallback: prerequisites
            )
            result[questionId] = selected
            previous[sectionId] = selected
        }
        return result
    }

    /// `annaleExerciseSections` : découpe l'énoncé en blocs « exercice N ».
    static func annaleExerciseSections(_ statement: String) -> [(id: String, text: String)] {
        let pattern = "^exercice\\s+([0-9]{1,2})(?:[^\\n]*)"
        guard let regex = try? NSRegularExpression(
            pattern: pattern, options: [.caseInsensitive, .anchorsMatchLines]
        ) else { return [] }
        let text = statement as NSString
        let matches = regex.matches(in: statement, range: NSRange(location: 0, length: text.length))
        return matches.enumerated().map { index, match in
            let start = match.range.location
            let end = index + 1 < matches.count ? matches[index + 1].range.location : text.length
            let number = text.substring(with: match.range(at: 1))
            return ("exercice-\(number)", text.substring(with: NSRange(location: start, length: end - start)))
        }
    }
}
