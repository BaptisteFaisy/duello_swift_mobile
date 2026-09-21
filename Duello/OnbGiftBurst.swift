//
//  OnbGiftBurst.swift
//  Duello
//
//  LOT K — extras d’onboarding : l’explosion du cadeau Premium.
//
//  Fichier source Expo porté : `src/components/OnboardingPremiumGiftBurst.tsx`
//  (`BurstScene`, `StarburstRays`, `DebrisPiece`, `RibbonStream`, `GlitterDot`,
//  `ConfettiPiece` et leurs comptes `RAY_COUNT`, `DEBRIS_COUNT`, `RIBBON_COUNT`,
//  `GLITTER_COUNT`, `CONFETTI_COUNT`).
//
//  Toutes les couches sont peintes sous l’étiquette des jours, dans l’ordre de
//  la source : rayons en étoile, débris de la boîte, rubans, poussière
//  scintillante, confettis. Chaque pièce est une fonction pure de `progress` :
//  positions et rotations reprennent mot pour mot les formules de la source,
//  `seededUnit` fournissant le même tirage déterministe entre les images.
//
//  Cible : iOS 16.
//
import Foundation
import SwiftUI

// Comptes de chaque couche, à l’échelle du fichier comme les constantes du
// module Expo (`RAY_COUNT`, `DEBRIS_COUNT`, `RIBBON_COUNT`, `GLITTER_COUNT`,
// `CONFETTI_COUNT`).
private let onbGiftRayCount = 12
private let onbGiftDebrisCount = 16
private let onbGiftRibbonCount = 4
private let onbGiftGlitterCount = 10
private let onbGiftConfettiCount = 14

/// Toutes les couches de l’explosion, centrées sur la scène du cadeau.
struct OnbGiftBurstScene: View {
    let progress: Double

    var body: some View {
        ZStack {
            OnbGiftRays(progress: progress)
            ForEach(0..<onbGiftDebrisCount, id: \.self) { index in
                OnbGiftDebrisPiece(progress: progress, index: index)
            }
            ForEach(0..<onbGiftRibbonCount, id: \.self) { index in
                OnbGiftRibbon(progress: progress, index: index)
            }
            ForEach(0..<onbGiftGlitterCount, id: \.self) { index in
                OnbGiftGlitter(progress: progress, index: index)
            }
            ForEach(0..<onbGiftConfettiCount, id: \.self) { index in
                OnbGiftConfetti(progress: progress, index: index)
            }
        }
        .frame(width: OnbGiftTimeline.stageWidth, height: OnbGiftTimeline.stageHeight)
    }
}

/// `StarburstRays` : étoile de douze rayons déployée à la détonation. Le
/// viewport SVG de la source borne le tracé à la scène.
private struct OnbGiftRays: View {
    let progress: Double

    var body: some View {
        let opacity = OnbGiftTimeline.interpolate(
            progress,
            [
                OnbGiftTimeline.tRaysStart,
                OnbGiftTimeline.tRaysStart + 0.05,
                OnbGiftTimeline.tRaysEnd * 0.75,
                OnbGiftTimeline.tRaysEnd,
            ],
            [0, 0.85, 0.45, 0])
        let scale = OnbGiftTimeline.interpolate(
            progress,
            [OnbGiftTimeline.tRaysStart, OnbGiftTimeline.tRaysEnd],
            [0.25, 1.85])
        let rotation = OnbGiftTimeline.interpolate(
            progress,
            [OnbGiftTimeline.tRaysStart, OnbGiftTimeline.tRaysEnd],
            [0, 22])
        let center = CGPoint(
            x: OnbGiftTimeline.stageWidth / 2,
            y: OnbGiftTimeline.stageHeight / 2)

        return ZStack {
            ForEach(0..<onbGiftRayCount, id: \.self) { index in
                OnbGiftTimeline.rayPath(
                    index: index, count: onbGiftRayCount, radius: 118, center: center)
                    .fill(index % 2 == 0 ? OnbGiftTimeline.goldSoft : OnbGiftTimeline.giftWhite)
                    .opacity(index % 3 == 0 ? 0.55 : 0.3)
            }
        }
        .frame(width: OnbGiftTimeline.stageWidth, height: OnbGiftTimeline.stageHeight)
        .scaleEffect(CGFloat(scale))
        .rotationEffect(.degrees(rotation))
        .opacity(opacity)
    }
}

/// `DebrisPiece` : fragment de la boîte — éjection, traînée, gravité, rotation.
private struct OnbGiftDebrisPiece: View {
    let progress: Double
    let index: Int

    var body: some View {
        let angle = (Double(index) / Double(onbGiftDebrisCount)) * .pi * 2
            + OnbGiftTimeline.seededUnit(Double(index)) * 0.55
        let distance = 92 + OnbGiftTimeline.seededUnit(Double(index + 5)) * 68
        let spin = (index % 2 == 0 ? 1.0 : -1.0)
            * (320 + OnbGiftTimeline.seededUnit(Double(index + 9)) * 520)
        let width = 5 + OnbGiftTimeline.seededUnit(Double(index + 13)) * 4
        let height = width * (1.4 + OnbGiftTimeline.seededUnit(Double(index + 17)) * 1.1)
        let flight = OnbGiftTimeline.interpolate(
            progress,
            [
                OnbGiftTimeline.tDebrisStart,
                OnbGiftTimeline.tDebrisStart + 0.1,
                OnbGiftTimeline.tDebrisEnd * 0.72,
                OnbGiftTimeline.tDebrisEnd,
            ],
            [0, 0.52, 0.86, 1])
        let opacity = OnbGiftTimeline.interpolate(
            progress,
            [OnbGiftTimeline.tDebrisStart, OnbGiftTimeline.tDebrisFadeStart, OnbGiftTimeline.tDebrisEnd],
            [1, 0.9, 0])
        let colors = OnbGiftTimeline.debrisColors

        return RoundedRectangle(cornerRadius: index % 4 == 0 ? 3 : 1.5)
            .fill(colors[index % colors.count])
            .frame(width: CGFloat(width), height: CGFloat(height))
            .scaleEffect(CGFloat(1 - flight * 0.45))
            .rotationEffect(.degrees(spin * flight))
            .offset(
                x: CGFloat(cos(angle) * distance * flight),
                y: CGFloat(sin(angle) * distance * flight + 95 * flight * flight))
            .opacity(opacity)
    }
}

/// `RibbonStream` : ruban lancé en arc, puis chute ondulante.
private struct OnbGiftRibbon: View {
    let progress: Double
    let index: Int

    var body: some View {
        let direction = index % 2 == 0 ? -1.0 : 1.0
        let launchX = direction * (54 + OnbGiftTimeline.seededUnit(Double(index + 21)) * 46)
        let phase = OnbGiftTimeline.seededUnit(Double(index + 31)) * .pi * 2
        let time = OnbGiftTimeline.interpolate(
            progress,
            [OnbGiftTimeline.tRibbonStart, OnbGiftTimeline.tRibbonEnd],
            [0, 1])
        let opacity = OnbGiftTimeline.interpolate(
            progress,
            [
                OnbGiftTimeline.tRibbonStart,
                OnbGiftTimeline.tRibbonStart + 0.05,
                OnbGiftTimeline.tRibbonEnd * 0.8,
                OnbGiftTimeline.tRibbonEnd,
            ],
            [0, 1, 0.85, 0])
        let x = launchX * time + sin(time * .pi * 3 + phase) * 12
        let y = -440 * time * (1 - time) + 165 * time * time
        let rotation = direction * 200 * time + sin(time * .pi * 4 + phase) * 25

        return RoundedRectangle(cornerRadius: 2)
            .fill(index % 2 == 0 ? OnbGiftTimeline.gold : OnbGiftTimeline.mint)
            .frame(width: 4, height: 26)
            .scaleEffect(x: 1, y: CGFloat(cos(time * .pi * 5 + phase)))
            .rotationEffect(.degrees(rotation))
            .offset(x: CGFloat(x), y: CGFloat(y))
            .opacity(opacity)
    }
}

/// `GlitterDot` : poussière scintillante en suspension autour de l’explosion.
private struct OnbGiftGlitter: View {
    let progress: Double
    let index: Int

    var body: some View {
        let angle = OnbGiftTimeline.seededUnit(Double(index + 41)) * .pi * 2
        let distance = 42 + OnbGiftTimeline.seededUnit(Double(index + 43)) * 78
        let phase = OnbGiftTimeline.seededUnit(Double(index + 47)) * .pi * 2
        let size = 3 + OnbGiftTimeline.seededUnit(Double(index + 53)) * 2
        let time = OnbGiftTimeline.interpolate(
            progress,
            [OnbGiftTimeline.tGlitterStart, OnbGiftTimeline.tGlitterEnd],
            [0, 1])
        let twinkle = sin(time * .pi * 7 + phase) * 0.5 + 0.5
        let fade = OnbGiftTimeline.interpolate(
            progress,
            [
                OnbGiftTimeline.tGlitterStart,
                OnbGiftTimeline.tGlitterStart + 0.05,
                OnbGiftTimeline.tGlitterEnd * 0.78,
                OnbGiftTimeline.tGlitterEnd,
            ],
            [0, 1, 0.8, 0])

        return RoundedRectangle(cornerRadius: 3)
            .fill(index % 3 == 0 ? OnbGiftTimeline.goldSoft : OnbGiftTimeline.giftWhite)
            .frame(width: CGFloat(size), height: CGFloat(size))
            .scaleEffect(CGFloat(0.6 + twinkle * 0.7))
            .offset(
                x: CGFloat(cos(angle) * distance * time),
                y: CGFloat(sin(angle) * distance * time - 22 * time))
            .opacity(fade * (0.35 + twinkle * 0.65))
    }
}

/// `ConfettiPiece` : confetti tombant du haut de la scène en ondulant.
private struct OnbGiftConfetti: View {
    let progress: Double
    let index: Int

    var body: some View {
        let startAt = OnbGiftTimeline.tConfettiStart
            + Double(index % 7) * OnbGiftTimeline.tConfettiStagger
        let endAt = min(startAt + OnbGiftTimeline.tConfettiFall, OnbGiftTimeline.tGlitterEnd - 0.01)
        let baseX = (OnbGiftTimeline.seededUnit(Double(index + 61)) * 2 - 1) * 105
        let phase = OnbGiftTimeline.seededUnit(Double(index + 67)) * .pi * 2
        let direction = index % 2 == 0 ? 1.0 : -1.0
        let width = 6 + OnbGiftTimeline.seededUnit(Double(index + 71)) * 3
        let height = width * (index % 3 == 0 ? 1.5 : 0.7)
        let startY = -Double(OnbGiftTimeline.stageHeight) / 2 - 14
            - OnbGiftTimeline.seededUnit(Double(index + 73)) * 34
        let fall = Double(OnbGiftTimeline.stageHeight) * 0.8
            + OnbGiftTimeline.seededUnit(Double(index + 79)) * 34
        let time = OnbGiftTimeline.interpolate(progress, [startAt, endAt], [0, 1])
        let opacity = OnbGiftTimeline.interpolate(
            progress,
            [startAt, startAt + 0.03, endAt * 0.86, endAt],
            [0, 1, 1, 0])
        let colors = OnbGiftTimeline.confettiColors

        return RoundedRectangle(cornerRadius: 1.5)
            .fill(colors[index % colors.count])
            .frame(width: CGFloat(width), height: CGFloat(height))
            .scaleEffect(x: 1, y: CGFloat(cos(time * .pi * 4 + phase)))
            .rotationEffect(.degrees(direction * 270 * time))
            .offset(
                x: CGFloat(baseX + sin(time * .pi * 2 + phase) * 16),
                y: CGFloat(startY + fall * time))
            .opacity(opacity)
    }
}
