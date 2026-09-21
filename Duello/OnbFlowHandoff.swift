//
//  OnbFlowHandoff.swift
//  Duello
//
//  LOT 12-B — passation animée vers l'entraînement.
//
//  Fichier source Expo porté : `src/screens/OnboardingScreen.tsx`
//    - constantes `TRAINING_BLOOM_SIZE`, `TRAINING_BLOOM_RADIUS`,
//      `CONTINUE_BUTTON_HEIGHT`, `ONBOARDING_FOOTER_BOTTOM_PADDING`,
//      `TRAINING_BLOOM_CENTER_ABOVE_SAFE_AREA`, `TRAINING_HANDOFF_DURATION_MS`,
//      `TRAINING_HANDOFF_REVEAL_DURATION_MS`, `TRAINING_HANDOFF_EASING` ;
//    - calcul de `trainingBloomCenterFromBottom` / `trainingBloomScale` ;
//    - `animateTrainingBloom`, `revealTrainingHandoff`,
//      `prewarmTrainingModule` / `waitForTwoPaintedFrames` ;
//    - la surface de passation (`TrainingStartupSurface` sous
//      `trainingHandoffReveal`, opacité + `translateY(8 -> 0)`).
//
//  Le halo est un cercle plein à la couleur de fond de l'écran
//  (`styles.trainingBloom`, 96 pt, rayon 48), qui grossit jusqu'à couvrir la
//  diagonale. L'évaluation du module Entraînement démarre derrière lui et la
//  surface n'apparaît qu'après deux images réellement peintes.
//
//  ⚠️ Écarts assumés :
//   - `requestAnimationFrame` n'existe pas côté Swift : les deux images peintes
//     sont approchées par deux courtes attentes successives (~2 trames à 60 Hz),
//     avant l'appel à `onTrainingSurfaceReady` ;
//   - `downloadedOnboardingBloomOffset` (app de bureau téléchargée) vaut 0 sur
//     mobile : il est figé ici ;
//   - `TRAINING_HANDOFF_EASING` (`OnbUiConstants.trainingHandoffEasing`) n'est
//     pas consommé : SwiftUI interpole nativement via `withAnimation`
//     (`.easeInOut` / `.easeOut`), là où Reanimated pilotait la courbe image
//     par image.
//
//  Cible : iOS 16. Aucune dépendance externe.
//
import SwiftUI
import Combine

/// Constantes et géométrie de la passation vers l'entraînement.
///
/// Les constantes de mise en page et de rythme sont celles du lot `OnbUi`
/// (`OnbUiConstants`) : seules la géométrie du halo et l'interpolation, absentes
/// de ce lot, vivent ici.
enum OnbFlowHandoff {
    /// `TRAINING_BLOOM_SIZE` / `TRAINING_BLOOM_RADIUS`.
    static let bloomSize: CGFloat = OnbUiConstants.trainingBloomSize
    static let bloomRadius: CGFloat = OnbUiConstants.trainingBloomRadius
    /// `downloadedOnboardingBloomOffset`, nul sur mobile.
    static let bloomOffset: CGFloat = 0
    /// `TRAINING_HANDOFF_DURATION_MS` / `TRAINING_HANDOFF_REVEAL_DURATION_MS`.
    static let handoffDuration: Double = Double(OnbUiConstants.trainingHandoffDurationMs) / 1000
    static let revealDuration: Double = Double(OnbUiConstants.trainingHandoffRevealDurationMs) / 1000
    /// Bornes d'échelle du halo : `interpolate([0, 1], [0.08, bloomScale])`.
    static let minBloomScale: CGFloat = 0.08
    /// `translateY(8 -> 0)` de la surface révélée.
    static let revealOffset: CGFloat = 8

    /// `trainingBloomCenterFromBottom`.
    static func centerFromBottom(bottomSafeArea: CGFloat) -> CGFloat {
        bottomSafeArea + OnbUiConstants.trainingBloomCenterAboveSafeArea + bloomOffset
    }

    /// `trainingBloomScale` : de quoi couvrir la diagonale depuis le centre bas.
    static func bloomScale(viewport: CGSize, bottomSafeArea: CGFloat) -> CGFloat {
        let center = centerFromBottom(bottomSafeArea: bottomSafeArea)
        let vertical = max(0, viewport.height - center)
        return ceil(hypot(viewport.width / 2, vertical) / bloomRadius) + 1
    }

    /// Opacité du halo : `interpolate([0, 0.02, 1], [0, 1, 1])`.
    static func bloomOpacity(_ progress: Double) -> Double {
        if progress <= 0 { return 0 }
        if progress >= 0.02 { return 1 }
        return progress / 0.02
    }

    /// Échelle du halo pour une progression donnée.
    static func bloomScaleValue(progress: Double, fullScale: CGFloat) -> CGFloat {
        let clamped = CGFloat(min(max(progress, 0), 1))
        return minBloomScale + (fullScale - minBloomScale) * clamped
    }
}

/// Le halo de passation : un cercle plein à la couleur de fond, centré
/// horizontalement, posé au-dessus du bouton principal.
struct OnbFlowTrainingBloom: View {
    /// Progression 0 → 1 de l'animation d'ouverture.
    let progress: Double
    /// Échelle finale (`trainingBloomScale`).
    let fullScale: CGFloat
    /// Distance du centre du halo au bas de l'écran.
    let centerFromBottom: CGFloat

    var body: some View {
        Circle()
            .fill(Theme.background)
            .frame(width: OnbFlowHandoff.bloomSize, height: OnbFlowHandoff.bloomSize)
            .scaleEffect(OnbFlowHandoff.bloomScaleValue(progress: progress, fullScale: fullScale))
            .opacity(OnbFlowHandoff.bloomOpacity(progress))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .offset(y: -(centerFromBottom - OnbFlowHandoff.bloomRadius))
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

/// La surface d'entraînement révélée sous le halo (`TrainingStartupSurface`
/// sous `trainingHandoffReveal`).
struct OnbFlowTrainingHandoffView: View {
    let programYear: Int
    /// Progression 0 → 1 de la révélation.
    let revealProgress: Double

    var body: some View {
        Ui2TrainingStartupSurface(
            programYear: programYear,
            profileYear: programYear,
            onSelectYear: { _ in }
        )
        .opacity(revealProgress)
        .offset(y: OnbFlowHandoff.revealOffset * (1 - revealProgress))
        .allowsHitTesting(false)
        .accessibilityElement()
        .accessibilityLabel("Ouverture de l’entraînement")
    }
}

/// Pilote l'animation de passation (`animateTrainingBloom` +
/// `revealTrainingHandoff` + `waitForTwoPaintedFrames`).
final class OnbFlowHandoffDriver: ObservableObject {
    @Published private(set) var bloomProgress: Double = 0
    @Published private(set) var revealProgress: Double = 0
    @Published private(set) var isSurfaceVisible = false

    /// Vrai dès que le halo ou la surface doit être affiché.
    var isActive: Bool { bloomProgress > 0 || isSurfaceVisible }

    /// Joue la séquence : ouverture du halo, apparition de la surface, révélation.
    @MainActor
    func start() async {
        isSurfaceVisible = false
        revealProgress = 0
        withAnimation(.easeInOut(duration: OnbFlowHandoff.handoffDuration)) {
            bloomProgress = 1
        }
        try? await Task.sleep(nanoseconds: UInt64(OnbFlowHandoff.handoffDuration * 1_000_000_000))
        isSurfaceVisible = true
        // Deux images réellement peintes avant d'évaluer le module Entraînement.
        try? await Task.sleep(nanoseconds: 32_000_000)
        withAnimation(.easeOut(duration: OnbFlowHandoff.revealDuration)) {
            revealProgress = 1
        }
        try? await Task.sleep(nanoseconds: UInt64(OnbFlowHandoff.revealDuration * 1_000_000_000))
    }

    /// Referme la passation (échec de création de compte : le halo se rétracte).
    @MainActor
    func reset() {
        bloomProgress = 0
        revealProgress = 0
        isSurfaceVisible = false
    }
}
