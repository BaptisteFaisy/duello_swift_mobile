//
//  ChalSeries.swift
//  Duello
//
//  Lot « Extras de défi » — série de défis : réunit les exercices
//  irréversiblement validés en une seule copie à noter.
//
//  Fichier source Expo porté (identifiants et libellés repris mot pour mot) :
//    - src/utils/challengeSeries.ts
//      (`seriesQuestionId`, `buildChallengeSeriesExercise`,
//       `buildChallengeSeriesAnswers`)
//
//  Le serveur conserve ainsi un résultat unique et une seule variation d'Elo
//  pour le défi, quelle que soit la quantité d'exercices traités. Chaque énoncé
//  est préfixé « EXERCICE n » ; chaque question reçoit un identifiant non
//  ambigu `exo-<n>--<questionId>` pour éviter les collisions entre exercices.
//
//  Note de périmètre : le brief décrit `ChalSeries` comme « séries de défis :
//  seuils, récompenses » ; la source `challengeSeries.ts` ne contient aucune
//  table de seuils ni de récompenses — elle assemble la copie de série. Aucune
//  grille de seuils/récompenses n'existe côté Expo pour ce module.
//
//  Cible : iOS 16, aucune API iOS 17.
//
import Foundation

/// Un exercice validé et ses réponses (`CompletedChallengeExercise`).
struct ChalCompletedExercise {
    var exercise: DuelExercise
    var answers: [String: String]
}

/// Série de défis (`challengeSeries.ts`).
enum ChalSeries {
    /// Identifiant non ambigu d'une question dans la copie globale du défi.
    static func questionId(exerciseIndex: Int, questionId: String) -> String {
        "exo-\(exerciseIndex + 1)--\(questionId)"
    }

    /// Réunit les exercices validés en une seule copie à noter
    /// (`buildChallengeSeriesExercise`).
    static func buildExercise(subject: String, entries: [ChalCompletedExercise]) -> DuelExercise {
        let id = entries.map { $0.exercise.id }.joined(separator: "::")
        let context = entries.enumerated()
            .map { index, entry in "EXERCICE \(index + 1)\n\(duelExercisePrompt(entry.exercise))" }
            .joined(separator: "\n\n")
        let questions = entries.enumerated().flatMap { exerciseIndex, entry in
            entry.exercise.questions.enumerated().map { questionIndex, question in
                DuelExercise.Question(
                    id: questionId(exerciseIndex: exerciseIndex, questionId: question.id),
                    // Le contexte porte déjà l'énoncé de chaque exercice : la
                    // question ne garde que son repère, comme la source.
                    prompt: nil,
                    label: "\(exerciseIndex + 1).\(question.label ?? String(questionIndex + 1))"
                )
            }
        }
        let solutionParts = entries.enumerated().compactMap { index, entry -> String? in
            let trimmed = entry.exercise.solution?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return trimmed.isEmpty ? nil : "EXERCICE \(index + 1)\n\(trimmed)"
        }
        return DuelExercise(
            id: id,
            subject: subject,
            context: context,
            questions: questions,
            solution: solutionParts.isEmpty ? nil : solutionParts.joined(separator: "\n\n")
        )
    }

    /// Réindexe les réponses de chaque exercice pour éviter les identifiants
    /// égaux (`buildChallengeSeriesAnswers`).
    static func buildAnswers(entries: [ChalCompletedExercise]) -> [String: String] {
        var result: [String: String] = [:]
        for (exerciseIndex, entry) in entries.enumerated() {
            for question in entry.exercise.questions {
                let answer = (entry.answers[question.id] ?? "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                guard !answer.isEmpty else { continue }
                result[questionId(exerciseIndex: exerciseIndex, questionId: question.id)] = answer
            }
        }
        return result
    }
}
