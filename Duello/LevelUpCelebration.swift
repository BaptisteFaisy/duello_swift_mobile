//
//  LevelUpCelebration.swift
//  Duello
//
//  Célébration plein écran d'un franchissement de niveau — unité U5.
//
//  Fichier source Expo porté (libellés et minutages repris mot pour mot) :
//    - src/components/LevelUpCelebration.tsx
//        `LevelUpCelebrationCoordinator`, `useCelebrationProgress`,
//        `useCelebrationDismissal`, `useCelebrationContainerStyles`,
//        `useCelebrationArtworkStyles`, `LevelUpCelebration`.
//
//  `react-native-reanimated` n'existe pas côté SwiftUI : la valeur partagée
//  `progress` (révélation 0 → 0.5 en 680 ms `cubicOut`, sortie 0.5 → 1 en 200 ms
//  `cubicIn`, figée à 0.5 quand « réduire les animations ») est recalculée à
//  chaque image par `TimelineView(.animation)`, comme `LeaguePromotionCelebration`.
//  Les interpolations reprennent `LeagueAnimation.interpolate` (mêmes formules que
//  la source). La vue couvre tout l'écran ; l'appelant la présente en superposition
//  (`.overlay` / `.fullScreenCover`), à la place du `Modal` transparent
//  `overFullScreen` de la source.
//
//  La carte et les étincelles vivent dans `LevelUpCelebrationCard.swift`.
//
//  Cible : iOS 16, SwiftUI + Foundation ; aucune API iOS 17.
//
import Foundation
import SwiftUI

/// `LevelUpCelebrationCoordinator` : affiche successivement les paliers franchis.
struct LevelUpCelebrationCoordinator: View {
    @ObservedObject var queue: LevelUpQueue

    var body: some View {
        if let level = queue.level {
            LevelUpCelebration(level: level, onFinished: queue.finishCurrent)
                .id(level)   // `key={level}` : remonte l'animation à chaque palier
        }
    }
}

/// `LevelUpCelebration` : voile sombre, étincelles et carte ; fermeture au
/// toucher de l'écran.
struct LevelUpCelebration: View {
    let level: Int
    let onFinished: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var startedAt = Date()
    @State private var dismissedAt: Date?
    @State private var closing = false

    /// `CELEBRATION_REVEAL_DURATION_MS`, `CELEBRATION_DISMISS_DURATION_MS`,
    /// `STATIC_PROGRESS`, en secondes / unité de progression.
    private let revealDuration: Double = 0.68
    private let dismissDuration: Double = 0.2
    private let staticProgress: Double = 0.5

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                dismissLayer
                TimelineView(.animation(paused: reduceMotion)) { context in
                    let animation = LevelUpCelebrationAnimation(
                        progress: progress(at: context.date)
                    )
                    ZStack {
                        Color(hex: 0x030504)
                            .opacity(0.92 * animation.backdropOpacity)
                            .ignoresSafeArea()
                        LevelUpSparkles(animation: animation)
                        LevelUpCelebrationCard(level: level, animation: animation)
                            .padding(.horizontal, 24)
                            .padding(.top, max(proxy.safeAreaInsets.top, 32))
                            .padding(.bottom, max(proxy.safeAreaInsets.bottom, 32))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                // Les taps traversent le contenu animé jusqu'à `dismissLayer`.
                .allowsHitTesting(false)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear { startedAt = Date() }
    }

    /// Zone de fermeture : tout l'écran, sous le contenu animé. Porte le libellé
    /// d'accessibilité du `Pressable` de la source.
    private var dismissLayer: some View {
        Button(action: dismiss) {
            Color.clear.contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .ignoresSafeArea()
        .accessibilityAddTraits(.isModal)
        .accessibilityLabel(
            "Niveau supérieur. Bravo, tu passes au niveau \(level). Toucher pour continuer."
        )
    }

    /// `progress` : révélation puis sortie, ou état figé si mouvement réduit.
    private func progress(at date: Date) -> Double {
        if reduceMotion { return staticProgress }
        if let dismissedAt {
            let elapsed = date.timeIntervalSince(dismissedAt)
            return staticProgress
                + staticProgress * LeagueAnimation.cubicIn(elapsed / dismissDuration)
        }
        let elapsed = date.timeIntervalSince(startedAt)
        return staticProgress * LeagueAnimation.cubicOut(elapsed / revealDuration)
    }

    /// `dismiss` : ferme une seule fois, puis rappelle l'appelant.
    private func dismiss() {
        guard !closing else { return }
        closing = true
        if reduceMotion {
            onFinished()
            return
        }
        dismissedAt = Date()
        DispatchQueue.main.asyncAfter(deadline: .now() + dismissDuration) {
            onFinished()
        }
    }
}

/// Styles animés d'une montée de niveau, dérivés de `progress ∈ [0, 1]` où 0.5
/// est l'état pleinement révélé (`STATIC_PROGRESS`). Reprend
/// `useCelebrationContainerStyles` et `useCelebrationArtworkStyles`.
struct LevelUpCelebrationAnimation {
    let progress: Double

    /// `backdropStyle.opacity` (voile `rgba(3, 5, 4, 0.92)`).
    var backdropOpacity: Double {
        LeagueAnimation.interpolate(progress, [0, 0.1, 0.5, 1], [0, 1, 1, 0], clamped: true)
    }

    /// `cardStyle.opacity`.
    var cardOpacity: Double {
        LeagueAnimation.interpolate(progress, [0, 0.1, 0.5, 1], [0, 1, 1, 0])
    }

    /// `cardStyle.transform.scale`.
    var cardScale: Double {
        LeagueAnimation.interpolate(
            progress, [0, 0.14, 0.24, 0.5, 1], [0.72, 1.08, 1, 1, 0.96], clamped: true
        )
    }

    /// `cardStyle.transform.translateY`.
    var cardOffsetY: Double {
        LeagueAnimation.interpolate(progress, [0, 0.24, 0.5, 1], [26, 0, 0, -8])
    }

    /// `burstStyle.opacity` (étincelles).
    var burstOpacity: Double {
        LeagueAnimation.interpolate(progress, [0, 0.12, 0.5, 1], [0, 1, 0.82, 0])
    }

    /// `burstStyle.transform.scale`.
    var burstScale: Double {
        LeagueAnimation.interpolate(progress, [0, 0.3, 0.5, 1], [0.45, 1, 1, 1.28])
    }

    /// `burstStyle.transform.rotate`, en degrés.
    var burstRotation: Double {
        LeagueAnimation.interpolate(progress, [0, 1], [-10, 12])
    }

    /// `badgeStyle.transform.scale` (pastille du niveau).
    var badgeScale: Double {
        LeagueAnimation.interpolate(
            progress, [0, 0.17, 0.28, 0.5, 1], [0.4, 1.16, 1, 1, 1], clamped: true
        )
    }
}
