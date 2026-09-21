//
//  ExGSuccessSummary.swift
//  Duello
//
//  Bilan de fin d'exercice — point d'entrée public (`SuccessSummary.tsx`) et
//  bilan de révision (`RevisionSuccessSummary.tsx`).
//
//  Le correcteur de copies reste celui de l'app : `DuelloAPI.gradeCopyWithAi(…)`
//  rend un `ProductionAssessment` (note sur 100 + commentaire), exposé ici par
//  `ExGSuccessSummary(assessment:expectedAnswer:)` sous le libellé « Compte
//  rendu » / « Correction ».
//
//  Fichiers source Expo portés (libellés repris mot pour mot) :
//    - src/components/SuccessSummary.tsx                (aiguillage du bilan)
//    - src/components/RevisionSuccessSummary.tsx        (bilan de révision)
//
//  Découpé de `ExerciseGradingViews.swift` (1 975 lignes) le 2026-09-21 : contenu
//  repris ligne pour ligne — aucun type, propriété, méthode ni signature renommé.
//  Spécification de référence : specs/exws_C.md (§0 socle commun, §1 à §5
//  composants, §6 récapitulatif animations, §7 dépendances non portables).
//  Cible : iOS 16, aucune API iOS 17.
//
import Foundation
import SwiftUI

// MARK: - §4 — Bilan de révision et §Correction — point d'entrée

/// Une mesure du bilan de révision (`RevisionMetric`).
private struct ExGRevisionMetric: View {
    let icon: String
    let revision: Bool
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: revision ? 16 : 22, weight: .semibold))
                .foregroundStyle(revision ? Theme.ink : Theme.primary)
            Text(text)
                .font(.system(size: revision ? 15 : 20, weight: revision ? .regular : .bold))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

/// Bilan de fin d'exercice : correction détaillée, ou célébration de la
/// révision.
///
/// Une seule entrée publique, comme `SuccessSummary.tsx` : quand `correction`
/// est fourni, c'est le bilan de correction (appréciation, note, XP, rang,
/// verdict par question, correction attendue, relance) ; sinon, c'est le bilan
/// de révision (`RevisionSuccessSummary`) — mesures, collecte des XP, reprise.
/// `perfect` superpose la célébration de l'exercice parfaitement réussi.
struct ExGSuccessSummary: View {
    // Aligné sur `SuccessSummaryProps` de `SuccessSummary.types.ts`.
    var title: String? = nil
    var xp: Double = 0
    var exerciseBonus: ExGBonusReceipt? = nil
    var bonusStatus: ExGBonusStatus.Kind? = nil
    var onRetryBonus: (() -> Void)? = nil
    var scoreOn20: Double? = nil
    var scoreComplete: Bool = true
    var exerciseRank: Int? = nil
    var seconds: Int = 0
    var chapterMastery: Int? = nil
    var revision: Bool = false
    /// Bilan de correction : progression et questions corrigées.
    var correction: ExGCorrection? = nil
    /// Note sur 100 et commentaire du correcteur
    /// (`DuelloAPI.gradeCopyWithAi(…)` → `ProductionAssessment`).
    var assessment: ProductionAssessment? = nil
    /// Corrigé attendu, affiché en serif sous le compte rendu.
    var expectedAnswer: String? = nil
    var onClaimXp: () -> Void = {}
    var onRetry: (() -> Void)? = nil
    var onResume: (() -> Void)? = nil
    var onQuit: (() -> Void)? = nil
    var onOpenQuestionReport: ((String) -> Void)? = nil
    var onReport: (() -> Void)? = nil
    var trophy: ExGTrophy? = nil
    /// Exercice parfaitement réussi : lance la célébration.
    var perfect: Bool = false

    @State private var claiming = false
    @State private var xpOffset: CGFloat = 0
    @State private var xpOpacity: Double = 1

    /// Note sur 20 du bilan : celle fournie par l'écran, ou celle déduite de la
    /// note sur 100 du correcteur (`DuelloAPI.gradeCopyWithAi(…)` →
    /// `ProductionAssessment`, ramenée sur 20 et arrondie au dixième).
    private var displayedScoreOn20: Double? {
        if let scoreOn20 { return scoreOn20 }
        guard let assessment else { return nil }
        return ExGGrading.roundScore(Double(assessment.score) / 5)
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            if let correction {
                correctionLayout(correction)
            } else {
                revisionLayout
            }
        }
        .overlay(alignment: .top) {
            if perfect {
                ExGPerfectCelebration(active: true)
                    .padding(.top, 18)
            }
        }
    }

    // MARK: Bilan de correction

    @ViewBuilder
    private func correctionLayout(_ correction: ExGCorrection) -> some View {
        VStack(spacing: 0) {
            ExGCorrectionTopBar(
                correction: correction,
                trophy: trophy,
                onResume: onResume,
                onReport: onReport
            )

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 28) {
                    if let title, !title.isEmpty {
                        Text(title)
                            .font(.system(size: 17, weight: .heavy))
                            .foregroundStyle(Theme.ink)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .frame(maxWidth: .infinity)
                    }

                    if correction.completed {
                        ExGCorrectionOverview(
                            correction: correction,
                            scoreOn20: displayedScoreOn20,
                            xp: xp,
                            exerciseRank: exerciseRank
                        )
                    }

                    if !correction.questions.isEmpty {
                        ExGCorrectionQuestionList(
                            correction: correction,
                            onOpenQuestionReport: onOpenQuestionReport
                        )
                    }

                    if assessment != nil || expectedAnswer != nil {
                        ExGAssessmentCard(assessment: assessment, expectedAnswer: expectedAnswer)
                    }
                }
                .frame(maxWidth: 880, alignment: .leading)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 28)
            }

            if correction.completed {
                ExGCorrectionActions(onResume: onResume, onRetry: onRetry, onQuit: onQuit)
            }
        }
    }

    // MARK: Bilan de révision

    private var revisionLayout: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 20) {
                if let title, !title.isEmpty {
                    Text(title)
                        .font(.system(size: revision ? 15 : 28,
                                      weight: revision ? .regular : .bold))
                        .foregroundStyle(Theme.ink)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }

                VStack(spacing: 14) {
                    if let scoreOn20 {
                        ExGRevisionMetric(
                            icon: "graduationcap",
                            revision: revision,
                            text: ExGFormat.score(scoreOn20)
                                + (scoreComplete ? "" : "\u{00A0}· provisoire")
                        )
                    }

                    xpSection

                    ExGRevisionMetric(
                        icon: "timer",
                        revision: revision,
                        text: "\(ExGFormat.duration(Double(seconds))) au total"
                    )

                    if revision, let chapterMastery {
                        ExGRevisionMetric(
                            icon: "graduationcap",
                            revision: revision,
                            text: "\(chapterMastery)% du cours maîtrisé"
                        )
                    }
                }
                .frame(maxWidth: .infinity)

                claimButton

                if let onRetry {
                    retryButton(onRetry)
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, revision ? 42 : 28)
            .padding(.bottom, revision ? 22 : 28)
            .frame(maxWidth: .infinity)
        }
    }

    private var xpSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: revision ? 16 : 22, weight: .semibold))
                    .foregroundStyle(revision ? Theme.ink : exgGoogleBlue)
                Text("+\(ExGFormat.xp(xp)) XP gagnés")
                    .font(.system(size: revision ? 15 : 20,
                                  weight: revision ? .regular : .bold))
                    .foregroundStyle(revision ? Theme.ink : exgGoogleBlue)
            }
            .frame(maxWidth: .infinity)

            if let exerciseBonus {
                ExGBonusProgress(receipt: exerciseBonus)
            }
            if let bonusStatus {
                ExGBonusStatus(status: bonusStatus, onRetry: onRetryBonus)
            }
        }
        .frame(maxWidth: 560)
        .offset(y: xpOffset)
        .opacity(xpOpacity)
    }

    private var claimButton: some View {
        Button(action: claimXp) {
            Text(claiming ? "XP reçus" : "Recevoir mes XP")
                .frame(maxWidth: .infinity, minHeight: 54)
        }
        .buttonStyle(DuelloPrimaryButton())
        .disabled(claiming)
    }

    private func retryButton(_ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 19, weight: .semibold))
                Text("Recommencer l’exercice")
                    .font(.system(size: 16, weight: .bold))
            }
            .foregroundStyle(Theme.primary)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLarge))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusLarge)
                    .stroke(Theme.primary, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    /// `useRevisionClaim` — hors révision, la collecte est immédiate ; en
    /// révision, la section XP se soulève de 90 pt et s'efface en 1 400 ms,
    /// puis l'appel part après 900 ms de maintien.
    ///
    /// Limite documentée : la source maintient l'opacité à 1 jusqu'à 72 % puis
    /// la fond (`interpolate([0, 0.72, 1] → [1, 1, 0])`) ; ici un seul
    /// `withAnimation` en `easeInOut` approche la séquence sans animation par
    /// images clés (iOS 17).
    private func claimXp() {
        if !revision {
            onClaimXp()
            return
        }
        if claiming { return }
        claiming = true
        withAnimation(.easeInOut(duration: 1.4)) {
            xpOffset = -90
            xpOpacity = 0
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 900_000_000)
            onClaimXp()
        }
    }
}
