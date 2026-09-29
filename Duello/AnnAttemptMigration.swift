//
//  AnnAttemptMigration.swift
//  Duello
//
//  Port de `src/utils/annaleAttempt.ts` — `migrateAnnaleAttemptQuestionIds` :
//  récupère les anciennes réponses lorsque des questions homonymes ont reçu un
//  identifiant préfixé par leur exercice, puis lorsque la numérotation des
//  parties est repassée de la série continue à la reprise à 1 par partie.
//
//  Une ancienne clé ne peut contenir qu'une seule réponse : elle est transférée
//  vers sa première occurrence, jamais dupliquée sur toutes les questions qui
//  portaient autrefois le même identifiant.
//
//  Cible : iOS 16, aucune API iOS 17.
//
import Foundation

func migrateAnnaleAttemptQuestionIds(
    attempt: AnnAttempt,
    questions: [AnnAttemptQuestionRef]
) -> AnnAttempt {
    var answers = attempt.answers
    var reviews = attempt.reviews
    var submissionCounts = attempt.submissionCounts ?? [:]
    var consumedLegacyIds = Set<String>()
    var changed = false

    let claim: (String, String) -> Void = { questionId, previousKey in
        if consumedLegacyIds.contains(previousKey) { return }
        let previousAnswer = attempt.answers[previousKey]
        let previousReview = attempt.reviews[previousKey]
        let previousSubmissionCount = attempt.submissionCounts?[previousKey]
        if previousAnswer == nil && previousReview == nil && previousSubmissionCount == nil {
            return
        }
        consumedLegacyIds.insert(previousKey)
        if answers[questionId] == nil, let previousAnswer {
            answers[questionId] = previousAnswer
            changed = true
        }
        if reviews[questionId] == nil, let previousReview {
            reviews[questionId] = previousReview
            changed = true
        }
        if submissionCounts[questionId] == nil, let previousSubmissionCount {
            submissionCounts[questionId] = previousSubmissionCount
            changed = true
        }
    }

    for question in questions {
        // La convention continue précédente d'abord (brouillons récents),
        // l'identifiant sans préfixe ensuite (réponses anciennes).
        if let previousId = question.previousId, previousId != question.id {
            claim(question.id, previousId)
        }
        if let legacyId = question.legacyId, legacyId != question.id {
            claim(question.id, legacyId)
        }
    }

    guard changed else { return attempt }
    var migrated = attempt
    migrated.answers = answers
    migrated.reviews = reviews
    migrated.submissionCounts = submissionCounts
    return migrated
}
