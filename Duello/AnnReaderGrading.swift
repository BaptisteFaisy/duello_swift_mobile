//
//  AnnReaderGrading.swift
//  Duello
//
//  Moteur de correction du lecteur d'annale (P0 18#2) : envoi d'une question au
//  correcteur, enregistrement du verdict, suivi du lot et persistance de la
//  tentative.
//
//  Fichier source Expo porté : `src/components/AnnaleViewer.tsx` (`submitAnswer`,
//  `runAutomaticGrade`, `recordQuestionReview`, `finishGrade`,
//  `finishBatchQuestion`, `finishSubmittedBatch`).
//
//  Écarts assumés (P0 18#2) :
//   - la capture des pages PDF (`pageImages`, `pdfPageHtml`) n'est pas portée :
//     la correction part sur l'énoncé et le corrigé **retranscrits** — même
//     réduction que les sujets non PDF de la source ;
//   - la file bornée (`MAX_CONCURRENT_QUESTION_CORRECTIONS`) n'est pas portée :
//     chaque question du lot part indépendamment, sans plafond de concurrence ;
//   - `finishSubmittedBatch` s'arrête au bilan : le calcul des XP, du rang et du
//     résultat de classement (`completeTrainingSubmission`, `recordExerciseResult`)
//     reste à raccorder hors lot.
//
//  Cible : iOS 16.
//
import SwiftUI

extension AnnReaderView {
    // MARK: Envoi d'une question

    /// `submitAnswer` : lance la correction d'une question donnée, affichée ou
    /// non. Renvoie `false` quand la correction n'a pas pu démarrer.
    @discardableResult
    func submitAnswer(question: AnnQuestion, answer: String) -> Bool {
        let trimmed = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        guard attempt?.reviews[question.id] == nil else { return false }
        if let attempt, isAnnaleQuestionSatisfied(attempt, entry.questions, question.id) { return false }
        guard !gradingQuestionIds.contains(question.id) else { return false }

        gradingQuestionIds.insert(question.id)
        gradingErrors[question.id] = nil

        // Corrigé en texte : la référence est immédiate, sans attendre une page.
        if let solution = entry.solution, !solution.isEmpty {
            Task { @MainActor in
                await runAutomaticGrade(question: question, answer: trimmed,
                                        correction: solution, statement: nil)
            }
            return true
        }
        // Sans corrigé officiel, le correcteur résout la question depuis l'énoncé.
        guard let statement = entry.statement, !statement.isEmpty else {
            gradingErrors[question.id] =
                "L’énoncé nécessaire à la correction automatique est indisponible."
            finishGrade(question.id)
            return false
        }
        mode = .statement
        Task { @MainActor in
            await runAutomaticGrade(question: question, answer: trimmed,
                                    correction: nil, statement: statement)
        }
        return true
    }

    /// `runAutomaticGrade` : note une question, enregistre le verdict ou l'erreur,
    /// puis clôt la correction de cette question.
    func runAutomaticGrade(question: AnnQuestion, answer: String,
                           correction: String?, statement: String?) async {
        do {
            let input = CollGradeAnswerInput(
                exercise: entry.title,
                question: "Question \(question.displayLabel)",
                answer: answer,
                program: profStudent.program,
                statement: statement,
                correction: correction
            )
            let grade = try await CollGradingRequest.gradeAnswer(input: input, token: session.token)
            await recordQuestionReview(questionId: question.id, grade: grade)
        } catch {
            gradingErrors[question.id] =
                "\(error.localizedDescription). Relance la correction automatique."
        }
        finishGrade(question.id)
    }

    /// `recordQuestionReview` : pose le verdict rendu sur la question et persiste
    /// la tentative.
    func recordQuestionReview(questionId: String, grade: CollMathGrade) async {
        guard let verdict = AnnVerdict(grade.verdict) else { return }
        var current = attempt ?? emptyAnnaleAttempt(itemId: entry.id)
        current.reviews[questionId] = AnnQuestionReview(
            verdict: verdict,
            feedback: grade.feedback,
            correction: grade.correction,
            source: .automatic,
            reviewedAt: annNowISOString()
        )
        current.updatedAt = annNowISOString()
        attempt = current
        await persistAttempt()
    }

    /// `finishGrade` : retire l'indicateur de la question, puis avance le lot.
    func finishGrade(_ questionId: String) {
        gradingQuestionIds.remove(questionId)
        finishBatchQuestion(questionId)
    }

    /// `finishBatchQuestion` : avance le lot ; la dernière réponse rentrée clôt
    /// la correction.
    func finishBatchQuestion(_ questionId: String) {
        guard batchPendingQuestionIds.contains(questionId) else { return }
        batchPendingQuestionIds.remove(questionId)
        if let progress = batchProgress {
            let done = progress.done + 1
            batchProgress = done >= progress.total
                ? nil
                : AnnBatchProgress(done: done, total: progress.total)
        }
        if batchPendingQuestionIds.isEmpty, correction != nil {
            Task { @MainActor in await finishSubmittedBatch() }
        }
    }

    /// `finishSubmittedBatch` : marque la copie corrigée et persiste la tentative.
    func finishSubmittedBatch() async {
        guard var current = correction else { return }
        current.completed = true
        correction = current
        await persistAttempt()
    }

    /// `saveAnnaleAttempt` : écrit la tentative du sujet sous le compte courant.
    func persistAttempt() async {
        guard let attempt else { return }
        await AnnAttemptStore.saveAnnaleAttempt(accountId: accountId, attempt: attempt)
    }
}
