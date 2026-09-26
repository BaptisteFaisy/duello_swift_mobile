//
//  OnbGiftTimeline.swift
//  Duello
//
//  LOT K — extras d’onboarding : la scène du cadeau Premium et sa timeline.
//
//  Fichiers source Expo portés :
//    - src/components/OnboardingPremiumGiftTimeline.ts (fenêtres temporelles de
//      la séquence, palette, `seededUnit`, `rayPath`)
//    - src/components/OnboardingPremiumGiftStep.tsx (le composant
//      `GiftDayBadge`, l’étiquette « N jours / Premium offerts »)
//
//  Le contrat de portage fait de `OnbGiftTimeline` la vue de la scène : la
//  source ne décrit que des constantes, mais toutes les couches qu’elles
//  pilotent — effets, cadeau, explosion, étiquette — sont rassemblées ici sous
//  une unique progression maîtresse `progress` (0 → 1) et la secousse de scène
//  de `useSceneShakeStyle` (`OnboardingPremiumGiftBox.tsx`).
//
//  ⚠️ `react-native-reanimated` n’existe pas côté Swift : `progress` et
//  `elapsed` sont recalculés à chaque image par le `TimelineView` de
//  `OnbGiftStepView`, et chaque couche en dérive ses transformations. Les
//  constantes non consommées par une couche portée (`T_MESSAGE_*`,
//  `T_RING_*`, `RING_STAGGER`, `T_FLASH_SECOND_PEAK`, `T_FLASH_END`,
//  `T_BADGE_SHIMMER_*`) sont conservées telles quelles : la source les déclare
//  aussi sans les lire dans ces composants.
//
//  Cible : iOS 16.
//
import Foundation
import SwiftUI

/// Scène de la célébration du cadeau : effets, cadeau, explosion et étiquette,
/// sous la progression maîtresse et la secousse de détonation.
struct OnbGiftTimeline: View {
    /// Progression maîtresse, `0 → 1` sur `openSequenceSeconds`.
    let progress: Double
    /// Nombre de taps encaissés (0 à `crackTapCount`) : fissures du cadeau.
    let crackStage: Int
    /// Secondes écoulées depuis l’apparition : pilote les boucles continues
    /// (flottement, orbite, scintillement) qui tournent avant l’ouverture.
    let elapsed: Double

    var body: some View {
        ZStack {
            OnbGiftEffects(progress: progress, elapsed: elapsed)
            OnbGiftBox(progress: progress, crackStage: crackStage, elapsed: elapsed)
            OnbGiftBurstScene(progress: progress)
            OnbGiftDayBadge(progress: progress)
        }
        .frame(width: Self.stageWidth, height: Self.stageHeight)
        .offset(x: Self.shakeX(progress), y: Self.shakeY(progress))
        .accessibilityHidden(true)
    }
}

// MARK: - Mesures et fenêtres temporelles

extension OnbGiftTimeline {
    /// `GIFT_STAGE_WIDTH` / `GIFT_STAGE_HEIGHT` (`OnboardingPremiumGiftBox.tsx`).
    static let stageWidth: CGFloat = 250
    static let stageHeight: CGFloat = 210
    /// `OPEN_SEQUENCE_MS` de `OnboardingPremiumGiftStep.tsx`, en secondes.
    static let openSequenceSeconds: Double = 1.5
    /// `CRACK_TAP_COUNT` : taps qui fissurent le cadeau avant son ouverture.
    static let crackTapCount = 3
    /// `DAY_BADGE_LANDING_Y` : ordonnée d’atterrissage de l’étiquette.
    static let dayBadgeLandingY: Double = 56

    /// Fin de l’anticipation (squash) et instant de la détonation.
    static let tSquashEnd = 0.09
    static let tDetonation = 0.09
    /// Double flash : pic blanc puis pic doré.
    static let tFlashPeak = 0.14
    static let tFlashSecondPeak = 0.2
    static let tFlashEnd = 0.34
    /// Rayons lumineux en étoile.
    static let tRaysStart = 0.09
    static let tRaysEnd = 0.46
    /// Trois ondes de choc décalées.
    static let tRingStart = 0.09
    static let tRingSpan = 0.42
    static let ringStagger = 0.045
    /// Débris de la boîte projetés avec gravité.
    static let tDebrisStart = 0.1
    static let tDebrisFadeStart = 0.58
    static let tDebrisEnd = 0.85
    /// Rubans éjectés en arc puis retombée flottante.
    static let tRibbonStart = 0.12
    static let tRibbonEnd = 0.95
    /// Poussière scintillante en suspension.
    static let tGlitterStart = 0.14
    static let tGlitterEnd = 1.0
    /// Confettis tombant depuis le haut de la scène.
    static let tConfettiStart = 0.2
    static let tConfettiStagger = 0.025
    static let tConfettiFall = 0.42
    /// Étiquette « N jours offerts » : jaillit, atterrit, puis reflet.
    static let tBadgePopStart = 0.3
    static let tBadgePopLand = 0.52
    static let tBadgeShimmerStart = 0.6
    static let tBadgeShimmerEnd = 0.8
    /// Message final (constantes de la source, non lues par ces composants).
    static let tMessageStart = 0.62
    static let tMessageEnd = 0.85
    /// Fin de la secousse de scène déclenchée par la détonation.
    static let tShakeEnd = 0.34

    // MARK: Palette : blanc dominant, or et menthe en accents

    static let giftWhite = Color(hex: 0xFFFFFF)
    static let gold = Color(hex: 0xFDE68A)
    static let goldSoft = Color(hex: 0xFEF3C7)
    static let mint = Color(hex: 0xBBF7D0)
    static let greenSpark = Color(hex: 0x4ADE80)
    static let debrisColors: [Color] = [
        OnbGiftTimeline.giftWhite, OnbGiftTimeline.goldSoft, OnbGiftTimeline.mint,
        OnbGiftTimeline.giftWhite, OnbGiftTimeline.gold,
    ]
    static let confettiColors: [Color] = [
        OnbGiftTimeline.gold, OnbGiftTimeline.giftWhite, OnbGiftTimeline.mint,
        OnbGiftTimeline.goldSoft, OnbGiftTimeline.greenSpark,
    ]
    static let sparkleColors: [Color] = [
        OnbGiftTimeline.giftWhite, OnbGiftTimeline.gold, OnbGiftTimeline.mint,
        OnbGiftTimeline.giftWhite, OnbGiftTimeline.goldSoft,
    ]
}

// MARK: - Helpers partagés par les couches

extension OnbGiftTimeline {
    /// Interpolation linéaire par morceaux, bornée aux extrémités : calque de
    /// `interpolate(value, input, output, Extrapolation.CLAMP)` de Reanimated.
    static func interpolate(_ value: Double, _ input: [Double], _ output: [Double]) -> Double {
        guard input.count >= 2, input.count == output.count else { return output.first ?? 0 }
        if value <= input[0] { return output[0] }
        if value >= input[input.count - 1] { return output[output.count - 1] }
        for index in 0..<(input.count - 1) where value <= input[index + 1] {
            let span = input[index + 1] - input[index]
            let ratio = span == 0 ? 0 : (value - input[index]) / span
            return output[index] + (output[index + 1] - output[index]) * ratio
        }
        return output[output.count - 1]
    }

    /// Pseudo-aléatoire déterministe dans `[0, 1[` : stable entre les images,
    /// calculé uniquement au montage des couches, comme `seededUnit`.
    static func seededUnit(_ seed: Double) -> Double {
        let x = sin(seed * 127.1 + 311.7) * 43758.5453123
        return x - floor(x)
    }

    /// Chemin SVG effilé d’un rayon lumineux du starburst (`rayPath`).
    static func rayPath(index: Int, count: Int, radius: Double, center: CGPoint) -> Path {
        let angle = (Double(index) / Double(count)) * .pi * 2
        let halfWidth = .pi / Double(count) / 2.6
        var path = Path()
        path.move(to: polarPoint(angle: angle + halfWidth, radius: radius * 0.16, center: center))
        path.addLine(to: polarPoint(angle: angle, radius: radius, center: center))
        path.addLine(to: polarPoint(angle: angle - halfWidth, radius: radius * 0.16, center: center))
        path.closeSubpath()
        return path
    }

    /// Point du cercle de rayon `radius` à l’angle `angle`, autour de `center`.
    private static func polarPoint(angle: Double, radius: Double, center: CGPoint) -> CGPoint {
        CGPoint(x: center.x + CGFloat(cos(angle) * radius), y: center.y + CGFloat(sin(angle) * radius))
    }

    /// Secousse horizontale de la scène après la détonation.
    static func shakeX(_ progress: Double) -> CGFloat {
        CGFloat(interpolate(
            progress,
            [tDetonation, 0.13, 0.17, 0.21, 0.25, 0.29, tShakeEnd],
            [0, -10, 8, -6, 4, -2, 0]))
    }

    /// Secousse verticale de la scène après la détonation.
    static func shakeY(_ progress: Double) -> CGFloat {
        CGFloat(interpolate(
            progress,
            [tDetonation, 0.13, 0.17, 0.21, 0.25, tShakeEnd],
            [0, -5, 4, -3, 1.5, 0]))
    }
}

// MARK: - Étiquette des jours offerts

/// Étiquette « 7 jours / Premium offerts » : jaillit du centre et atterrit sous
/// l’explosion (`GiftDayBadge` de `OnboardingPremiumGiftStep.tsx`).
struct OnbGiftDayBadge: View {
    let progress: Double

    var body: some View {
        let motion = badgeMotion

        return VStack(spacing: 1) {
            Text("\(PremOfferCatalog.trialDays) jours")
                .font(.system(size: 18, weight: .black))
                .tracking(0.3)
                .foregroundStyle(Theme.ink)
            Text("Premium offerts")
                .font(.system(size: 11, weight: .bold))
                .textCase(.uppercase)
                .tracking(1.2)
                .foregroundStyle(Theme.inkSoft)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Theme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Theme.surface, lineWidth: 1.5)
                )
                .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 3)
        )
        .opacity(motion.appear)
        .scaleEffect(CGFloat(motion.scale))
        .rotationEffect(.degrees(motion.rotation))
        .offset(y: CGFloat(motion.offsetY))
    }

    /// Les quatre valeurs animées de l’étiquette, dérivées de la progression :
    /// apparition, ordonnée d’atterrissage, échelle et inclinaison.
    private var badgeMotion: (appear: Double, offsetY: Double, scale: Double, rotation: Double) {
        let appear = OnbGiftTimeline.interpolate(
            progress,
            [OnbGiftTimeline.tBadgePopStart, OnbGiftTimeline.tBadgePopStart + 0.06],
            [0, 1])
        let offsetY = OnbGiftTimeline.interpolate(
            progress,
            [
                OnbGiftTimeline.tBadgePopStart,
                OnbGiftTimeline.tBadgePopStart + 0.1,
                OnbGiftTimeline.tBadgePopLand,
            ],
            [-14, OnbGiftTimeline.dayBadgeLandingY + 8, OnbGiftTimeline.dayBadgeLandingY])
        let scale = OnbGiftTimeline.interpolate(
            progress,
            [
                OnbGiftTimeline.tBadgePopStart,
                OnbGiftTimeline.tBadgePopStart + 0.1,
                OnbGiftTimeline.tBadgePopLand * 0.92,
                OnbGiftTimeline.tBadgePopLand,
            ],
            [0.2, 1.22, 0.96, 1])
        let rotation = OnbGiftTimeline.interpolate(
            progress,
            [OnbGiftTimeline.tBadgePopStart, OnbGiftTimeline.tBadgePopLand],
            [-7, 0])

        return (appear: appear, offsetY: offsetY, scale: scale, rotation: rotation)
    }
}
