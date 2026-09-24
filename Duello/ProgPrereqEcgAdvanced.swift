//
//  ProgPrereqEcgAdvanced.swift
//  Duello
//
//  Phase 1a — port de src/data/ecgAdvancedPrerequisites.ts (RN) : revue des
//  prérequis des exercices ECG mathématiques approfondies.
//
//  ⚠️ Ce module a ses PROPRES helpers, distincts du socle MPSI/MP
//  (`ProgPrereqMpsiMpGraph`) malgré des noms proches :
//    - `advancedChapterIndex()` : index ordonné du programme approfondies
//      (positions + amont transitif), bâti sur `ProgPrereqEcgProgram` ;
//    - `semanticQuestionPrerequisites(year:chapterId:questionText:)` **local**,
//      qui autorise un chapitre POSTÉRIEUR au porteur (contrairement au socle) ;
//    - `chapterTopicPatterns`, `carrierPrerequisite`, `completedPrerequisite`,
//      `uniquePrerequisites`, `revisionAnalysisPrerequisites`,
//      `annaleTopicPatterns`, `annaleEditorialChapters`,
//      `matchingAnnalePrerequisites`, `annaleCorePrerequisites`,
//      `normalizedAnnalePrerequisites`.
//  Ne pas les confondre avec ceux du socle.
//
//  Couture documentée (aucune donnée fabriquée) :
//    - `AdvancedReviewItem.id` → `ProgPrereq.Exercise.key` ;
//    - `AdvancedReviewItem.questions?.map(q => q.id)` → `ReviewInput.questionIds`
//      (le type `Exercise` ne porte pas `questions`) ;
//    - l'année (`ProgramYear`) n'est pas dans `ReviewInput` : elle est déduite du
//      scope de `bankId` (`ecg-approfondies-1` → 1, `ecg-approfondies-2` → 2).
//
//  Découpage (24/09/2026, ratchet Hermes) :
//    - `ProgPrereqEcgAdvanced+Review.swift` : fabriques de résultat ;
//    - `ProgPrereqEcgAdvanced+Semantic.swift` : index, ventilation sémantique,
//      analyse de révision et `chapterTopicPatterns` ;
//    - `ProgPrereqEcgAdvanced+Annale.swift` : revue d'annale et ses tables ;
//    - `ProgPrereqEcgAdvanced+Signatures.swift` : empreinte et banques relues.
//
//  Cache : la source mémoïse `advancedChapterIndex` ; le port recalcule (aucun
//  cache partagé), comme le socle.
//
//  Cible : iOS 16, aucune dépendance externe.
//
import Foundation

// MARK: - Position et index de chapitre

/// `AdvancedChapterPosition` : position d'un chapitre et chapitres déjà exigés
/// transitivement par le programme.
struct AdvancedChapterPosition {
    var year: SubjProgramYear
    var id: String
    var name: String
    var index: Int
    var upstream: Set<String>
}

/// `advancedChapterPositions` : index ordonné (ordre d'insertion du programme).
struct AdvancedChapterIndex {
    var keys: [String]
    var positions: [String: AdvancedChapterPosition]
}

// MARK: - Revue

enum ProgPrereqEcgAdvanced {

    /// `advancedExercisePrerequisiteReview`.
    static func review(_ input: ProgPrereq.ReviewInput) -> ProgPrereqReview {
        let year = programYear(forBankId: input.bankId)
        let prerequisites = exercisePrerequisites(year: year, chapterId: input.chapterId, item: input.exercise)
        guard reviewedAdvancedBankSignatures[input.bankId] == input.bankSignature else {
            return pendingReview(prerequisites: prerequisites)
        }
        let questionPrerequisites = input.questionIds.count >= 2
            ? ventilation(year: year, chapterId: input.chapterId, input: input, prerequisites: prerequisites)
            : nil
        return reviewedReview(
            prerequisites: prerequisites,
            questionPrerequisites: questionPrerequisites,
            source: .semantic
        )
    }

    /// Ventilation par question d'un exercice relu (extrait de `review`).
    static func ventilation(
        year: SubjProgramYear,
        chapterId: String,
        input: ProgPrereq.ReviewInput,
        prerequisites: [SubjChapterPrerequisite]
    ) -> [String: [SubjChapterPrerequisite]] {
        var previous: [SubjChapterPrerequisite]?
        var byQuestion: [String: [SubjChapterPrerequisite]] = [:]
        for questionId in input.questionIds {
            let prompt = input.questionPrompts[questionId] ?? ""
            let direct: [SubjChapterPrerequisite]
            if year == .second && chapterId == "analyse-concours" {
                direct = revisionAnalysisPrerequisites(itemId: input.exercise.key, text: prompt)
            } else {
                direct = uniquePrerequisites(
                    prerequisites + semanticQuestionPrerequisites(
                        year: year, chapterId: chapterId, questionText: prompt
                    )
                )
            }
            let selected = direct.isEmpty ? (previous ?? prerequisites) : direct
            previous = selected
            byQuestion[questionId] = selected
        }
        return byQuestion
    }

    // MARK: - Fabriques de prérequis

    /// `carrierPrerequisite`.
    static func carrierPrerequisite(year: SubjProgramYear, chapterId: String) -> SubjChapterPrerequisite {
        SubjChapterPrerequisite(
            year: year,
            chapterId: chapterId,
            requiredStatus: .inProgress,
            reason: "Notion principale vérifiée dans l'énoncé."
        )
    }

    /// `completedPrerequisite`.
    static func completedPrerequisite(year: SubjProgramYear, chapterId: String, reason: String) -> SubjChapterPrerequisite {
        SubjChapterPrerequisite(year: year, chapterId: chapterId, requiredStatus: .completed, reason: reason)
    }

    /// `uniquePrerequisites` : une exigence par chapitre, la plus forte gagnant,
    /// dans l'ordre de première insertion (`Map` de la source).
    static func uniquePrerequisites(_ prerequisites: [SubjChapterPrerequisite]) -> [SubjChapterPrerequisite] {
        var order: [String] = []
        var byChapter: [String: SubjChapterPrerequisite] = [:]
        for prerequisite in prerequisites {
            let key = "\(prerequisite.year.rawValue):\(prerequisite.chapterId)"
            guard let previous = byChapter[key] else {
                order.append(key)
                byChapter[key] = prerequisite
                continue
            }
            if previous.requiredStatus == .inProgress, prerequisite.requiredStatus == .completed {
                byChapter[key] = prerequisite
            }
        }
        return order.compactMap { byChapter[$0] }
    }

    // MARK: - Exigences d'un exercice

    /// `advancedExercisePrerequisites`.
    static func exercisePrerequisites(year: SubjProgramYear, chapterId: String, item: ProgPrereq.Exercise) -> [SubjChapterPrerequisite] {
        if year == .second && chapterId == "analyse-concours" {
            return revisionAnalysisPrerequisites(itemId: item.key, text: "\(item.title)\n\(item.statement)")
        }
        return [carrierPrerequisite(year: year, chapterId: chapterId)]
    }

    // MARK: - Aiguillage d'année

    /// Année déduite du scope de `bankId` (`ecg-approfondies-1` → 1re année).
    static func programYear(forBankId bankId: String) -> SubjProgramYear {
        let scope = bankId.split(separator: ":").first.map(String.init) ?? bankId
        return scope.hasSuffix("2") ? .second : .first
    }

    // MARK: - Motifs

    /// Test d'un motif regex. `caseInsensitive` par défaut (drapeau `/…/i`) ;
    /// les motifs d'identifiant de chapitre de la source sont, eux, sensibles à
    /// la casse.
    static func matches(_ pattern: String, _ text: String, caseInsensitive: Bool = true) -> Bool {
        var options: String.CompareOptions = [.regularExpression]
        if caseInsensitive { options.insert(.caseInsensitive) }
        return text.range(of: pattern, options: options) != nil
    }
}
