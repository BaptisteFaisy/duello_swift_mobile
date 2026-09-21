//
//  ReportQuestionSheet.swift
//  Duello
//
//  Lot « Report » — compte rendu détaillé d'une question : verdict, énoncé
//  paginé, réponse soumise et corrigé de référence, dans des blocs repliables.
//
//  Fichiers source Expo portés (libellés repris mot pour mot) :
//    - src/components/QuestionCorrectionReportModal.tsx (QuestionCorrectionReportModal,
//                                                        VERDICT_PRESENTATION,
//                                                        ReviewVerdict, ReportSections,
//                                                        statementPages)
//    - src/components/question-report/ReportSection.tsx (ReportSection)
//    - src/utils/annaleAttempt.ts                       (AnnaleQuestionReview,
//                                                        AnnaleQuestionVerdict)
//
//  Contenu seul de l'écran : l'enveloppe (présentation plein écran, croix de
//  fermeture) reste à la charge de l'appelant. Les documents de sujet et de
//  corrigé (`statementDocument` / `referenceDocument`, des `ReactNode`) n'ont
//  pas d'équivalent Swift et ne sont pas repris.
//
//  Cible : iOS 16, aucune API iOS 17.
//
import SwiftUI

/// Verdict d'une question dans le compte rendu (`AnnaleQuestionReview` réduit à
/// son verdict et à sa justification).
struct ReportQuestionReview: Equatable {
    var verdict: AnnVerdict
    var feedback: String
}

/// Compte rendu détaillé d'une question (`QuestionCorrectionReportModal.tsx`).
struct ReportQuestionSheet: View {
    /// Numéro affiché à gauche de la croix, sans le mot « Question ».
    let questionNumber: String
    let answer: String
    let review: ReportQuestionReview?
    /// Extrait de l'énoncé propre à la question, montré par défaut.
    let questionStatement: String?
    let fullStatement: String?
    let referenceCorrection: String?
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            if let review {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        compteRendu(review)
                        enonce
                        reponseSoumise
                        corrige
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                }
            }
        }
        .background(Theme.background.ignoresSafeArea())
    }

    // MARK: En-tête

    private var header: some View {
        HStack {
            Text(questionNumber)
                .font(.system(size: 14, weight: .black))
                .foregroundStyle(Theme.ink)
                .padding(.horizontal, 10)
                .frame(minHeight: 28)
                .background(Theme.surfaceMuted)
                .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall))
                .accessibilityLabel("Question \(questionNumber)")

            Spacer(minLength: 8)

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 42, height: 42)
                    .background(Theme.surface)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Fermer le compte rendu de la question \(questionNumber)")
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
    }

    // MARK: Blocs

    private func compteRendu(_ review: ReportQuestionReview) -> some View {
        ReportCollapsibleSection(title: "Compte rendu") {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: review.verdict.icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(review.verdict.color)
                    Text(review.verdict.label)
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundStyle(review.verdict.color)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Statut : \(review.verdict.label)")
                statementText(review.feedback)
            }
        }
    }

    private var enonce: some View {
        ReportCollapsibleSection(title: "Énoncé") {
            let pages = statementPages()
            if pages.isEmpty {
                statementText("L’énoncé n’est pas disponible pour cette question.")
            } else {
                ReportStatementPager(pages: pages)
            }
        }
    }

    private var reponseSoumise: some View {
        ReportCollapsibleSection(title: "Réponse soumise") {
            statementText(answer)
        }
    }

    private var corrige: some View {
        ReportCollapsibleSection(title: "Corrigé") {
            if let referenceCorrection, !referenceCorrection.isEmpty {
                statementText(referenceCorrection)
            } else {
                statementText("Aucun corrigé de référence n’est disponible pour cette question.")
            }
        }
    }

    // MARK: Helpers

    /// Texte d'énoncé rendu comme `MathStatementText` (LaTeX → Unicode).
    private func statementText(_ text: String) -> some View {
        Text(LatexToUnicode.toUnicodeMath(text))
            .font(.system(size: 15))
            .foregroundStyle(Theme.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// Pages de l'énoncé (`statementPages`) : extrait de la question, puis
    /// énoncé complet s'il diffère. Le document de sujet (`statementDocument`,
    /// un `ReactNode`) n'est pas repris.
    private func statementPages() -> [ReportStatementPage] {
        var pages: [ReportStatementPage] = []
        if let questionStatement, !questionStatement.isEmpty {
            pages.append(ReportStatementPage(id: "question", text: questionStatement))
        }
        if let fullStatement,
           !fullStatement.isEmpty,
           fullStatement.trimmingCharacters(in: .whitespacesAndNewlines)
            != questionStatement?.trimmingCharacters(in: .whitespacesAndNewlines) {
            pages.append(ReportStatementPage(id: "full", text: fullStatement))
        }
        return pages
    }
}

// MARK: - Bloc repliable

/// Bloc du compte rendu (`ReportSection.tsx`) : fond blanc, léger contour, et
/// un chevron à droite du titre pour replier son contenu. Chaque bloc s'ouvre
/// déplié.
private struct ReportCollapsibleSection<Content: View>: View {
    let title: String
    let content: Content

    @State private var open = true

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                open.toggle()
            } label: {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.system(size: 16, weight: .heavy))
                        .foregroundStyle(Theme.ink)
                    Spacer(minLength: 6)
                    Image(systemName: open ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                }
                .frame(minHeight: 28)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(title), \(open ? "masquer" : "afficher") le contenu")

            if open {
                content
                    .padding(.top, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 12)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLarge))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusLarge)
                .stroke(Theme.border, lineWidth: 1)
        )
    }
}
