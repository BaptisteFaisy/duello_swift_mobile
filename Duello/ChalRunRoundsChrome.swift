//
//  ChalRunRoundsChrome.swift
//  Duello
//
//  Chrome du défi (`ChalRunRounds`) : chrono (`DuelChrono`), onglets des
//  questions (`questionTabs`) et avis en ligne (`successNotice`).
//  Découpé de `ChalRunRounds.swift` le 2026-09-29 (ratchet de complexité :
//  fichier 502 l. > 500) — contenu repris **ligne pour ligne**, aucun type,
//  propriété, méthode ni signature renommé.
//  Cible : iOS 16.
//
import SwiftUI

/// Chrono du défi (`DuelChrono`) : décompte « m:ss », rouge dans la dernière
/// minute, rendu depuis un instantané déjà borné par `ChalTimer`.
struct ChalRunChrono: View {
    let remainingSeconds: Int

    var body: some View {
        Text(ChalTimer.clock(remainingSeconds))
            .font(.system(size: 20, weight: .black).monospacedDigit())
            .foregroundStyle(remainingSeconds <= 60 ? Theme.like : Theme.ink)
    }
}

/// Onglets des questions d'un exercice (`questionTabs`) : disent laquelle est
/// ouverte et lesquelles portent déjà une réponse. Un exo d'une seule question
/// n'a pas d'onglets : son champ est la copie.
struct ChalRunQuestionTabs: View {
    let questions: [DuelExercise.Question]
    let activeId: String
    let answers: [String: String]
    var disabled: Bool = false
    var onSelect: (String) -> Void

    var body: some View {
        if questions.count > 1 {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(questions.enumerated()), id: \.element.id) { index, question in
                        tab(index: index, question: question)
                    }
                }
            }
        }
    }

    private func tab(index: Int, question: DuelExercise.Question) -> some View {
        let active = question.id == activeId
        let written = !(answers[question.id] ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty
        return Button {
            onSelect(question.id)
        } label: {
            HStack(spacing: 5) {
                Text(duelQuestionLabel(question, index))
                if written {
                    Circle()
                        .fill(active ? Theme.surface : Theme.ink)
                        .frame(width: 5, height: 5)
                }
            }
            .font(.system(size: 13, weight: .heavy))
            .foregroundStyle(active ? Theme.surface : Theme.inkSoft)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(active ? Theme.ink : Theme.surfaceMuted)
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(active ? Color.clear : Theme.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.5 : 1)
        .accessibilityLabel("Question \(duelQuestionLabel(question, index))")
    }
}

/// Avis en ligne d'un défi (`successNotice`) : pénalité, bonus ou alerte.
struct ChalRunNotice: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            IonIcon(name: icon, size: 20, color: Theme.ink)
            Text(text)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Theme.inkSoft)
                .lineSpacing(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Theme.primaryLight)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
    }
}
