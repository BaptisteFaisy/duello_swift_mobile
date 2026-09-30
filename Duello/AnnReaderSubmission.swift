//
//  AnnReaderSubmission.swift
//  Duello
//
//  Soumission du lecteur d'annale (P0 18#2) : envoi d'une réponse ou de la copie
//  entière, garde du programme Python avant la correction (18#5) et barrière
//  Premium + consentement IA (`submitWithCorrectionAccess`, `AnnaleViewer.tsx`).
//
//  Fichier source Expo porté : `src/components/AnnaleViewer.tsx`
//  (`submitCurrentAnswer`, `gradeCurrentAnswer`, `retryAutomaticGrade`,
//  `submitWholeExercise`, `gradeWholeExercise`, `checkPythonBeforeCorrection`).
//
//  Cible : iOS 16.
//
import SwiftUI

extension AnnReaderView {
    // MARK: Question ouverte

    /// `selectQuestion` : change de question en gardant la réponse en cours dans
    /// la tentative, puis rouvre le brouillon de la nouvelle.
    func selectQuestion(_ question: AnnQuestion) {
        flushDraftToAttempt()
        activeQuestionId = question.id
        draft = attempt?.answers[question.id] ?? ""
    }

    /// `commitAttempt` : range le brouillon affiché dans les réponses de la
    /// tentative (le portage n'écrit qu'au changement de question et à l'envoi).
    func flushDraftToAttempt() {
        guard let activeQuestionId else { return }
        var current = attempt ?? emptyAnnaleAttempt(itemId: entry.id)
        current.answers[activeQuestionId] = draft
        current.updatedAt = annNowISOString()
        attempt = current
    }

    // MARK: Soumission d'une réponse

    /// `submitCurrentAnswer` : envoie la réponse affichée, une fois l'abonnement
    /// confirmé (`submitWithCorrectionAccess`).
    func submitCurrentAnswer(skipPythonRun: Bool = false) async {
        guard let activeQuestion, !currentAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              currentReview == nil, !pythonRunning, !activeQuestionGrading else { return }
        let questionId = activeQuestion.id
        await requestCorrectionWithConsent(questionIds: [questionId]) {
            await gradeCurrentAnswer(skipPythonRun: skipPythonRun)
        }
    }

    /// `gradeCurrentAnswer` : exécute le programme Python de la question, puis
    /// envoie la réponse affichée.
    func gradeCurrentAnswer(skipPythonRun: Bool = false) async {
        guard let activeQuestion, !currentAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              currentReview == nil else { return }
        gradingErrors[activeQuestion.id] = nil
        pythonBlocked = nil
        if !skipPythonRun {
            let failed = await firstBlockingPythonQuestion([activeQuestion.id])
            if failed != nil { return }
            if attempt?.reviews[activeQuestion.id] != nil { return }
        }
        let answer = attempt?.answers[activeQuestion.id] ?? currentAnswer
        submitAnswer(question: activeQuestion, answer: answer)
    }

    /// `retryAutomaticGrade` : relance la correction de la question ouverte
    /// après un échec, sans repasser par l'exécution Python.
    func retryAutomaticGrade() {
        guard let question = activeQuestion,
              !currentAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !activeQuestionGrading else { return }
        let answer = currentAnswer
        Task { @MainActor in
            await requestCorrectionWithConsent(questionIds: [question.id]) {
                submitAnswer(question: question, answer: answer)
            }
        }
    }

    // MARK: Soumission de la copie entière

    /// `submitWholeExercise` : corrige d'un coup toutes les réponses écrites, une
    /// fois l'abonnement confirmé.
    func submitWholeExercise(skipPythonRun: Bool = false) async {
        guard !submittableQuestionIds.isEmpty, batchProgress == nil, !pythonRunning else { return }
        let ids = submittableQuestionIds
        await requestCorrectionWithConsent(questionIds: ids) {
            await gradeWholeExercise(skipPythonRun: skipPythonRun)
        }
    }

    /// `gradeWholeExercise` : ouvre le lot de corrections ; un échec Python
    /// rouvre la question fautive sans consommer de correction.
    func gradeWholeExercise(skipPythonRun: Bool = false) async {
        guard !submittableQuestionIds.isEmpty, batchProgress == nil, !pythonRunning else { return }
        flushDraftToAttempt()
        for id in submittableQuestionIds { gradingErrors[id] = nil }
        pythonBlocked = nil

        if !skipPythonRun {
            let failed = await firstBlockingPythonQuestion(submittableQuestionIds)
            if let failed {
                if let question = entry.questions.first(where: { $0.id == failed }) {
                    selectQuestion(question)
                }
                return
            }
        }

        let ids = submittableQuestionIds
        let startedAt = Date().timeIntervalSince1970 * 1000
        correction = AnnCorrectionState(
            submissionId: "\(entry.id)-\(Int(startedAt))-\(UUID().uuidString.prefix(8))",
            startedAt: startedAt,
            submittedQuestionIds: ids,
            spentSeconds: attempt?.spentSeconds ?? 0
        )
        resultCardDismissedId = nil
        batchPendingQuestionIds = Set(ids)
        batchProgress = AnnBatchProgress(done: 0, total: ids.count)
        for id in ids {
            guard let question = entry.questions.first(where: { $0.id == id }),
                  submitAnswer(question: question, answer: attempt?.answers[id] ?? "")
            else { finishBatchQuestion(id); continue }
        }
    }

    // MARK: Garde du programme Python (18#5)

    /// `checkPythonBeforeCorrection` (`AnnaleViewer.tsx:3375`) : exécute les
    /// programmes des questions visées avant d'engager leur correction et rend
    /// l'identifiant de la première qui échoue, `nil` si tout tourne.
    ///
    /// Écart assumé : une console jamais montée (`pythonModel.hasStarted` faux)
    /// ne bloque rien, comme `pythonConsole.current === null` de la source. La
    /// réponse est réduite à ses blocs Python (`PythonAnswer.sourceFromAnswer`) :
    /// la prose d'une réponse mixte n'est jamais exécutée.
    func firstBlockingPythonQuestion(_ questionIds: [String]) async -> String? {
        guard pythonModel.hasStarted else { return nil }
        pythonRunning = true
        defer { pythonRunning = false }
        let sources = questionIds.compactMap { id -> (id: String, source: String)? in
            let answer = attempt?.answers[id] ?? (activeQuestionId == id ? draft : "")
            guard let source = PythonAnswer.sourceFromAnswer(answer) else { return nil }
            return (id: id, source: source)
        }
        if let blocked = await pythonModel.firstBlockingQuestion(sources),
           let result = pythonModel.result {
            pythonBlocked = AnnPythonBlocked(questionId: blocked, result: result)
            return blocked
        }
        return nil
    }

    // MARK: Barrière Premium + consentement IA

    /// `submitWithCorrectionAccess` : une correction IA est réservée à
    /// l'abonnement Premium, puis demande l'accord de partage IA. Sans l'un ou
    /// l'autre, rien ne part et le refus est affiché sur les questions visées.
    func requestCorrectionWithConsent(
        questionIds: [String],
        action: @escaping @MainActor () async -> Void
    ) async {
        _ = await ConsentPremiumGate.gate(tool: .aiCorrection, accountId: accountId) {
            if CtdAiConsent.isGranted {
                await action()
            } else {
                pendingCorrectionAction = action
                pendingCorrectionQuestionIds = questionIds
                correctionConsentVisible = true
            }
        }
    }

    /// `resolveConsent` : accord donné, la soumission retenue part ; refus, les
    /// questions visées portent le message de refus.
    func resolveCorrectionConsent(granted: Bool) {
        let action = pendingCorrectionAction
        let questionIds = pendingCorrectionQuestionIds
        pendingCorrectionAction = nil
        pendingCorrectionQuestionIds = []
        guard granted, let action else {
            if !granted {
                for id in questionIds { gradingErrors[id] = CtdAiConsent.declinedLabel }
            }
            return
        }
        CtdAiConsent.grant()
        Task { @MainActor in await action() }
    }
}
