//
//  OnbGiftHand.swift
//  Duello
//
//  LOT K — extras d’onboarding : la main qui invite à toucher le cadeau.
//
//  Fichier source Expo porté : `src/components/OnboardingPremiumGiftHand.tsx`
//  (`GiftPressHand` et les constantes `HAND_SIZE`, `PRESS_DISTANCE`,
//  `PRESS_DURATION_MS`, `PRESS_HOLD_MS`, `REST_DURATION_MS`, `OUTLINE`).
//
//  La main de la source est un SVG de trois rectangles arrondis (viewBox
//  32 × 32, rendu à 52 pt) qui appuie sur le cadeau tant qu’il n’est pas
//  ouvert : descente de 16 pt, appui tenu 180 ms, remontée, repos 650 ms. Les
//  rectangles sont redessinés ici en `RoundedRectangle` SwiftUI, aux mêmes
//  coordonnées ; la séquence est dérivée de `elapsed` à chaque image.
//
//  Cible : iOS 16.
//
import Foundation
import SwiftUI

/// `GiftPressHand` : main blanche qui appuie sur le cadeau fermé.
struct OnbGiftPressHand: View {
    /// Secondes écoulées depuis l’apparition du cadeau.
    let elapsed: Double

    var body: some View {
        let press = pressValue

        return hand
            .scaleEffect(CGFloat(1 - press * 0.08))
            .offset(y: CGFloat((press - 1) * Self.pressDistance))
            .accessibilityHidden(true)
    }

    /// La main : pouce dressé, paume, doigt replié — viewBox `0 0 32 32`.
    private var hand: some View {
        ZStack {
            finger(x: 12.5, y: 2, width: 7, height: 20, radius: 3.5)
            finger(x: 7, y: 16, width: 18, height: 13, radius: 6)
            finger(x: 21.5, y: 20, width: 7.5, height: 6, radius: 3)
        }
        .frame(width: Self.handSize, height: Self.handSize)
    }

    /// Un rectangle arrondi du SVG, ramené au centre du carré de 52 pt.
    private func finger(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat, radius: CGFloat) -> some View {
        let scale = Self.handSize / 32
        return RoundedRectangle(cornerRadius: radius * scale)
            .fill(OnbGiftTimeline.giftWhite)
            .overlay(
                RoundedRectangle(cornerRadius: radius * scale)
                    .stroke(Theme.ink, lineWidth: 1.6 * scale)
            )
            .frame(width: width * scale, height: height * scale)
            .offset(
                x: (x + width / 2) * scale - Self.handSize / 2,
                y: (y + height / 2) * scale - Self.handSize / 2)
    }

    /// `withRepeat(withSequence(descendre 480 ms, tenir 180 ms, remonter
    /// 480 ms, repos 650 ms))` : cycle de 1,79 s.
    private var pressValue: Double {
        let phase = elapsed.truncatingRemainder(dividingBy: Self.cycle)
        if phase < 0.48 { return OnbGiftEasing.quadInOut(phase / 0.48) }
        if phase < 0.66 { return 1 }
        if phase < 1.14 { return 1 - OnbGiftEasing.quadInOut((phase - 0.66) / 0.48) }
        return 0
    }

    private static let handSize: CGFloat = 52
    private static let pressDistance: Double = 16
    private static let cycle = 1.79
}
