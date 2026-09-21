//
//  OnbGiftEffects.swift
//  Duello
//
//  LOT K — extras d’onboarding : l’anneau d’étincelles du cadeau Premium.
//
//  Fichier source Expo porté : `src/components/OnboardingPremiumGiftEffects.tsx`
//  (`GiftEffects`, `OrbitSparkle`, `useOrbitStyle` et les constantes
//  `ORBIT_SPARKLE_COUNT`, `ORBIT_PERIOD_MS`, `ORBIT_RADIUS`).
//
//  Six étincelles losanges tournent lentement autour du cadeau (un tour complet
//  en 16 s) en scintillant chacune à son propre décalage, puis le voile
//  s’efface à la détonation. La rotation et le scintillement sont dérivés de
//  `elapsed` à chaque image (voir `OnbGiftStepView`) ; le voile, de `progress`.
//
//  Cible : iOS 16.
//
import Foundation
import SwiftUI

// Constantes de l’orbite, à l’échelle du fichier comme dans la source
// (`ORBIT_SPARKLE_COUNT`, `ORBIT_PERIOD_MS`, `ORBIT_RADIUS`).
private let onbGiftOrbitSparkleCount = 6
private let onbGiftOrbitPeriod = 16.0
private let onbGiftOrbitRadius = 98.0

/// `GiftEffects` : anneau d’étincelles en orbite, voilé à la détonation.
struct OnbGiftEffects: View {
    let progress: Double
    let elapsed: Double

    var body: some View {
        let orbit = elapsed.truncatingRemainder(dividingBy: onbGiftOrbitPeriod)
            / onbGiftOrbitPeriod * 360
        let veil = OnbGiftTimeline.interpolate(
            progress,
            [0, OnbGiftTimeline.tDetonation + 0.09],
            [1, 0])

        return ZStack {
            ForEach(0..<onbGiftOrbitSparkleCount, id: \.self) { index in
                OnbGiftOrbitSparkle(index: index, elapsed: elapsed)
            }
        }
        .frame(width: OnbGiftTimeline.stageWidth, height: OnbGiftTimeline.stageHeight)
        .rotationEffect(.degrees(orbit))
        .opacity(veil)
        .accessibilityHidden(true)
    }
}

/// `OrbitSparkle` : étincelle losange en orbite, scintillant en décalé.
private struct OnbGiftOrbitSparkle: View {
    let index: Int
    let elapsed: Double

    var body: some View {
        let angle = (Double(index) / Double(onbGiftOrbitSparkleCount)) * .pi * 2 + 0.4
        let radius = onbGiftOrbitRadius + OnbGiftTimeline.seededUnit(Double(index + 3)) * 14
        let size = 6 + OnbGiftTimeline.seededUnit(Double(index + 11)) * 4
        let delay = (OnbGiftTimeline.seededUnit(Double(index + 7)) * 1500).rounded() / 1000
        let twinkle = twinkleValue(delay: delay)
        let opacity = OnbGiftTimeline.interpolate(twinkle, [0, 0.5, 1], [0.15, 1, 0.15])
        let colors = OnbGiftTimeline.sparkleColors

        return RoundedRectangle(cornerRadius: 2)
            .fill(colors[index % colors.count])
            .frame(width: CGFloat(size), height: CGFloat(size))
            .rotationEffect(.degrees(45))
            .scaleEffect(CGFloat(0.55 + twinkle * 0.65))
            .offset(x: CGFloat(cos(angle) * radius), y: CGFloat(sin(angle) * radius))
            .opacity(opacity)
    }

    /// `withDelay(seed, withRepeat(withSequence(1 sur 780 ms, 0 sur 780 ms)))` :
    /// un cycle de 1,56 s, décalé du retard tiré au montage.
    private func twinkleValue(delay: Double) -> Double {
        let cycle = 1.56
        let local = elapsed - delay
        guard local > 0 else { return 0 }
        let phase = local.truncatingRemainder(dividingBy: cycle)
        return phase < 0.78
            ? OnbGiftEasing.quadInOut(phase / 0.78)
            : 1 - OnbGiftEasing.quadInOut((phase - 0.78) / 0.78)
    }
}
