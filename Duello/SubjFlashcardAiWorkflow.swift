//
//  SubjFlashcardAiWorkflow.swift
//  Duello
//
//  Lot « Subj » (9-G) — branche « correction IA » de la session de révision :
//  carte QUESTION, champ de réponse, soumission au correcteur, puis carte
//  retournable teintée par le verdict avec la correction intégrée.
//
//  Fichier source Expo porté :
//    - src/screens/SubjectsScreen.tsx (lignes 2779-2947)
//        `FlashcardReviewModal` — `flashcardAiWorkflow`, `flashcardAiQuestionCard`,
//        `flashcardAiResultFlipArea`, `flashcardAiIntegratedResult`,
//        `flashcardAiSubmitButton(Docked)`, `continueAfterAiCorrection`,
//        `submitAiCorrection`.
//
//  Réutilisation stricte : le champ de réponse et l'aperçu composé viennent du
//  lot 9-F (`SubjFlashcardAnswerField`, `SubjAnswerComposition`) ; la notation
//  passe par `SubjFlashcardAiGrader` (`SubjFlashcardAnswerComposer.swift`).
//
//  Cible : iOS 16, aucune dépendance externe.
//
import SwiftUI

/// Bloc « réponse remise » du résultat IA : aperçu de la copie, verdict et
/// commentaire du correcteur, séparés du recto par un filet.
struct SubjFlashcardAiIntegratedResult: View {
    let grade: CollMathGrade
    let answer: String

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            SubjAnswerComposition(answer: answer, submitted: true)
            if grade.verdict != .correct {
                Text(SubjFlashcardReviewCopy.aiVerdict(grade.verdict))
                    .font(.system(size: 16, weight: .black))
                    .foregroundStyle(Theme.ink)
            }
            Text(LatexToUnicode.toUnicodeMath(grade.feedback))
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Theme.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 20)
        .overlay(alignment: .top) {
            Rectangle().fill(Theme.border).frame(height: 1)
        }
    }
}

/// Enchaînement IA : question → réponse → correction → carte retournable.
struct SubjFlashcardAiWorkflow: View {
    let card: CollFlashcard
    let chapterName: String
    let subject: String
    let gradingProgram: String
    let token: String?
    let verdictPending: Bool
    @Binding var response: String
    @Binding var answerVisible: Bool
    @Binding var mathKeyboardOpen: Bool
    @Binding var grading: Bool
    let onFlip: () -> Void
    let onVerdict: (CollFlashcardVerdict) async -> Void
    let onAuthenticationRequired: (() -> Void)?

    @State private var aiGrade: CollMathGrade?
    @State private var aiError = ""
    @State private var transcriptionPending = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 12) {
                    if let grade = aiGrade {
                        resultArea(grade)
                    } else {
                        questionCard
                        answerField
                        if !aiError.isEmpty {
                            Text(aiError)
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.ink)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            bottomAction
        }
        .onChange(of: grading) { value in
            if value { mathKeyboardOpen = false }
        }
    }

    // MARK: Question et réponse

    private var questionCard: some View {
        SubjFlashcardFace(
            sideLabel: SubjFlashcardReviewCopy.sideQuestion,
            minHeight: SubjFlashcardReviewMetrics.aiQuestionMinHeight,
            contentBottomPadding: 34
        ) {
            SubjFlashcardMathText(text: card.question)
        }
    }

    /// Champ du lot 9-F : saisie, dictée, photo et bascule du clavier maths.
    private var answerField: some View {
        SubjFlashcardAnswerField(
            answer: response,
            card: card,
            chapterName: chapterName,
            subject: subject,
            disabled: grading,
            mathKeyboardOpen: mathKeyboardOpen,
            onChangeAnswer: { value in
                response = value
                aiError = ""
            },
            onToggleMathKeyboard: {
                mathKeyboardOpen.toggle()
            },
            onTranscriptionStateChange: { pending in
                transcriptionPending = pending
            }
        )
    }

    // MARK: Résultat retournable

    private func resultArea(_ grade: CollMathGrade) -> some View {
        SubjFlashcardFlipCard(
            showingBack: answerVisible,
            minHeight: SubjFlashcardReviewMetrics.aiResultMinHeight
        ) {
            SubjFlashcardFace(
                sideLabel: SubjFlashcardReviewCopy.sideFront,
                tint: .ai(grade.verdict),
                tapHint: SubjFlashcardReviewCopy.tapHintToBack,
                minHeight: SubjFlashcardReviewMetrics.aiResultMinHeight,
                contentBottomPadding: SubjFlashcardReviewMetrics.aiResultContentBottom
            ) {
                VStack(spacing: 22) {
                    SubjFlashcardMathText(text: card.question)
                    SubjFlashcardAiIntegratedResult(grade: grade, answer: response)
                }
            }
        } back: {
            SubjFlashcardFace(
                sideLabel: SubjFlashcardReviewCopy.sideBack,
                tint: .ai(grade.verdict),
                tapHint: SubjFlashcardReviewCopy.tapHintToFront,
                minHeight: SubjFlashcardReviewMetrics.aiResultMinHeight,
                contentBottomPadding: SubjFlashcardReviewMetrics.aiResultContentBottom
            ) {
                SubjFlashcardMathText(text: verso(grade))
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { onFlip() }
    }

    /// `aiGrade.correction ?? card.answer` : le corrigé du correcteur, sinon la
    /// réponse attendue de la carte.
    private func verso(_ grade: CollMathGrade) -> String {
        grade.correction.isEmpty ? card.answer : grade.correction
    }

    // MARK: Action de bas d'écran

    @ViewBuilder private var bottomAction: some View {
        if aiGrade != nil {
            Button {
                continueAfterGrade()
            } label: {
                Text(SubjFlashcardReviewCopy.continueLabel)
                    .frame(maxWidth: .infinity, minHeight: 50)
            }
            .buttonStyle(DuelloPrimaryButton())
            .disabled(verdictPending)
        } else {
            Button {
                Task { await submitCorrection() }
            } label: {
                HStack(spacing: 8) {
                    if grading {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(Theme.surface)
                    }
                    Text(grading
                        ? SubjFlashcardReviewCopy.submitBusy
                        : SubjFlashcardReviewCopy.submitIdle)
                        .frame(maxWidth: .infinity, minHeight: 50)
                }
            }
            .buttonStyle(DuelloPrimaryButton())
            .disabled(grading || transcriptionPending)
            .accessibilityLabel(SubjFlashcardReviewCopy.submitAccessibility)
        }
    }

    // MARK: Soumission

    private func submitCorrection() async {
        let submitted = response.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !grading, !transcriptionPending else { return }
        guard !submitted.isEmpty else {
            aiError = SubjFlashcardReviewCopy.emptyAnswerError
            return
        }
        grading = true
        aiError = ""
        do {
            aiGrade = try await SubjFlashcardAiGrader.grade(
                card: card,
                chapterName: chapterName,
                program: gradingProgram,
                answer: submitted,
                token: token
            )
        } catch let error as CollGradingError {
            if case .authentication = error { onAuthenticationRequired?() }
            aiError = error.errorDescription ?? SubjFlashcardReviewCopy.gradingUnavailable
        } catch {
            aiError = SubjFlashcardReviewCopy.gradingUnavailable
        }
        grading = false
    }

    private func continueAfterGrade() {
        guard let grade = aiGrade else { return }
        Task { await onVerdict(verdict(for: grade.verdict)) }
    }

    /// `incorrect → wrong`, `partial → partial`, sinon `correct`.
    private func verdict(for verdict: CollVerdict) -> CollFlashcardVerdict {
        switch verdict {
        case .incorrect: return .wrong
        case .partial: return .partial
        case .perfect, .correct: return .correct
        }
    }
}
