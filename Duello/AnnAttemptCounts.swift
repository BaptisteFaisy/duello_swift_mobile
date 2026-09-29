//
//  AnnAttemptCounts.swift
//  Duello
//
//  Port de `src/utils/annaleAttempt.ts` — décomptes purs :
//  `annaleQuestionGroups`, `isAnnaleGroupCorrect`, `annaleQuestionCount`,
//  `isAnnaleQuestionSatisfied`, `annaleCorrectCount`, `annaleAnsweredCount`,
//  `annaleAttemptFraction`.
//
//  Les questions manipulées sont `AnnQuestion` (`AnnAnnalesModels.swift`),
//  aligné sur `AnnaleQuestion` de `chapterItems.ts` (`alternativeGroupId`).
//
//  Cible : iOS 16, aucune API iOS 17.
//
import Foundation

/// Questions logiques regroupées : les variantes A/B/C d'un même choix ne
/// comptent qu'une fois (`annaleQuestionGroups`).
func annaleQuestionGroups(_ questions: [AnnQuestion]) -> [[AnnQuestion]] {
    var order: [String] = []
    var groups: [String: [AnnQuestion]] = [:]
    for question in questions {
        let groupId = question.alternativeGroupId
            .map { "alternative-\($0)" } ?? "single-\(question.id)"
        if groups[groupId] == nil { order.append(groupId) }
        groups[groupId, default: []].append(question)
    }
    return order.map { groups[$0] ?? [] }
}

/// Vrai si l'un des choix du groupe porte un verdict validé
/// (`isAnnaleGroupCorrect`).
func isAnnaleGroupCorrect(_ attempt: AnnAttempt?, _ group: [AnnQuestion]) -> Bool {
    group.contains { question in
        attempt?.reviews[question.id]?.verdict.isValidated ?? false
    }
}

/// Nombre de questions logiques (`annaleQuestionCount`).
func annaleQuestionCount(_ questions: [AnnQuestion]) -> Int {
    annaleQuestionGroups(questions).count
}

/// Vrai si l'un des choix rattachés à cette question est déjà juste
/// (`isAnnaleQuestionSatisfied`).
func isAnnaleQuestionSatisfied(
    _ attempt: AnnAttempt?,
    _ questions: [AnnQuestion],
    _ questionId: String
) -> Bool {
    guard let question = questions.first(where: { $0.id == questionId }) else { return false }
    guard let group = annaleQuestionGroups(questions)
        .first(where: { $0.contains { $0.id == question.id } })
    else { return false }
    return isAnnaleGroupCorrect(attempt, group)
}

/// Nombre de questions logiques justes (`annaleCorrectCount`).
func annaleCorrectCount(_ attempt: AnnAttempt?, _ questions: [AnnQuestion]) -> Int {
    annaleQuestionGroups(questions).filter { isAnnaleGroupCorrect(attempt, $0) }.count
}

/// Questions logiques dont le champ contient une réponse non vide
/// (`annaleAnsweredCount`).
func annaleAnsweredCount(_ attempt: AnnAttempt?, _ questions: [AnnQuestion]) -> Int {
    annaleQuestionGroups(questions).filter { group in
        group.contains { question in
            !(attempt?.answers[question.id] ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }.count
}

/// Fraction de questions justes (`annaleAttemptFraction`).
func annaleAttemptFraction(_ attempt: AnnAttempt?, _ questions: [AnnQuestion]) -> Double {
    let count = annaleQuestionCount(questions)
    guard count > 0 else { return 0 }
    return Double(annaleCorrectCount(attempt, questions)) / Double(count)
}
