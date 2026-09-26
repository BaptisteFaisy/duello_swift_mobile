//
//  SubjFlashcardReviewSession.swift
//  Duello
//
//  Lot « Subj » (9-G) — fenêtre plein écran de révision d'un paquet de
//  flashcards : file d'attente d'une carte, retournement recto/verso, verdict
//  (auto-correction ou correction IA), compteurs de session et bilan de fin.
//
//  Fichier source Expo porté :
//    - src/screens/SubjectsScreen.tsx (lignes 2336-2973)
//        `FlashcardReviewModal` — sortie séquencée (`abandonReview`,
//        `claimSuccessReview`), remise à zéro par carte (`useLayoutEffect` sur
//        `[card.id, reviewStep]`), bascule recto/verso, alertes de sortie.
//
//  Répartition : les faces dans `SubjFlashcardReviewCard.swift`, le chrome dans
//  `SubjFlashcardReviewChrome.swift`, le bilan dans
//  `SubjFlashcardReviewSummary.swift` et la branche IA dans
//  `SubjFlashcardAiWorkflow.swift` (+ `SubjFlashcardAnswerComposer.swift`). Le
//  champ de réponse et l'aperçu composé sont ceux du lot 9-F
//  (`SubjFlashcardAnswerField`, `SubjAnswerComposition`) : ce lot ne les
//  redéfinit pas.
//
//  Présentation attendue côté écran des matières :
//  `.fullScreenCover(isPresented: $revisionOpen) { SubjFlashcardReviewModal(...) }`.
//  La fenêtre masque son contenu (`visible = false`) avant d'appeler
//  `onAbandon` / `onClaimSuccess` à l'image suivante, comme la source qui
//  évitait ainsi un flash au retour.
//
//  Cible : iOS 16, aucune dépendance externe.
//
import Foundation
import SwiftUI

/// Fenêtre plein écran de révision (`FlashcardReviewModal`).
struct SubjFlashcardReviewModal: View {
    // MARK: Entrées

    /// Carte courante de la file d'attente.
    let card: CollFlashcard
    /// Étape de la session : force la remise à zéro quand la même carte revient
    /// en tête (session d'une seule carte).
    let reviewStep: Int
    let correctionMode: SubjFlashcardCorrectionMode
    let chapterId: String
    let chapterName: String
    let gradingProgram: String
    let subject: String
    let sessionCounts: CollFlashcardSessionCounts
    var topInset: CGFloat = 0
    var bottomInset: CGFloat = 0
    /// Gain XP à faire flotter, `nil` hors gain.
    let xpGain: Double?
    /// XP gagnés dans la session : montant annoncé par l'alerte de sortie.
    let sessionXp: Double
    /// Bilan non `nil` : la session est terminée.
    let successSummary: SubjFlashcardReviewSummary?
    let onVerdict: (CollFlashcardVerdict) async -> Void
    let onAbandon: () async -> Void
    let onClaimSuccess: () -> Void
    var onAuthenticationRequired: (() -> Void)? = nil
    var onMathKeyboardVisibilityChange: ((Bool) -> Void)? = nil

    // MARK: État

    @EnvironmentObject private var session: SessionStore
    @State private var visible = true
    @State private var answerVisible = false
    @State private var response = ""
    @State private var mathKeyboardOpen = false
    @State private var grading = false
    @State private var verdictPending = false
    @State private var closeConfirmationOpen = false
    @State private var closing = false

    // MARK: Corps

    var body: some View {
        Group {
            if visible {
                if let successSummary {
                    summaryScreen(successSummary)
                } else {
                    reviewScreen
                }
            } else {
                Color.clear
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background.ignoresSafeArea())
        .alert(SubjFlashcardReviewCopy.exitTitle, isPresented: $closeConfirmationOpen) {
            Button(SubjFlashcardReviewCopy.exitKeep, role: .cancel) {}
            Button(SubjFlashcardReviewCopy.exitConfirm, role: .destructive) {
                abandonReview()
            }
        } message: {
            Text(SubjFlashcardReviewCopy.exitMessage(sessionXp: sessionXp))
        }
        .onChange(of: card.id) { _ in resetCard() }
        .onChange(of: reviewStep) { _ in resetCard() }
        .onChange(of: mathKeyboardOpen) { open in
            onMathKeyboardVisibilityChange?(open)
        }
        .onDisappear { onMathKeyboardVisibilityChange?(false) }
    }

    // MARK: Révision

    private var reviewScreen: some View {
        VStack(spacing: 0) {
            if correctionMode == .ai && mathKeyboardOpen {
                mathKeyboardBar
            }
            SubjFlashcardReviewHeader(counts: sessionCounts, xpGain: xpGain)
            if correctionMode == .selfCorrection {
                ScrollView(.vertical, showsIndicators: false) {
                    selfFlipArea
                        .padding(.top, 12)
                        .padding(.bottom, 24)
                }
                if answerVisible {
                    SubjFlashcardVerdictRow(pending: verdictPending) { verdict in
                        Task { await handleVerdict(verdict) }
                    }
                }
            } else {
                SubjFlashcardAiWorkflow(
                    card: card,
                    chapterName: chapterName,
                    subject: subject,
                    gradingProgram: gradingProgram,
                    token: session.token,
                    verdictPending: verdictPending,
                    response: $response,
                    answerVisible: $answerVisible,
                    mathKeyboardOpen: $mathKeyboardOpen,
                    grading: $grading,
                    onFlip: toggleAnswer,
                    onVerdict: onVerdict,
                    onAuthenticationRequired: onAuthenticationRequired
                )
                // Une nouvelle carte (ou un nouveau tour de la même carte)
                // repart d'une correction vierge.
                .id("\(card.id)#\(reviewStep)")
            }
        }
        .padding(.horizontal, SubjFlashcardReviewMetrics.horizontalPadding)
        .padding(.top, topInset)
        .padding(.bottom, bottomInset)
        .overlay(alignment: .topTrailing) {
            SubjFlashcardExitButton(disabled: verdictPending || grading) {
                requestClose()
            }
            .padding(.top, max(topInset - 8, 0))
            .padding(.trailing, SubjFlashcardReviewMetrics.exitButtonTrailing)
        }
    }

    /// Carte d'auto-correction : recto question, verso réponse.
    private var selfFlipArea: some View {
        SubjFlashcardFlipCard(
            showingBack: answerVisible,
            minHeight: SubjFlashcardReviewMetrics.selfCardMinHeight
        ) {
            SubjFlashcardFace(
                sideLabel: SubjFlashcardReviewCopy.sideFront,
                tapHint: SubjFlashcardReviewCopy.tapHintFlip,
                minHeight: SubjFlashcardReviewMetrics.selfCardMinHeight
            ) {
                SubjFlashcardMathText(text: card.question)
            }
        } back: {
            SubjFlashcardFace(
                sideLabel: SubjFlashcardReviewCopy.sideBack,
                tint: .muted,
                minHeight: SubjFlashcardReviewMetrics.selfCardMinHeight
            ) {
                SubjFlashcardMathText(text: card.answer)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { toggleAnswer() }
    }

    /// Clavier maths, posé au-dessus de l'en-tête (la source déborde des marges
    /// de l'écran : `marginHorizontal: -18`).
    private var mathKeyboardBar: some View {
        MathKeyboardView(
            mode: .math,
            onInsert: { text in
                response = SubjFlashcardMathEditing.insert(text, into: response)
            },
            onBackspace: {
                response = SubjFlashcardMathEditing.deleteLast(response)
            },
            onClose: { mathKeyboardOpen = false }
        )
        .padding(.top, SubjFlashcardReviewMetrics.mathKeyboardTop)
        .padding(.horizontal, -SubjFlashcardReviewMetrics.horizontalPadding)
    }

    // MARK: Bilan

    private func summaryScreen(_ summary: SubjFlashcardReviewSummary) -> some View {
        SubjFlashcardRevisionSummary(summary: summary, onClaimXp: claimSuccessReview)
            .padding(.top, topInset)
            .padding(.bottom, bottomInset)
    }

    // MARK: Actions

    /// `useLayoutEffect [card.id, reviewStep]` : nouvelle carte, session neuve.
    private func resetCard() {
        answerVisible = false
        response = ""
        mathKeyboardOpen = false
        grading = false
        verdictPending = false
    }

    private func toggleAnswer() {
        withAnimation(.spring(response: SubjFlashcardReviewMetrics.flipDuration, dampingFraction: 0.82)) {
            answerVisible.toggle()
        }
    }

    private func requestClose() {
        guard !closing, !closeConfirmationOpen, !verdictPending, !grading else { return }
        closeConfirmationOpen = true
    }

    /// Sortie par la croix : masquer la fenêtre, puis signaler l'abandon.
    private func abandonReview() {
        guard !closing else { return }
        closing = true
        visible = false
        DispatchQueue.main.async {
            Task { await onAbandon() }
        }
    }

    /// Sortie par le bilan : même séquence, sans alerte.
    private func claimSuccessReview() {
        guard !closing else { return }
        closing = true
        visible = false
        DispatchQueue.main.async {
            onClaimSuccess()
        }
    }

    private func handleVerdict(_ verdict: CollFlashcardVerdict) async {
        guard !verdictPending else { return }
        verdictPending = true
        await onVerdict(verdict)
        verdictPending = false
    }
}
