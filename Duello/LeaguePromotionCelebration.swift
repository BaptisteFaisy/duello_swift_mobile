//
//  LeaguePromotionCelebration.swift
//  Duello
//
//  Célébration bloquante d'un vrai franchissement de ligue
//  (`EloLeaguePromotionCelebration.tsx`).
//
//  Fichiers source Expo portés (libellés et minutages repris mot pour mot) :
//    - src/components/EloLeaguePromotionCelebration.tsx
//    - src/hooks/useEloLeaguePromotionLifecycle.ts
//    - src/hooks/useEloLeaguePromotionStyles.ts
//
//  `useEloLeaguePromotionLifecycle` (révélation 680 ms `cubicOut`, sortie
//  180 ms `cubicIn`, chemin sans mouvement si « réduire les animations ») et
//  `useEloLeaguePromotionStyles` sont transposés : la progression est
//  recalculée à chaque image par `TimelineView(.animation)`, comme dans
//  `ExGPerfectCelebration.swift`. Le voile couvre tout l'écran ; l'appelant
//  présente la vue en superposition (`.overlay` ou `.fullScreenCover`).
//  Les marges de sécurité reprennent `Math.max(inset, 24)` de la source.
//
//  Cible : iOS 16, aucune API iOS 17.
//
import Foundation
import SwiftUI

/// Célébration ponctuelle : voile sombre, carte de promotion, fermeture au
/// toucher du fond ou du bouton « Continuer ».
struct LeaguePromotionCelebration: View {
    let promotion: LeaguePromotion
    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var startedAt = Date()
    @State private var dismissedAt: Date?
    @State private var closing = false

    /// `REVEAL_DURATION_MS` et `EXIT_DURATION_MS`, en secondes.
    private let revealDuration: Double = 0.68
    private let exitDuration: Double = 0.18

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                // Hors de la `TimelineView` : la zone de fermeture n'est plus
                // reconstruite à chaque image. Elle reste sous le voile et la
                // carte (l'ordre d'affichage est inchangé).
                dismissLayer
                TimelineView(.animation(paused: reduceMotion)) { context in
                    let animation = LeaguePromotionAnimation(progress: progress(at: context.date))
                    ZStack {
                        Color(hex: 0x0A0D0C)
                            .opacity(0.62 * animation.backdropOpacity)
                            .ignoresSafeArea()
                            // Le voile passe devant `dismissLayer` : il ne doit
                            // pas intercepter les taps de fermeture du fond.
                            .allowsHitTesting(false)
                        LeaguePromotionCard(
                            promotion: promotion,
                            animation: animation,
                            onDismiss: dismiss
                        )
                        .padding(.horizontal, 20)
                        .padding(.top, max(proxy.safeAreaInsets.top, 24))
                        .padding(.bottom, max(proxy.safeAreaInsets.bottom, 24))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear { startedAt = Date() }
    }

    /// Zone de fermeture : tout le fond, sous la carte.
    private var dismissLayer: some View {
        Button(action: dismiss) {
            Color.clear
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .ignoresSafeArea()
        .accessibilityLabel("Fermer la célébration")
    }

    /// Progression `p ∈ [0, 1]` : révélation puis sortie, ou état figé quand
    /// « réduire les animations » est actif.
    private func progress(at date: Date) -> Double {
        if reduceMotion { return closing ? 0 : 1 }
        if let dismissedAt {
            let elapsed = date.timeIntervalSince(dismissedAt)
            return max(0, 1 - LeagueAnimation.cubicIn(elapsed / exitDuration))
        }
        let elapsed = date.timeIntervalSince(startedAt)
        return LeagueAnimation.cubicOut(elapsed / revealDuration)
    }

    /// Ferme une seule fois : sortie animée, puis rappel de l'appelant.
    private func dismiss() {
        guard !closing else { return }
        closing = true
        if reduceMotion {
            onDismiss()
            return
        }
        dismissedAt = Date()
        DispatchQueue.main.asyncAfter(deadline: .now() + exitDuration) {
            onDismiss()
        }
    }
}
