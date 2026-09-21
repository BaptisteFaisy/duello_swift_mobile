//
//  ExGPerfectCelebration.swift
//  Duello
//
//  Célébration de l'exercice parfaitement réussi
//  (`PerfectExerciseCelebration.tsx`) : éclatement de particules et pastille.
//
//  Fichiers source Expo portés (libellés repris mot pour mot) :
//    - src/components/PerfectExerciseCelebration.tsx    (célébration parfaite)
//
//  Découpé de `ExerciseGradingViews.swift` (1 975 lignes) le 2026-09-21 : contenu
//  repris ligne pour ligne — aucun type, propriété, méthode ni signature renommé.
//  Spécification de référence : specs/exws_C.md (§0 socle commun, §1 à §5
//  composants, §6 récapitulatif animations, §7 dépendances non portables).
//  Cible : iOS 16, aucune API iOS 17.
//
import Foundation
import SwiftUI

// MARK: - §5 — Célébration de l'exercice parfait

/// Interpolation linéaire par morceaux, comme `interpolate` de Reanimated.
/// `clamped` reproduit `Extrapolation.CLAMP` ; sinon la courbe prolonge la
/// dernière pente, comportement par défaut de la source.
private func exgInterpolate(_ value: Double, _ input: [Double], _ output: [Double],
                            clamped: Bool = false) -> Double {
    guard input.count >= 2, input.count == output.count else { return output.first ?? 0 }
    if value <= input[0] {
        return clamped ? output[0]
            : exgLinear(value, input[0], input[1], output[0], output[1])
    }
    let last = input.count - 1
    if value >= input[last] {
        return clamped ? output[last]
            : exgLinear(value, input[last - 1], input[last], output[last - 1], output[last])
    }
    for index in 1...last where value <= input[index] {
        return exgLinear(value, input[index - 1], input[index], output[index - 1], output[index])
    }
    return output[last]
}

private func exgLinear(_ value: Double, _ x0: Double, _ x1: Double,
                       _ y0: Double, _ y1: Double) -> Double {
    guard x1 > x0 else { return y1 }
    return y0 + (y1 - y0) * (value - x0) / (x1 - x0)
}

/// `CelebrationParticleModel` : couleur, rotation, forme, taille et éclatement.
private struct ExGCelebrationParticleModel: Identifiable {
    let id: Int
    let colorHex: Int
    let rotation: Double
    let round: Bool
    let size: CGFloat
    let x: CGFloat
    let y: CGFloat
}

/// `CELEBRATION_PARTICLES` — les 12 particules, dans l'ordre exact.
private let exgCelebrationParticles: [ExGCelebrationParticleModel] = [
    ExGCelebrationParticleModel(id: 0, colorHex: 0x22C55E, rotation: 130, round: false, size: 10, x: -106, y: -52),
    ExGCelebrationParticleModel(id: 1, colorHex: 0x0A0D0C, rotation: -95, round: false, size: 7, x: -70, y: -91),
    ExGCelebrationParticleModel(id: 2, colorHex: 0x166534, rotation: 155, round: false, size: 9, x: -24, y: -108),
    ExGCelebrationParticleModel(id: 3, colorHex: 0x22C55E, rotation: -120, round: true, size: 8, x: 34, y: -104),
    ExGCelebrationParticleModel(id: 4, colorHex: 0x0A0D0C, rotation: 105, round: false, size: 8, x: 82, y: -76),
    ExGCelebrationParticleModel(id: 5, colorHex: 0x22C55E, rotation: -160, round: true, size: 10, x: 112, y: -28),
    ExGCelebrationParticleModel(id: 6, colorHex: 0x166534, rotation: 90, round: false, size: 8, x: 104, y: 38),
    ExGCelebrationParticleModel(id: 7, colorHex: 0x0A0D0C, rotation: -135, round: true, size: 7, x: 64, y: 82),
    ExGCelebrationParticleModel(id: 8, colorHex: 0x22C55E, rotation: 145, round: false, size: 10, x: 14, y: 101),
    ExGCelebrationParticleModel(id: 9, colorHex: 0x166534, rotation: -100, round: false, size: 8, x: -43, y: 91),
    ExGCelebrationParticleModel(id: 10, colorHex: 0x0A0D0C, rotation: 120, round: true, size: 7, x: -88, y: 62),
    ExGCelebrationParticleModel(id: 11, colorHex: 0x22C55E, rotation: -145, round: false, size: 9, x: -116, y: 8),
]

/// `CelebrationParticle` : une particule, projetée par `p ∈ [0, 1]`.
private struct ExGCelebrationParticle: View {
    let model: ExGCelebrationParticleModel
    let p: Double

    private var rotation: Double { exgInterpolate(p, [0, 1], [0, model.rotation]) }
    private var opacity: Double { exgInterpolate(p, [0, 0.08, 0.72, 1], [0, 1, 1, 0]) }
    private var translateX: CGFloat {
        CGFloat(exgInterpolate(p, [0, 0.16, 0.82], [0, 0, Double(model.x)], clamped: true))
    }
    private var translateY: CGFloat {
        CGFloat(exgInterpolate(p, [0, 0.16, 0.82], [0, 0, Double(model.y)], clamped: true))
    }
    private var scale: Double { exgInterpolate(p, [0, 0.18, 0.7, 1], [0.3, 1.2, 1, 0.7]) }

    var body: some View {
        RoundedRectangle(cornerRadius: model.round ? model.size / 2 : 2)
            .fill(Color(hex: model.colorHex))
            .frame(width: model.size, height: model.size)
            .rotationEffect(.degrees(rotation))
            .scaleEffect(scale)
            .opacity(opacity)
            .position(x: 108 + model.size / 2 + translateX,
                      y: 108 + model.size / 2 + translateY)
    }
}

/// `CelebrationBadge` : le halo, puis la pastille « Tout est juste ! ».
private struct ExGCelebrationBadge: View {
    let p: Double

    private var badgeOpacity: Double { exgInterpolate(p, [0, 0.1, 0.72, 1], [0, 1, 1, 0]) }
    private var badgeScale: Double { exgInterpolate(p, [0, 0.2, 0.38, 1], [0.4, 1.12, 1, 1]) }
    private var badgeOffset: CGFloat { CGFloat(exgInterpolate(p, [0, 0.7, 1], [10, 0, -12])) }
    private var haloOpacity: Double { exgInterpolate(p, [0, 0.12, 0.6, 0.9], [0, 0.5, 0.18, 0]) }
    private var haloScale: Double { exgInterpolate(p, [0, 0.8], [0.45, 2.1], clamped: true) }

    var body: some View {
        ZStack {
            Circle()
                .fill(Theme.progressLight)
                .frame(width: 68, height: 68)
                .scaleEffect(haloScale)
                .opacity(haloOpacity)

            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(exgMastery)
                        .frame(width: 34, height: 34)
                    Image(systemName: "checkmark")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white)
                }
                Text("Tout est juste !")
                    .font(.system(size: 17, weight: .heavy))
                    .foregroundStyle(Theme.ink)
            }
            .padding(.horizontal, 18)
            .frame(minHeight: 54)
            .background(Theme.surface)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(exgMastery, lineWidth: 1))
            .shadow(color: exgCardShadow, radius: 8, x: 0, y: 2)
            .scaleEffect(badgeScale)
            .offset(y: badgeOffset)
            .opacity(badgeOpacity)
        }
        .frame(width: 224, height: 224)
    }
}

/// `PerfectExerciseCelebration` : éclatement de 12 particules et pastille
/// centrale, déclenché par `active`.
///
/// Une seule valeur pilote `p ∈ [0, 1]`, avec `p(t) = cubicOut(t / 1,6 s)` ;
/// toutes les grandeurs sont des interpolations linéaires par morceaux sur `p`.
/// `TimelineView(.animation)` remplace le thread UI de Reanimated — les
/// animations par images clés (iOS 17) sont volontairement écartées. Si
/// « réduire les animations » est actif, rien n'est affiché, comme le
/// `return null` de la source.
struct ExGPerfectCelebration: View {
    let active: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var startedAt = Date()

    var body: some View {
        Group {
            if active && !reduceMotion {
                TimelineView(.animation) { context in
                    let elapsed = context.date.timeIntervalSince(startedAt)
                    let clamped = min(max(elapsed / 1.6, 0), 1)
                    let p = 1 - pow(1 - clamped, 3)
                    ZStack {
                        ForEach(exgCelebrationParticles) { model in
                            ExGCelebrationParticle(model: model, p: p)
                        }
                        ExGCelebrationBadge(p: p)
                    }
                    .frame(width: 224, height: 224)
                }
                .onAppear { startedAt = Date() }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
