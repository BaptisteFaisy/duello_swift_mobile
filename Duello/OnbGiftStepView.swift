//
//  OnbGiftStepView.swift
//  Duello
//
//  LOT K — extras d’onboarding : l’étape « cadeau Premium ».
//
//  Fichier source Expo porté : `src/components/OnboardingPremiumGiftStep.tsx`
//  (`OnboardingPremiumGiftStep`, `useGiftOpenProgress`, `handleTap`,
//  `premiumGiftMessage`, `CRACK_TAP_COUNT`, `OPEN_SEQUENCE_MS`).
//
//  Le cadeau se fissure en trois taps (secousse à chaque tap), puis la
//  célébration se joue en 1,5 s sur `Easing.bezier(0.4, 0, 0.2, 1)`. Reanimated
//  n’existe pas côté Swift : un unique `TimelineView` sert d’horloge — il
//  fournit la progression maîtresse et le temps écoulé qui pilote les boucles
//  continues de la scène (`OnbGiftTimeline`), au lieu de `SharedValue`.
//
//  ⚠️ Deux écarts assumés, documentés :
//   - la source s’appuie sur le fond noir de l’écran d’onboarding
//     (`usesDarkOnboardingAppearance = true`) ; la vue porte donc son propre
//     fond noir, et borne l’explosion (`clipShape`) là où la source laisse les
//     débris dépasser de la scène ;
//   - le message « Tu as en cadeau N jours Premium offerts ! » n’est, comme
//     dans la source, qu’un libellé d’accessibilité : la source ne l’affiche
//     nulle part (les fenêtres `T_MESSAGE_*` de la timeline restent inutilisées).
//
//  Cible : iOS 16.
//
import Foundation
import SwiftUI

/// Étape « cadeau Premium » : le cadeau se fissure, puis s’ouvre en fanfare.
struct OnbGiftStepView: View {
    /// Vrai une fois le cadeau ouvert : la séquence se joue et se fige.
    let opened: Bool
    /// Ouverture déclenchée par le troisième tap.
    let onOpened: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var crackStage = 0
    @State private var tapShake: CGFloat = 0
    @State private var startedAt = Date()
    @State private var openStartedAt: Date?

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { context in
            let elapsed = reduceMotion ? 0 : context.date.timeIntervalSince(startedAt)
            return stage(elapsed: elapsed, progress: progress(at: context.date))
        }
        .frame(maxWidth: .infinity)
        .frame(height: Self.panelHeight)
        .background(Color.black)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLarge))
        .onAppear { startedAt = Date() }
        .onChange(of: opened) { isOpen in
            if isOpen {
                openStartedAt = Date()
            } else {
                openStartedAt = nil
                crackStage = 0
            }
        }
    }

    /// La scène : le cadeau (et ses couches) sous la main tant qu’il est fermé,
    /// le tout secoué par le tap. Le fond noir de la source est porté par la vue.
    private func stage(elapsed: Double, progress: Double) -> some View {
        ZStack {
            OnbGiftTimeline(progress: progress, crackStage: crackStage, elapsed: elapsed)
            if !opened {
                OnbGiftPressHand(elapsed: elapsed)
            }
        }
        .frame(width: OnbGiftTimeline.stageWidth, height: OnbGiftTimeline.stageHeight)
        .offset(x: tapShake)
        .contentShape(RoundedRectangle(cornerRadius: 32))
        .onTapGesture { handleTap() }
        .allowsHitTesting(!opened)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(opened ? message : Self.crackHint)
        .accessibilityAddTraits(.isButton)
    }

    /// `handleTap` : chaque tap fissure un peu plus ; le troisième ouvre.
    private func handleTap() {
        guard !opened else { return }
        crackStage = min(crackStage + 1, OnbGiftTimeline.crackTapCount)
        triggerTapShake()
        if crackStage >= OnbGiftTimeline.crackTapCount {
            onOpened()
        }
    }

    /// Secousse du tap : `withSequence(-6, +6, -3, 0)` aux durées de la source.
    private func triggerTapShake() {
        guard !reduceMotion else { return }
        let steps: [(CGFloat, Double)] = [(-6, 0.04), (6, 0.06), (-3, 0.05), (0, 0.04)]
        var delay = 0.0
        for step in steps {
            delay += step.1
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.linear(duration: step.1)) { tapShake = step.0 }
            }
        }
    }

    /// `useGiftOpenProgress` : `withTiming(1, 1500 ms, bezier(0.4, 0, 0.2, 1))`,
    /// ou l’état final immédiat quand le mouvement est réduit.
    private func progress(at date: Date) -> Double {
        guard opened, let start = openStartedAt else { return 0 }
        if reduceMotion { return 1 }
        let raw = date.timeIntervalSince(start) / OnbGiftTimeline.openSequenceSeconds
        return OnbGiftEasing.standard(raw)
    }

    /// `premiumGiftMessage` : l’offre annoncée, mot pour mot.
    private var message: String {
        "Tu as en cadeau \(PremOfferCatalog.trialDays) jours Premium offerts !"
    }

    private static let crackHint = "Fissurer le cadeau pour révéler les jours Premium offerts"
    private static let panelHeight: CGFloat = 340
}
