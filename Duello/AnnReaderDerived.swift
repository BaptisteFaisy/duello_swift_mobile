//
//  AnnReaderDerived.swift
//  Duello
//
//  État dérivé du lecteur d'annale (P0 18#2) : la question ouverte, la copie,
//  l'avancement de la correction et le bilan, calculés depuis la tentative
//  persistée et les repères de soumission. Repris de la section dérivée
//  d'`AnnaleViewer.tsx` (:2141-2430).
//
//  Cible : iOS 16.
//
import SwiftUI

extension AnnReaderView {
    // MARK: Question ouverte

    /// `activeQuestion` : la question ouverte, ou la première du sujet.
    var activeQuestion: AnnQuestion? {
        entry.questions.first { $0.id == activeQuestionId } ?? entry.questions.first
    }

    /// Libellé de la question ouverte (`questionDisplayLabel`).
    var currentQuestionLabel: String { activeQuestion?.displayLabel ?? "" }

    /// Réponse affichée (`currentAnswer`) : le brouillon de la question ouverte.
    var currentAnswer: String { draft }

    /// Verdict déjà rendu sur la question ouverte (`currentReview`).
    var currentReview: AnnQuestionReview? {
        guard let activeQuestion else { return nil }
        return attempt?.reviews[activeQuestion.id]
    }

    /// Correction de la question ouverte en cours (`activeQuestionGrading`).
    var activeQuestionGrading: Bool {
        guard let activeQuestion else { return false }
        return gradingQuestionIds.contains(activeQuestion.id)
    }

    /// Erreur de correction de la question ouverte (`currentGradingError`).
    var currentGradingError: String? {
        guard let activeQuestion else { return nil }
        return gradingErrors[activeQuestion.id]
    }

    /// Programme en échec de la question ouverte (`currentPythonBlocked`).
    var currentPythonBlocked: AnnPythonBlocked? {
        guard let pythonBlocked, pythonBlocked.questionId == activeQuestion?.id else { return nil }
        return pythonBlocked
    }

    // MARK: Verdicts et avancement

    /// Verdicts connus, indexés par question (`attempt.reviews`).
    var verdicts: [String: AnnVerdict] {
        (attempt?.reviews ?? [:]).compactMapValues { $0.verdict }
    }

    /// `attemptComplete` : toutes les réponses de l'annale ont été envoyées.
    var attemptComplete: Bool {
        guard let attempt else { return false }
        return isAnnaleAttemptComplete(attempt, entry.questions)
    }

    /// `pendingQuestionIds` : questions sans réponse satisfaisante.
    var pendingQuestionIds: [String] {
        guard let attempt else { return entry.questions.map(\.id) }
        return annalePendingQuestionIds(attempt, entry.questions)
    }

    /// `submittableQuestionIds` : questions à envoyer, hors corrections en cours.
    var submittableQuestionIds: [String] {
        pendingQuestionIds.filter { !gradingQuestionIds.contains($0) }
    }

    /// Note de l'annale (`gradingScore`) : note sur 20, points et avancement.
    var gradingScore: ExGGradingScore {
        ExGGradingScoreCalculator.annale(attempt: attempt, questions: entry.questions)
    }

    /// Estimation prudente de la durée d'une correction (`questionCorrectionSeconds`).
    var questionCorrectionSeconds: Double {
        ConsentCorrectionSeconds.plannedSeconds(ConsentCorrectionSeconds.load())
    }

    // MARK: Correction et bilan

    /// `correctionDockCorrection` : la correction du lot en cours, pour le dock.
    var correctionDockCorrection: ExGCorrection? {
        guard let correction else { return nil }
        return ExGCorrection(
            startedAt: correction.startedAt,
            questionSeconds: questionCorrectionSeconds,
            completed: correction.completed,
            done: correctionDone,
            total: correction.submittedQuestionIds.count,
            questions: correctionSummaryQuestions
        )
    }

    /// Réponses rentrées du lot : tout le lot quand il est terminé, sinon le lot
    /// en cours (`correctionSummaryDone`).
    var correctionDone: Int {
        guard let correction else { return 0 }
        if correction.completed { return correction.submittedQuestionIds.count }
        return batchProgress?.done ?? 0
    }

    /// `correctionSummaryQuestions` : le verdict de chaque question du lot.
    var correctionSummaryQuestions: [ExGQuestion] {
        entry.questions.map { question in
            let review = attempt?.reviews[question.id]
            let answer = attempt?.answers[question.id] ?? ""
            return ExGQuestion(
                id: question.id,
                label: question.displayLabel,
                status: correctionQuestionStatus(question, review: review, answer: answer),
                reportAvailable: review != nil,
                feedback: review?.feedback
            )
        }
    }

    /// Statut d'une question du bilan (`correctionSummaryQuestions`).
    private func correctionQuestionStatus(
        _ question: AnnQuestion,
        review: AnnQuestionReview?,
        answer: String
    ) -> ExGQuestionStatus {
        if let review { return ExGQuestionStatus(rawValue: review.verdict.rawValue) ?? .pending }
        if gradingQuestionIds.contains(question.id) { return .pending }
        if gradingErrors[question.id] != nil { return .error }
        if answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return .unanswered }
        if correction?.submittedQuestionIds.contains(question.id) == true {
            return batchProgress == nil ? .error : .pending
        }
        return .pending
    }

    /// `correctionSubmittedIntact` : la copie est encore celle qui a été corrigée.
    var correctionSubmittedIntact: Bool {
        guard let correction else { return false }
        return correction.submittedQuestionIds.allSatisfy { attempt?.reviews[$0] != nil }
    }

    /// `resultCardVisible` : le bilan se lit sur la copie tant qu'elle est
    /// intacte et que l'élève ne l'a pas refermé.
    var resultCardVisible: Bool {
        guard let correction, correction.completed, correctionSubmittedIntact else { return false }
        return resultCardDismissedId != correction.submissionId
    }

    /// `correctionDockActive` : le dock prend la place du bouton de soumission
    /// pendant la correction d'un exercice entier, hors corrigé plein écran.
    /// Écart assumé : le repli du tableau blanc n'est pas lu depuis le lecteur.
    var correctionDockActive: Bool {
        wholeExerciseSubmissionOnly && correction != nil && mode != .solution
    }

    /// `showSupplementalWholeSubmit` : bouton d'exercice entier, seulement s'il
    /// fait plus que le bouton de la question courante.
    var showSupplementalWholeSubmit: Bool {
        guard !wholeExerciseSubmissionOnly else { return false }
        if batchProgress != nil { return true }
        return entry.questions.count > 1
            && submittableQuestionIds.contains { $0 != activeQuestion?.id }
    }

    /// `rankingUnread` : la dernière correction n'a pas encore été vue dans le
    /// classement du sujet (pastille du trophée, 18#8).
    var rankingUnread: Bool {
        CollExerciseRankingSeen.hasUnseen(
            history: attempt?.metricHistory ?? [],
            seenSubmissionId: rankingSeen[entry.id]
        )
    }

    /// Identifiant de compte local, comme `PremCodeSync`.
    var accountId: String {
        ConsentPremiumGate.accountId(email: session.profile.email)
    }
}
