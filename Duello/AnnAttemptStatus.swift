//
//  AnnAttemptStatus.swift
//  Duello
//
//  Port de `src/utils/annaleAttempt.ts` — état d'une copie :
//  `annalePendingQuestionIds`, `hasAnsweredAllAnnaleQuestions`,
//  `isAnnaleAttemptComplete`, `areAllAnnaleAnswersCorrect`,
//  `isAnnaleAttemptFlawless`, `annaleAttemptMinutes`, `annaleAttemptOutcome`.
//
//  `annaleAttemptOutcome` retourne `ItemOutcome` (`ProgressStore.swift` :
//  fail/partial/success).
//
//  Cible : iOS 16, aucune API iOS 17.
//
import Foundation

/// Questions qu'une soumission de l'exercice entier envoie à la correction :
/// réponse écrite et pas encore corrigée (`annalePendingQuestionIds`).
func annalePendingQuestionIds(_ attempt: AnnAttempt, _ questions: [AnnQuestion]) -> [String] {
    questions.filter { question in
        !isAnnaleQuestionSatisfied(attempt, questions, question.id)
            && !(attempt.answers[question.id] ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && attempt.reviews[question.id] == nil
    }.map(\.id)
}

/// Une réponse réellement rédigée est présente pour chaque question
/// (`hasAnsweredAllAnnaleQuestions`).
func hasAnsweredAllAnnaleQuestions(_ attempt: AnnAttempt, _ questions: [AnnQuestion]) -> Bool {
    guard !questions.isEmpty else { return false }
    return annaleQuestionGroups(questions).allSatisfy { group in
        group.contains { question in
            !(attempt.answers[question.id] ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }
}

/// Vrai si chaque question logique est juste ou entièrement corrigée
/// (`isAnnaleAttemptComplete`).
func isAnnaleAttemptComplete(_ attempt: AnnAttempt, _ questions: [AnnQuestion]) -> Bool {
    guard !questions.isEmpty else { return false }
    return annaleQuestionGroups(questions).allSatisfy { group in
        isAnnaleGroupCorrect(attempt, group)
            || group.allSatisfy { attempt.reviews[$0.id] != nil }
    }
}

/// Toutes les questions ont été corrigées et chacune a reçu un verdict juste
/// (`areAllAnnaleAnswersCorrect`).
func areAllAnnaleAnswersCorrect(_ attempt: AnnAttempt, _ questions: [AnnQuestion]) -> Bool {
    guard !questions.isEmpty else { return false }
    return annaleQuestionGroups(questions).allSatisfy { group in
        group.contains { question in
            !(attempt.answers[question.id] ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && (attempt.reviews[question.id]?.verdict.isValidated ?? false)
        }
    }
}

/// Aucune réponse fausse n'a été soumise sur ce sujet
/// (`isAnnaleAttemptFlawless`) : une réponse partiellement juste compte comme
/// une faute.
func isAnnaleAttemptFlawless(_ attempt: AnnAttempt) -> Bool {
    (attempt.wrongAnswers ?? 0) == 0
}

/// Minutes de travail mesurées, `nil` si rien n'a été mesuré
/// (`annaleAttemptMinutes`).
func annaleAttemptMinutes(_ attempt: AnnAttempt) -> Double? {
    let seconds = attempt.spentSeconds ?? 0
    return seconds > 0 ? Double(seconds) / 60 : nil
}

/// Résultat global de la copie (`annaleAttemptOutcome`).
func annaleAttemptOutcome(_ attempt: AnnAttempt, _ questions: [AnnQuestion]) -> ItemOutcome {
    let correct = annaleCorrectCount(attempt, questions)
    let count = annaleQuestionCount(questions)
    if correct == count && count > 0 { return .success }
    return correct > 0 ? .partial : .fail
}
