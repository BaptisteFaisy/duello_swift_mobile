//
//  ProgPrereqEcgApplied+Annale+Matching.swift
//  Duello
//
//  Phase 1a — appariement et sélection des prérequis d'annale ECG appliquées :
//  port de `matchingAnnalePrerequisites`, `annaleSectionPrerequisites`,
//  `selectAnnalePrerequisites` et de leurs auxiliaires (motifs
//  `ANNALE_TOPIC_PATTERNS`, découpage par section).
//
//  Cible : iOS 16, aucune dépendance externe.
//
import Foundation

extension ProgPrereqEcgApplied {

    /// `selectAnnalePrerequisites` : priorités de la source (reprise de
    /// section, énoncé de question, section précédente, base de section,
    /// énoncé suivant, socle).
    static func selectQuestionPrerequisites(
        reset: [SubjChapterPrerequisite],
        prompt: [SubjChapterPrerequisite],
        previous: [SubjChapterPrerequisite]?,
        bySection: [SubjChapterPrerequisite]?,
        nextPrompt: [SubjChapterPrerequisite],
        fallback: [SubjChapterPrerequisite]
    ) -> [SubjChapterPrerequisite] {
        if !reset.isEmpty { return reset }
        if !prompt.isEmpty { return prompt }
        if let previous { return previous }
        if let bySection { return bySection }
        if !nextPrompt.isEmpty { return nextPrompt }
        return fallback
    }

    /// Premier énoncé de question non vide, après `index`, dans la même section.
    static func followingSectionPrompts(
        _ questionIds: [String],
        from index: Int,
        sectionId: String,
        prompts: [String: [SubjChapterPrerequisite]]
    ) -> [SubjChapterPrerequisite] {
        guard index + 1 < questionIds.count else { return [] }
        for candidateId in questionIds[(index + 1)...] where annaleSectionId(of: candidateId) == sectionId {
            let candidate = prompts[candidateId] ?? []
            if !candidate.isEmpty { return candidate }
        }
        return []
    }

    /// `annaleSectionPrerequisites`.
    static func annaleSectionPrerequisites(
        _ section: String, _ prerequisites: [SubjChapterPrerequisite]
    ) -> [SubjChapterPrerequisite] {
        let selected = matchingAnnalePrerequisites(section, prerequisites)
        return selected.isEmpty ? prerequisites : selected
    }

    /// `matchingAnnalePrerequisites` : prérequis dont le chapitre et l'énoncé
    /// répondent au même motif.
    static func matchingAnnalePrerequisites(
        _ text: String, _ prerequisites: [SubjChapterPrerequisite]
    ) -> [SubjChapterPrerequisite] {
        prerequisites.filter { required in
            annaleTopicPatterns.contains { topic in
                matches(topic.chapter, required.chapterId, caseInsensitive: false)
                    && matches(topic.statement, text, caseInsensitive: true)
            }
        }
    }

    /// `selectAnnalePrerequisites`.
    static func selectAnnalePrerequisites(
        _ chapterIds: [String]?, _ prerequisites: [SubjChapterPrerequisite]
    ) -> [SubjChapterPrerequisite] {
        guard let chapterIds else { return [] }
        let programChapters: [(year: SubjProgramYear, chapter: ProgEcgChapter)] =
            (ProgPrereqEcgProgram.appliquees[.second] ?? []).map { (.second, $0) }
                + (ProgPrereqEcgProgram.appliquees[.first] ?? []).map { (.first, $0) }
        var selected: [SubjChapterPrerequisite] = []
        for chapterId in chapterIds {
            if let declared = prerequisites.first(where: {
                $0.chapterId == chapterId || $0.chapterId.hasSuffix("-\(chapterId)")
            }) {
                selected.append(declared)
                continue
            }
            if let match = programChapters.first(where: {
                $0.chapter.id == chapterId || $0.chapter.id.hasSuffix("-\(chapterId)")
            }) {
                selected.append(SubjChapterPrerequisite(
                    year: match.year,
                    chapterId: match.chapter.id,
                    requiredStatus: .completed,
                    reason: "Thème identifié lors de la revue éditoriale de l’annale."
                ))
            }
        }
        return dedupePrerequisites(selected)
    }

    /// Déduplication `Map` : dernière valeur, première position.
    static func dedupePrerequisites(
        _ prerequisites: [SubjChapterPrerequisite]
    ) -> [SubjChapterPrerequisite] {
        var order: [String] = []
        var byKey: [String: SubjChapterPrerequisite] = [:]
        for prerequisite in prerequisites {
            let key = "\(prerequisite.year.rawValue):\(prerequisite.chapterId)"
            if byKey[key] == nil { order.append(key) }
            byKey[key] = prerequisite
        }
        return order.compactMap { byKey[$0] }
    }

    /// `/^exercice-[0-9]{1,2}/` sur un id de question, sinon `monobloc`.
    static func annaleSectionId(of questionId: String) -> String {
        if let range = questionId.range(of: "^exercice-[0-9]{1,2}", options: .regularExpression) {
            return String(questionId[range])
        }
        return "monobloc"
    }

    /// Chapitres d'une section dans une table éditoriale ordonnée.
    static func sectionChapters(
        _ table: [(section: String, chapters: [String])], _ sectionId: String
    ) -> [String]? {
        table.first { $0.section == sectionId }?.chapters
    }
}
