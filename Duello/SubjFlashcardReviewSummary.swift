//
//  SubjFlashcardReviewSummary.swift
//  Duello
//
//  Lot « Subj » (9-G) — bilan de fin de session de révision.
//
//  Fichier source Expo porté :
//    - src/components/RevisionSuccessSummary.tsx (variante `revision`)
//        métriques « +n XP gagnés », « … au total », « n % du cours maîtrisé »,
//        collecte animée des XP puis bouton « Recevoir mes XP ».
//    - src/screens/SubjectsScreen.tsx (lignes 2602-2617) : `SuccessSummary`
//        appelé avec `revision` et `onClaimXp={claimSuccessReview}`.
//
//  La collecte des XP (`useRevisionClaim`) est reproduite : le bloc des XP
//  monte et s'efface sur 1,4 s, puis le bilan se ferme après 0,9 s.
//
//  Cible : iOS 16, aucune dépendance externe.
//
import Foundation
import SwiftUI

/// Bilan de la session de révision (style `revision`).
struct SubjFlashcardRevisionSummary: View {
    let summary: SubjFlashcardReviewSummary
    let onClaimXp: () -> Void

    @State private var claiming = false
    @State private var lifted = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            VStack(spacing: 14) {
                metric(icon: "sparkles", text: "+\(ExGFormat.xp(summary.xp)) XP gagnés")
                    .opacity(lifted ? 0 : 1)
                    .offset(y: lifted ? -SubjFlashcardReviewMetrics.summaryLift : 0)
                metric(icon: "timer", text: "\(ExGFormat.duration(summary.seconds)) au total")
                metric(icon: "graduationcap", text: "\(summary.chapterMastery)% du cours maîtrisé")
            }
            Spacer(minLength: 0)
            Button(action: claimXp) {
                Text(claiming ? SubjFlashcardReviewCopy.claimedXp : SubjFlashcardReviewCopy.claimXp)
                    .frame(maxWidth: .infinity, minHeight: 54)
            }
            .buttonStyle(DuelloPrimaryButton())
            .disabled(claiming)
        }
        .padding(.horizontal, 22)
        .padding(.top, 42)
        .padding(.bottom, 22)
    }

    /// Une ligne de métrique : icône de 16 pt et valeur en 15 pt (`revision`).
    private func metric(icon: String, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(Theme.ink)
            Text(text)
                .font(.system(size: 15))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
        }
    }

    /// Collecte animée des XP : un seul déclenchement, puis fermeture du bilan.
    private func claimXp() {
        guard !claiming else { return }
        claiming = true
        withAnimation(.easeInOut(duration: SubjFlashcardReviewMetrics.summaryFlightDuration)) {
            lifted = true
        }
        let delay = SubjFlashcardReviewMetrics.summaryFlightDuration
            + SubjFlashcardReviewMetrics.summaryHold
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            onClaimXp()
        }
    }
}
