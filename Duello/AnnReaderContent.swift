import SwiftUI

// MARK: - Contenu du document et navigation entre questions

extension AnnReaderView {
    // MARK: Contenu

    @ViewBuilder
    var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                questionNavigation
                documentBody
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
    }

    @ViewBuilder
    private var questionNavigation: some View {
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
        return Button {
            activeQuestionId = question.id
        } label: {
            HStack(spacing: 5) {
                if let verdict {
                    Image(systemName: verdict.icon)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(verdict.color)
                }
                Text(question.displayLabel)
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(selected ? Theme.surface : Theme.inkSoft)
                if isClassic {
                    Image(systemName: "star.fill")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Theme.ink)
                }
                if isForLater {
                    Circle()
                        .fill(Theme.like)
                        .frame(width: 6, height: 6)
                }
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .background(selected ? Theme.ink : Theme.surfaceMuted)
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(selected ? Color.clear : Theme.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel(for: question, verdict: verdict, classic: isClassic, later: isForLater))
    }

    /// Libellé d'accessibilité du bouton de question, mot pour mot du lecteur.
    private func accessibilityLabel(
        for question: AnnQuestion,
        verdict: AnnVerdict?,
        classic: Bool,
        later: Bool
    ) -> String {
        var text = "Question \(question.displayLabel)"
        if let verdict {
            text += ", \(verdict.label.lowercased())"
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
                empty: "Document indisponible"
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
        let unlocked = verdict != nil && (entry.difficulty < 5 || (verdict?.isValidated ?? false))
        let isClassic = classicQuestionIds.contains(question.id)
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text("Question \(question.displayLabel)")
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                if isClassic {
                    Image(systemName: "star.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Theme.ink)
                }
                Spacer(minLength: 0)
                Image(systemName: unlocked ? "lock.open" : "lock")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(unlocked ? Theme.ink : Theme.inkFaint)
            }
            Text(questionCorrectionText(question, unlocked: unlocked))
                .font(Theme.readingFont)
                .foregroundStyle(unlocked ? Theme.ink : Theme.inkFaint)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .duelloCard()
    }

    /// Texte du corrigé d'une question, ou l'explication de son verrouillage,
    /// mot pour mot du lecteur Expo.
    private func questionCorrectionText(_ question: AnnQuestion, unlocked: Bool) -> String {
        if unlocked {
            if entry.solution != nil {
                return LatexToUnicode.toUnicodeMath(entry.solution ?? "")
            }
            return "Consulte le compte rendu de cette question pour voir le corrigé de référence disponible."
        }
        if entry.difficulty >= 5, verdicts[question.id] != nil {
            let level = entry.difficulty == 6 ? "Extrême" : "Très difficile"
            return "\(level) · cette réponse doit être entièrement juste pour déverrouiller son corrigé."
        }
        return "Soumets cette réponse pour rendre son corrigé accessible."
    }

    private var lockedSolutionCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "lock")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Theme.inkFaint)
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
                    Image(systemName: "cloud")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(Theme.inkFaint)
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
