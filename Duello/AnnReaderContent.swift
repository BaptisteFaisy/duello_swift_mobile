import SwiftUI

// MARK: - Contenu du document et navigation entre questions

extension AnnReaderView {
    // MARK: Contenu

    @ViewBuilder
    var statementPane: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                documentBody
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
    }

    @ViewBuilder
    var questionNavigation: some View {
        if entry.questions.count > 1 {
            VStack(alignment: .leading, spacing: 6) {
                Text("Questions")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(Theme.inkFaint)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(entry.questions) { question in
                            questionChip(question)
                        }
                    }
                    .padding(.vertical, 1)
                }
            }
        }
    }

    private func questionChip(_ question: AnnQuestion) -> some View {
        let selected = question.id == (activeQuestionId ?? entry.questions.first?.id)
        let verdict = verdicts[question.id]
        let isClassic = classicQuestionIds.contains(question.id)
        let isForLater = unavailableQuestionIds.contains(question.id)
        let grading = gradingQuestionIds.contains(question.id)
        let gradingFailed = gradingErrors[question.id] != nil
        let skin = AnnQuestionChipSkin(selected: selected, verdict: verdict)
        return Button {
            activeQuestionId = question.id
        } label: {
            HStack(spacing: 4) {
                // Pendant la correction : indicateur d'activité ; en échec :
                // `refresh-circle`. Un verdict « Parfaite » n'affiche pas d'icône
                // (son contour vert suffit), comme la source.
                if grading {
                    ProgressView().tint(Theme.primary)
                } else if verdict == .perfect {
                    EmptyView()
                } else if let verdict {
                    IonIcon(name: verdict.icon, size: 14, color: verdict.color)
                } else if gradingFailed {
                    IonIcon(name: "refresh-circle", size: 14, color: Theme.like)
                }
                Text(question.displayLabel)
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(skin.text)
                if isClassic {
                    IonIcon(name: "star", size: 11, color: Theme.ink)
                }
                if isForLater {
                    Circle()
                        .fill(AnnQuestionChipSkin.prerequisiteDot)
                        .frame(width: 6, height: 6)
                }
            }
            .padding(.horizontal, 10)
            .frame(minWidth: 52, minHeight: 34)
            .background(skin.background)
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(skin.border, lineWidth: skin.borderWidth)
            )
            .opacity(isForLater ? 0.58 : 1)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel(
            for: question,
            verdict: verdict,
            classic: isClassic,
            later: isForLater,
            grading: grading,
            gradingFailed: gradingFailed
        ))
    }

    /// Libellé d'accessibilité du bouton de question, mot pour mot du lecteur.
    private func accessibilityLabel(
        for question: AnnQuestion,
        verdict: AnnVerdict?,
        classic: Bool,
        later: Bool,
        grading: Bool,
        gradingFailed: Bool
    ) -> String {
        var text = "Question \(question.displayLabel)"
        if let verdict {
            text += ", \(verdict.label.lowercased())"
        } else if grading {
            text += ", correction en cours"
        } else if gradingFailed {
            text += ", correction à relancer"
        }
        if classic { text += ", classique" }
        if later { text += ", conseillée pour plus tard" }
        return text
    }

    @ViewBuilder
    private var documentBody: some View {
        switch mode {
        case .statement:
            documentCard(
                title: nil,
                text: entry.statement,
                empty: "Énoncé indisponible"
            )
        case .markingScheme:
            documentCard(
                title: "Barème",
                text: entry.markingScheme,
                empty: "Document indisponible"
            )
        case .comments:
            documentCard(
                title: "Commentaires",
                text: entry.comments,
                empty: "Document indisponible"
            )
        case .solution:
            solutionBody
        }
    }

    @ViewBuilder
    private var solutionBody: some View {
        if entry.isWrittenPaper {
            documentCard(
                title: "Corrigé",
                text: entry.solution,
                empty: "Corrigé indisponible"
            )
        } else if !canShowSolution {
            lockedSolutionCard
        } else {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(entry.questions) { question in
                    questionCorrectionCard(question)
                }
            }
        }
    }

    /// Corrigé par question, verrouillé tant que la réponse n'est pas validée.
    private func questionCorrectionCard(_ question: AnnQuestion) -> some View {
        let verdict = verdicts[question.id]
        let unlocked = verdict != nil
            && (entry.difficulty < 5 || entry.difficulty >= 6 || (verdict?.isValidated ?? false))
        let isClassic = classicQuestionIds.contains(question.id)
        let correctionText = questionCorrectionText(question, unlocked: unlocked)
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text("Question \(question.displayLabel)")
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                if isClassic {
                    IonIcon(name: "star", size: 12, color: Theme.ink)
                        .accessibilityLabel("Question classique")
                }
                Spacer(minLength: 0)
                if unlocked {
                    // « ✦ Expliquer » : ouvre le prof IA sur le corrigé de la
                    // question (`openProfForCorrection`, `AnnaleViewer.tsx:3876-3886`).
                    Button {
                        explainCorrection(correctionText, question: question.displayLabel)
                    } label: {
                        Text("✦ Expliquer")
                            .font(.system(size: 11, weight: .heavy))
                            .foregroundStyle(Theme.surface)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Theme.primary)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Expliquer le corrigé de la question \(question.displayLabel)")
                }
                IonIcon(
                    name: unlocked ? "lock-open-outline" : "lock-closed-outline",
                    size: 15,
                    color: unlocked ? Theme.primary : Theme.inkFaint
                )
            }
            Text(correctionText)
                .font(Theme.readingFont)
                .foregroundStyle(unlocked ? Theme.ink : Theme.inkFaint)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .duelloCard()
    }

    /// Texte du corrigé d'une question, ou l'explication de son verrouillage,
    /// mot pour mot du lecteur Expo (`AnnaleViewer.tsx:3842-3857`).
    private func questionCorrectionText(_ question: AnnQuestion, unlocked: Bool) -> String {
        if unlocked {
            if entry.solution != nil {
                return LatexToUnicode.toUnicodeMath(entry.solution ?? "")
            }
            return "Consulte le compte rendu de cette question pour voir le corrigé de référence disponible."
        }
        if entry.difficulty == 5, verdicts[question.id] != nil {
            return "Très difficile · cette réponse doit être entièrement juste pour déverrouiller son corrigé."
        }
        return "Soumets cette réponse pour rendre son corrigé accessible."
    }

    private var lockedSolutionCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            IonIcon(name: "lock-closed-outline", size: 22, color: Theme.inkFaint)
            Text(solutionLockMessage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.inkSoft)
            if entry.isWrittenPaper {
                Text("Soumets l’exercice pour rendre son corrigé accessible.")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.inkFaint)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .duelloCard()
    }

    /// Carte de document : texte composé par `LatexToUnicode`, ou l'état
    /// d'indisponibilité du document.
    ///
    /// Le lecteur Expo charge le PDF puis le compose en HTML ; ici les
    /// documents arrivent retranscrits en texte avec la banque d'annales, et
    /// l'absence de texte veut dire « document indisponible ».
    @ViewBuilder
    private func documentCard(
        title: String?,
        text: String?,
        empty: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title {
                Text(title)
                    .font(.system(size: 13, weight: .heavy))
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.inkSoft)
            }
            if let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(LatexToUnicode.toUnicodeMath(text))
                    .font(Theme.readingFont)
                    .foregroundStyle(Theme.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    IonIcon(name: "cloud-offline-outline", size: 36, color: Theme.inkFaint)
                    Text(empty)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Theme.inkSoft)
                    Text("Vérifie ta connexion, puis réessaie.")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.inkFaint)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .duelloCard()
    }
}

// MARK: - Habillage d'une puce de question

/// Fond, contour et couleur de texte d'une puce de question, repris des styles
/// `questionTab*` du lecteur Expo (`AnnaleViewer.tsx:5553-5615`). Un verdict
/// posé l'emporte sur la sélection : le contour vert d'une réponse juste reste
/// visible même quand la puce est ouverte.
struct AnnQuestionChipSkin {
    /// `colors.prerequisitesMissing` (`theme.ts`) : pastille « conseillée pour
    /// plus tard », absente du thème Swift partagé.
    static let prerequisiteDot = Color(hex: 0xB42318)
    /// `colors.likeLight` (`theme.ts`) : fond de la puce d'une réponse fausse.
    static let incorrectBackground = Color(hex: 0xFDECEC)

    var background: Color
    var border: Color
    var borderWidth: CGFloat
    var text: Color

    init(selected: Bool, verdict: AnnVerdict?) {
        if selected {
            background = Theme.primaryLight
            border = Theme.primary
            borderWidth = 2
        } else {
            background = Theme.surface
            border = Theme.ink
            borderWidth = 1
        }
        text = Theme.ink
        guard let verdict else { return }
        switch verdict {
        case .perfect:
            background = Theme.gradingPerfectLight
            border = Theme.gradingPerfect
            borderWidth = 2
            text = Theme.gradingPerfect
        case .correct:
            background = Theme.surface
            border = AnnVerdict.masteryColor
            borderWidth = 2
            text = AnnVerdict.masteryColor
        case .partial:
            background = Theme.gradingPartialLight
            border = Theme.gradingPartial
        case .incorrect:
            background = AnnQuestionChipSkin.incorrectBackground
            border = Theme.like
        }
    }
}
