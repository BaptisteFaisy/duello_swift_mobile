//
//  ChartXpGainProgress.swift
//  Duello
//
//  Bilan animé des gains d'XP (lot D « Graphiques », préfixe `Chart`).
//
//  Fichier source Expo porté (libellés repris mot pour mot) :
//    - src/components/XpGainProgress.tsx (`XpGainProgress`, `useAnimatedXpTotal`)
//
//  Le total s'anime du total enregistré du compte au total après la session
//  (1 800 ms après un délai de 350 ms), en respectant « Réduire les animations ».
//  La courbe de niveaux est celle d'`ExGXp` (`ExGXpFoundation.swift`). Cible iOS 16.
//
import SwiftUI

/// `XpGainProgress` de `src/components/XpGainProgress.tsx` : anime tous les gains
/// du bilan à partir du total enregistré du compte.
struct ChartXpGainProgress: View {
    let progress: ChartXpProgressSnapshot

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animatedTotal: Double = 0

    private var level: ExGXpLevel { ExGXp.describe(animatedTotal) }
    private var finalLevel: ExGXpLevel { ExGXp.describe(progress.totalAfter) }
    private var levelUp: Bool { level.level > ExGXp.describe(progress.totalBefore).level }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            heading
            counterLine
            track
            footer
        }
        .task { await runAnimation() }
    }

    private var heading: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: Theme.radiusMedium)
                    .fill(levelUp ? Theme.progressLight : Theme.surfaceMuted)
                    .frame(width: 44, height: 44)
                Image(systemName: "star.fill")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(levelUp ? Theme.gradingPerfectHex.color : Theme.ink)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(levelUp ? "NOUVEAU NIVEAU !" : "TON NIVEAU ACTUEL")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(Theme.inkSoft)
                Text("Niveau \(level.level)")
                    .font(.system(size: 24, weight: .heavy))
                    .tracking(-0.6)
                    .foregroundStyle(Theme.ink)
            }
            Spacer(minLength: 0)
        }
        .padding(.bottom, 4)
    }

    private var counterLine: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text(ExGFormat.xp(level.intoLevel))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.ink)
                Text(" / \(ExGFormat.xp(level.levelSpan)) XP")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.inkSoft)
            }
            Spacer(minLength: 8)
            Text(level.isMaxLevel ? "Maximum" : "Niv. \(level.level + 1)")
                .font(.system(size: 11))
                .foregroundStyle(Theme.inkSoft)
        }
    }

    private var track: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.surfaceMuted)
                Capsule()
                    .fill(exgMastery)
                    .frame(width: geo.size.width * min(max(level.progress, 0), 1))
            }
        }
        .frame(height: 18)
        .accessibilityElement()
        .accessibilityLabel("Progression XP")
        .accessibilityValue("Niveau \(finalLevel.level), \(ExGFormat.xp(progress.totalAfter)) XP au total")
    }

    private var footer: some View {
        Text(footerText)
            .font(.system(size: 11))
            .foregroundStyle(Theme.inkSoft)
    }

    private var footerText: String {
        let head = level.isMaxLevel
            ? "Niveau maximum atteint"
            : "\(ExGFormat.xp(level.toNextLevel.rounded(.up))) XP avant le niveau \(level.level + 1)"
        return "\(head) · \(ExGFormat.xp(animatedTotal)) XP au total"
    }

    /// Anime le total, puis fixe la valeur finale (compte montant linéaire).
    private func runAnimation() async {
        animatedTotal = progress.totalBefore
        guard !reduceMotion else {
            animatedTotal = progress.totalAfter
            return
        }
        try? await Task.sleep(nanoseconds: 350_000_000)
        let steps = 60
        for step in 1...steps {
            let fraction = Double(step) / Double(steps)
            animatedTotal = progress.totalBefore
                + (progress.totalAfter - progress.totalBefore) * fraction
            try? await Task.sleep(nanoseconds: UInt64(1_800_000_000 / steps))
        }
        animatedTotal = progress.totalAfter
    }
}
