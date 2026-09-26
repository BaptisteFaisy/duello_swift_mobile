//
//  OnbGiftBox.swift
//  Duello
//
//  LOT K — extras d’onboarding : le cadeau fermé de la célébration Premium.
//
//  Fichier source Expo porté : `src/components/OnboardingPremiumGiftBox.tsx`
//  (`OnboardingPremiumGiftBox`, `GiftCracks`, `useIdleFloat`,
//  `useBadgeBurstStyle`, `DetonationFlash` et `GIFT_CRACKS`).
//
//  Le cadeau est nu et transparent — ni carré ni halo — : une icône blanche de
//  48 pt, six fissures posées au fil des taps, un flottement lent et un flash
//  blanc net au moment de la détonation. Les transformations sont dérivées à
//  chaque image de `progress` et de `elapsed` (voir `OnbGiftTimeline`), au lieu
//  des `SharedValue` de Reanimated.
//
//  Cible : iOS 16.
//
import Foundation
import SwiftUI

/// Le cadeau fermé : icône flottante, fissures de tap, flash de détonation.
struct OnbGiftBox: View {
    let progress: Double
    let crackStage: Int
    let elapsed: Double

    var body: some View {
        ZStack {
            badge
            flash
        }
        .frame(width: OnbGiftTimeline.stageWidth, height: OnbGiftTimeline.stageHeight)
        .accessibilityHidden(true)
    }

    /// `useBadgeBurstStyle` : anticipation (squash) puis éclatement du badge.
    private var badge: some View {
        let calm = OnbGiftTimeline.interpolate(progress, [0, OnbGiftTimeline.tDetonation], [1, 0])
        let squash = OnbGiftTimeline.interpolate(progress, [0, OnbGiftTimeline.tSquashEnd], [0, 1])
        let burst = OnbGiftTimeline.interpolate(
            progress,
            [OnbGiftTimeline.tSquashEnd, OnbGiftTimeline.tSquashEnd + 0.14],
            [0, 1])
        let opacity = OnbGiftTimeline.interpolate(
            progress,
            [OnbGiftTimeline.tSquashEnd, OnbGiftTimeline.tSquashEnd + 0.15],
            [1, 0])
        let float = idleFloat
        let offsetY = float * 5 * calm + squash * 8 - burst * 12
        let rotation = float * 2.5 * calm - squash * 2 + burst * 12
        let scaleX = 1 + float * 0.015 * calm + squash * 0.16 + burst * 0.4
        let scaleY = 1 - float * 0.02 * calm - squash * 0.18 + burst * 0.4

        return ZStack {
            Image(systemName: "gift")
                .font(.system(size: 48, weight: .regular))
                .foregroundStyle(OnbGiftTimeline.giftWhite)
            OnbGiftCracks(crackStage: crackStage)
        }
        .frame(width: Self.badgeSize, height: Self.badgeSize)
        .scaleEffect(x: CGFloat(scaleX), y: CGFloat(scaleY))
        .rotationEffect(.degrees(rotation))
        .offset(y: CGFloat(offsetY))
        .opacity(opacity)
    }

    /// `DetonationFlash` : flash blanc net de détonation.
    private var flash: some View {
        let opacity = OnbGiftTimeline.interpolate(
            progress,
            [OnbGiftTimeline.tDetonation, OnbGiftTimeline.tFlashPeak, OnbGiftTimeline.tFlashPeak + 0.1],
            [0, 0.95, 0])
        let scale = OnbGiftTimeline.interpolate(
            progress,
            [OnbGiftTimeline.tDetonation, OnbGiftTimeline.tFlashPeak + 0.1],
            [0.4, 1.8])

        return Circle()
            .fill(OnbGiftTimeline.giftWhite.opacity(0.9))
            .frame(width: Self.flashSize, height: Self.flashSize)
            .scaleEffect(CGFloat(scale))
            .opacity(opacity)
    }

    /// `useIdleFloat` : `withRepeat(withTiming(1, 1600 ms, inOut(quad)))`,
    /// aller-retour — soit une période complète de 3,2 s.
    private var idleFloat: Double {
        let period = 3.2
        let phase = elapsed.truncatingRemainder(dividingBy: period)
        let ramp = phase < period / 2 ? phase / (period / 2) : 2 - phase / (period / 2)
        return OnbGiftEasing.quadInOut(ramp)
    }

    private static let badgeSize: CGFloat = 88
    private static let flashSize: CGFloat = 200
}

/// `GiftCracks` : segments posés sur le cadeau, révélés tap après tap.
private struct OnbGiftCracks: View {
    let crackStage: Int

    var body: some View {
        ZStack {
            ForEach(Self.cracks.filter { $0.stage <= crackStage }) { crack in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Theme.ink)
                    .frame(width: 2.5, height: crack.height)
                    .rotationEffect(.degrees(crack.angle))
                    .offset(x: crack.left + 1.25 - 44, y: crack.top + crack.height / 2 - 44)
            }
        }
        .frame(width: 88, height: 88)
    }

    /// `GIFT_CRACKS` : `top` / `left` sont mesurés depuis le coin du badge.
    private struct Crack: Identifiable {
        let id: Int
        let top: CGFloat
        let left: CGFloat
        let height: CGFloat
        let angle: Double
        let stage: Int
    }

    private static let cracks: [Crack] = [
        Crack(id: 0, top: 22, left: 42, height: 26, angle: 14, stage: 1),
        Crack(id: 1, top: 44, left: 24, height: 22, angle: -40, stage: 1),
        Crack(id: 2, top: 16, left: 18, height: 20, angle: 58, stage: 2),
        Crack(id: 3, top: 50, left: 52, height: 22, angle: -16, stage: 2),
        Crack(id: 4, top: 10, left: 56, height: 18, angle: 44, stage: 3),
        Crack(id: 5, top: 56, left: 14, height: 18, angle: -62, stage: 3),
    ]
}
