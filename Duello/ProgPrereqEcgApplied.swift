//
//  ProgPrereqEcgApplied.swift
//  Duello
//
//  Phase 1a — port de src/data/ecgAppliedPrerequisites.ts (RN) : revue des
//  prérequis des exercices ECG mathématiques appliquées (1re et 2e année).
//
//  Surface publique :
//    - `review(_ input:)` = `appliedExercisePrerequisiteReview(year, chapterId,
//      exerciseKey, questionIds)` ;
//    - `annaleReview(annaleId:statement:prerequisites:questionIds:questionPrompts:)`
//      = `appliedAnnalePrerequisiteReview({…})` (fichier `+Annale.swift`) ;
//    - `isGenericAppliedExercise(_:)` ;
//    - les tables de données (`ProgPrereqEcgAppliedData.swift`, GÉNÉRÉ).
//
//  ⚠️ Couture documentée (aucune donnée fabriquée) :
//    - la source RN ne gère **aucune** empreinte de banque pour les appliquées :
//      la relecture est attestée par l'ensemble `REVIEWED_APPLIED_EXERCISES`
//      (clé `année:chapitre:exercice`), pas par un `appliedPrerequisiteSignature`
//      — qui n'existe pas (contrairement à `advancedPrerequisiteSignature`).
//      `ReviewInput.bankSignature` est donc **ignoré** ici, comme la source
//      ignore l'argument `bankSignature` qu'elle ne reçoit même pas.
//    - `year` n'est pas dans `ReviewInput` : il est déduit du scope de `bankId`
//      (`ecg-appliquees-1` → 1re année, `ecg-appliquees-2` → 2e), conformément
//      aux appels de `chapterItems.ts` ;
//    - `ReviewableAppliedExercise.id` → `ProgPrereq.Exercise.key` ;
//      les ids de questions viennent de `ReviewInput.questionIds`.
//
//  Découpage (24/09/2026, ratchet Hermes) :
//    - `ProgPrereqEcgApplied+Helpers.swift` : fabriques de prérequis et
//      constantes nommées de la source ;
//    - `ProgPrereqEcgApplied+Review.swift` : fabriques de résultat ;
//    - `ProgPrereqEcgApplied+Tables.swift` : surcharges et ensemble relu ;
//    - `ProgPrereqEcgApplied+Annale.swift` : revue d'annale et appariement ;
//    - `ProgPrereqEcgAppliedData.swift` : tables de données (GÉNÉRÉ).
//
//  Cible : iOS 16, aucune dépendance externe.
//
import Foundation

enum ProgPrereqEcgApplied {

    // MARK: - Revue d'exercice

    /// `appliedExercisePrerequisiteReview`.
    static func review(_ input: ProgPrereq.ReviewInput) -> ProgPrereqReview {
        let year = programYear(forBankId: input.bankId)
        let key = reviewKey(year: year, chapterId: input.chapterId, exerciseKey: input.exercise.key)
        let prerequisites = exercisePrerequisites(
            year: year, chapterId: input.chapterId, exerciseKey: input.exercise.key
        )
        guard reviewedAppliedExercises.contains(key) else {
            return pendingReview(prerequisites: prerequisites)
        }
        let explicit = questionPrerequisitesByExercise[key]
        let uniform = editoriallyUniformQuestionExercises.contains(key) && input.questionIds.count >= 2
            ? uniformQuestionPrerequisites(input.questionIds, prerequisites)
            : nil
        let questionPrerequisites = explicit ?? uniform
        let complete = questionPrerequisites
            ?? (input.questionIds.count >= 2
                ? uniformQuestionPrerequisites(input.questionIds, prerequisites)
                : nil)
        return reviewedReview(
            prerequisites: prerequisites,
            questionPrerequisites: complete,
            source: questionPrerequisites == nil ? .exerciseInheritance : .editorial
        )
    }

    // MARK: - Exigences d'un exercice

    /// Bloc `prerequisites` de la revue : surcharge exacte, sinon chapitre
    /// porteur + exigences inter-chapitres.
    static func exercisePrerequisites(
        year: SubjProgramYear, chapterId: String, exerciseKey: String
    ) -> [SubjChapterPrerequisite] {
        if let override = exercisePrerequisiteOverrides[
            reviewKey(year: year, chapterId: chapterId, exerciseKey: exerciseKey)
        ] {
            return override
        }
        return [carrierPrerequisite(year: year, chapterId: chapterId)]
            + (crossChapterRequirements[chapterId] ?? [])
    }

    /// `carrierPrerequisite` : notion principale de l'énoncé.
    static func carrierPrerequisite(year: SubjProgramYear, chapterId: String) -> SubjChapterPrerequisite {
        SubjChapterPrerequisite(
            year: year,
            chapterId: chapterId,
            requiredStatus: .inProgress,
            reason: "Notion principale vérifiée dans l'énoncé."
        )
    }

    /// Clé de revue `année:chapitre:exercice`.
    static func reviewKey(year: SubjProgramYear, chapterId: String, exerciseKey: String) -> String {
        "\(year.rawValue):\(chapterId):\(exerciseKey)"
    }

    /// Ventilation uniforme : chaque question hérite de l'exercice.
    static func uniformQuestionPrerequisites(
        _ questionIds: [String], _ prerequisites: [SubjChapterPrerequisite]
    ) -> [String: [SubjChapterPrerequisite]] {
        var byQuestion: [String: [SubjChapterPrerequisite]] = [:]
        for questionId in questionIds { byQuestion[questionId] = prerequisites }
        return byQuestion
    }

    // MARK: - Aiguillage d'année

    /// Année déduite du scope de `bankId` (`ecg-appliquees-1` → 1re année).
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

    // MARK: - Ressources génériques

    /// `isGenericAppliedExercise`.
    static func isGenericAppliedExercise(_ exerciseKey: String) -> Bool {
        exerciseKey == "ressource" || exerciseKey == "defi"
    }
}
