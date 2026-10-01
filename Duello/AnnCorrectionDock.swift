//
//  AnnCorrectionDock.swift
//  Duello
//
//  Dock d'attente de la correction du lecteur d'annale (P0 18#2) : le sablier et
//  le temps estimé restant, à la place du bouton de soumission pendant la
//  correction d'un exercice ou d'une colle.
//
//  Fichier source Expo porté : src/components/exercise-correction/ExerciseCorrectionDock.tsx
//  (`ExerciseCorrectionDock`), avec `utils/correctionCountdown.ts`.
//
//  Le décompte est porté ici (`AnnDockCountdown`) ; le sablier réutilise le
//  portage fidèle d'`AnimatedHourglass` (`ExGAnimatedHourglass`,
//  `ExGCorrectionCountdownAndBars.swift`), à 26 pt comme la partie 3 de la
//  source — un sablier en boucle propre (vidage 2,6 s, filet 450 ms), sans lien
//  avec le temps restant. Habillage de `styles.correctionDock` : fond `surface`
//  et filet supérieur `border`.
//
//  Cible : iOS 16.
//
import SwiftUI

// MARK: - Décompte de la correction

/// `CorrectionProgress` + `remainingCorrectionSeconds` (`correctionCountdown.ts`).
private struct AnnDockProgress {
    var startedAt: Double
    var total: Int
    var completedAt: [Double]
}

/// Portage direct de `utils/correctionCountdown.ts`.
private enum AnnDockCountdown {
    /// `MAX_CONCURRENT_QUESTION_CORRECTIONS` de `utils/correctionPerformance.ts`.
    static let concurrency = 4

    /// Départs des réponses soumises : la file en lance jusqu'à `concurrency`
    /// dès l'envoi, puis la suivante chaque fois qu'une correction se termine.
    static func inferredStarts(startedAt: Double, total: Int,
                              completedAt: [Double], concurrency: Int) -> [Double] {
        var starts = Array(repeating: startedAt, count: max(0, min(total, concurrency)))
        for finishedAt in completedAt {
            if starts.count >= total { break }
            starts.append(finishedAt)
        }
        return starts
    }

    /// Secondes restantes avant la dernière correction ; zéro signifie que les
    /// corrections encore ouvertes ont dépassé l'estimation.
    static func remainingSeconds(_ progress: AnnDockProgress,
                                 questionSeconds: Double, now: Double,
                                 concurrency: Int = 4) -> Double {
        let starts = inferredStarts(startedAt: progress.startedAt, total: progress.total,
                                    completedAt: progress.completedAt, concurrency: concurrency)
        let questionMs = questionSeconds * 1000
        var slots = starts.dropFirst(progress.completedAt.count).map { max(0, $0 + questionMs - now) }
        while slots.count < concurrency { slots.append(0) }

        var waiting = progress.total - starts.count
        while waiting > 0 {
            guard let earliest = slots.indices.min(by: { slots[$0] < slots[$1] }) else { break }
            slots[earliest] += questionMs
            waiting -= 1
        }
        return (slots.max() ?? 0) / 1000
    }
}

// MARK: - Dock

/// `ExerciseCorrectionDock` : le sablier seul et le temps estimé restant, sur une
/// ligne centrée, à la place du bouton de soumission pendant la correction.
struct AnnCorrectionDock: View {
    let correction: ExGCorrection

    @State private var completedAt: [Double] = []

    var body: some View {
        TimelineView(.periodic(from: Date(), by: 1)) { context in
            let observed = AnnDockProgress(
                startedAt: correction.startedAt,
                total: correction.total,
                completedAt: completedAt
            )
            let now = ExGFormat.milliseconds(context.date)
            // `Math.ceil(useCorrectionCountdown(correction))` : arrondi à la
            // seconde supérieure, comme la valeur affichée.
            let seconds = AnnDockCountdown.remainingSeconds(
                observed,
                questionSeconds: correction.questionSeconds,
                now: now
            ).rounded(.up)
            let remaining = seconds > 0 ? ExGFormat.duration(seconds) : "quelques instants"
            HStack(spacing: 8) {
                ExGAnimatedHourglass(size: 26)
                Text(remaining)
                    .font(.system(size: 20, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(Theme.ink)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            // `styles.correctionDock` : fond `surface` + filet supérieur `border`,
            // pour que le dock se détache de la copie sur `background`.
            .background(Theme.surface)
            .overlay(alignment: .top) {
                Rectangle().fill(Theme.border).frame(height: 1)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Correction complète dans \(seconds > 0 ? "environ \(remaining)" : remaining)")
        }
        .onAppear { syncCompleted() }
        .onChange(of: correction.done) { _ in syncCompleted() }
    }

    /// Chaque réponse terminée est datée pour replanifier la file.
    private func syncCompleted() {
        guard completedAt.count < correction.done else { return }
        let now = ExGFormat.milliseconds(Date())
        completedAt.append(contentsOf: Array(repeating: now,
                                            count: correction.done - completedAt.count))
    }
}
