//
//  EvEventCorrectionView.swift
//  Duello
//
//  Section « Correction » de la page d'événement : pendant la correction, un
//  état « en cours » avec la progression ; une fois la copie du compte corrigée,
//  la note sur 20, les XP gagnés, puis question par question le compte rendu de
//  l'IA et la réponse soumise transcrite. Le corrigé officiel reste scellé
//  jusqu'à la fin réelle de l'événement.
//
//  Fichier source Expo porté : `src/components/event/EventCorrectionView.tsx`.
//  Substitution SF Symbols : chevron-up/down → chevron.up/chevron.down.
//
//  Cible : iOS 16.
//
import SwiftUI

struct EvEventCorrectionView: View {
    let results: EvResultsState
    let questions: [EvEventQuestion]
    let durationMinutes: Int

    var body: some View {
        if let own = results.own {
            if own.graded {
                graded(own)
            } else {
                inProgress
            }
        } else {
            notParticipated
        }
    }

    /// Le compte n'a pas participé à cet événement.
    private var notParticipated: some View {
        Text("Tu n'as pas participé à cet événement.")
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(Theme.inkSoft)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
    }

    /// Correction en cours : progression des copies corrigées.
    private var inProgress: some View {
        VStack(spacing: 10) {
            ProgressView()
            Text("Correction en cours…")
                .font(.system(size: 15, weight: .heavy))
                .foregroundStyle(Theme.ink)
            Text("\(results.gradedParticipants)/\(results.participants) copies corrigées")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.inkFaint)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }

    /// Compte rendu : note sur 20, XP gagnés, puis question par question.
    private func graded(_ own: EvParticipation) -> some View {
        VStack(spacing: 12) {
            VStack(spacing: 4) {
                Text("\(EvEventScoring.formatScore(own.score ?? 0))/20")
                    .font(.system(size: 30, weight: .black))
                    .monospacedDigit()
                    .foregroundStyle(Theme.ink)
                Text("+\(own.xpAwarded) XP gagnés")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(Theme.inkSoft)
            }
            .frame(maxWidth: .infinity)
            .padding(18)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLarge))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusLarge)
                    .stroke(Theme.border, lineWidth: 1)
            )

            ForEach(Array(questions.enumerated()), id: \.element.id) { index, question in
                EvEventCorrectionQuestion(
                    question: question,
                    index: index,
                    result: own.results?[question.id],
                    answer: own.answers[question.id] ?? "",
                    photoCount: own.photoUris.count,
                    solutionsAvailable: results.solutionsAvailable
                )
            }

            Text(durationNote(own))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.inkFaint)
                .multilineTextAlignment(.center)
                .padding(.top, 8)
        }
        .padding(16)
        .padding(.bottom, 32)
    }

    /// Note de durée et de photos transmises avec la copie.
    private func durationNote(_ own: EvParticipation) -> String {
        let photos = own.photoUris.count
        let plural = photos > 1 ? "s" : ""
        return "Sujet de \(durationMinutes) minutes — \(photos) photo\(plural) transmise\(plural) avec la copie."
    }
}

// MARK: - Question corrigée

/// Question corrigée, repliable : compte rendu, réponse soumise, puis corrigé
/// officiel s'il est dévoilé.
private struct EvEventCorrectionQuestion: View {
    let question: EvEventQuestion
    let index: Int
    let result: EvQuestionResult?
    let answer: String
    let photoCount: Int
    let solutionsAvailable: Bool

    @State private var open = true

    var body: some View {
        if let result {
            VStack(alignment: .leading, spacing: 0) {
                Button { open.toggle() } label: {
                    HStack(spacing: 10) {
                        Text("\(index + 1)")
                            .font(.system(size: 12, weight: .black))
                            .foregroundStyle(Theme.ink)
                            .frame(width: 24, height: 24)
                            .background(Theme.surfaceMuted)
                            .clipShape(Circle())
                        Text(verdictLabel(result.verdict))
                            .font(.system(size: 13, weight: .heavy))
                            .foregroundStyle(Theme.ink)
                        Spacer(minLength: 0)
                        Image(systemName: open ? "chevron.up" : "chevron.down")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.inkSoft)
                    }
                    .padding(12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                if open { questionBody(result) }
            }
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusMedium)
                    .stroke(Theme.border, lineWidth: 1)
            )
        }
    }

    /// Compte rendu de la question, réponse soumise et corrigé éventuel.
    private func questionBody(_ result: EvQuestionResult) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            label("Compte rendu")
            Text(result.feedback.isEmpty ? "—" : result.feedback)
                .font(.system(size: 13))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
            label("Réponse soumise")
            Text(answerText)
                .font(.system(size: 13))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
            if solutionsAvailable {
                label("Corrigé")
                Text(question.solution)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Le corrigé sera accessible à la fin de l'événement.")
                    .font(.system(size: 12, weight: .semibold))
                    .italic()
                    .foregroundStyle(Theme.inkFaint)
                    .padding(.top, 6)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
    }

    /// Réponse transcrite, ou mention de la photo rendue, ou rien.
    private var answerText: String {
        if !answer.isEmpty { return answer }
        if photoCount > 0 { return "Réponse rendue en photo (voir compte rendu ci-dessus)." }
        return "Aucune réponse."
    }

    /// Libellé de section en capitales, au-dessus de chaque bloc.
    private func label(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .heavy))
            .textCase(.uppercase)
            .tracking(0.5)
            .foregroundStyle(Theme.inkFaint)
            .padding(.top, 6)
    }
}

/// Libellé français d'un verdict (`verdictLabel`).
private func verdictLabel(_ verdict: EvQuestionVerdict) -> String {
    switch verdict {
    case .perfect: return "Parfait"
    case .correct: return "Juste"
    case .partial: return "Partiel"
    case .incorrect: return "Incorrect"
    }
}
