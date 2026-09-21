import Foundation

/// Géométrie de la piste du parcours HEC.
///
/// Porté de `src/utils/hecJourney3d.ts` — `HEC_JOURNEY_WORLD_SPACING_SCALE`,
/// `HEC_JOURNEY_WORLD_STEP`, `HEC_JOURNEY_WORLD_RISE`,
/// `HEC_JOURNEY_STRAIGHT_ENTRY_END`, `HEC_JOURNEY_STRAIGHT_ENTRY_BLEND_END`,
/// `HEC_JOURNEY_FOG_NEAR`, `HEC_JOURNEY_FOG_FAR`, `hecJourneyWorldPoint`,
/// `hecJourneyCameraFraming`, `hecJourneyFogVisibility` — et de
/// `journeyNativeCrestLabelPoint` de `src/components/HecJourneyScene.tsx`.
///
/// La scène Expo est un rendu `three` (Canvas OpenGL) : un tuyau courbe, des
/// blocs posés dessus, une caméra qui suit la piste et une brume linéaire.
/// `HecJourneySceneView` réutilise **les mêmes formules** pour une frise 2D
/// SwiftUI : `x` écarte le bloc du centre, la profondeur `z` donne la distance
/// à la caméra, et la loi de brume donne l'opacité. Rien n'est inventé, seul le
/// rendu change (limite assumée, faute de moteur 3D embarqué).
enum HecJourneyGeometry {

    /// `HEC_JOURNEY_WORLD_SPACING_SCALE`.
    static let worldSpacingScale = 0.78
    /// `HEC_JOURNEY_WORLD_STEP`.
    static let worldStep = 4.4 * worldSpacingScale
    /// `HEC_JOURNEY_WORLD_RISE`.
    static let worldRise = 1.18 * worldSpacingScale
    /// `HEC_JOURNEY_FOG_NEAR` / `HEC_JOURNEY_FOG_FAR`.
    static let fogNear = 18.0
    static let fogFar = 64.0

    private static let straightEntryEnd = 0.36
    private static let straightEntryBlendEnd = 0.9

    /// `hecJourneyWorldPoint` : l'entrée reste droite, la courbure arrive
    /// ensuite par interpolation douce, et chaque étape monte un peu.
    static func worldPoint(_ progress: Double) -> (x: Double, y: Double, z: Double) {
        let blend = min(
            1,
            max(0, (progress - straightEntryEnd) / (straightEntryBlendEnd - straightEntryEnd))
        )
        let smoothBlend = blend * blend * (3 - 2 * blend)
        let curvedX = (sin(progress * 1.31) * 2.25 + sin(progress * 0.47) * 0.72) * worldSpacingScale
        return (
            x: curvedX * smoothBlend,
            y: elevation(progress),
            z: progress == 0 ? 0 : -progress * worldStep
        )
    }

    /// `hecJourneyElevation` : progression verticale continue.
    static func elevation(_ progress: Double) -> Double {
        max(0, progress) * worldRise
    }

    /// `hecJourneyCameraFraming` : la caméra recule légèrement au départ, puis
    /// retrouve son cadrage normal dès la première unité de temps.
    static func cameraDistance(_ progress: Double) -> Double {
        6.6 - min(1, max(0, progress)) * 0.9
    }

    /// `hecJourneyFogVisibility` : opacité linéaire entre les deux plans de
    /// brume.
    static func fogVisibility(distance: Double) -> Double {
        let fade = (fogFar - distance) / (fogFar - fogNear)
        return min(1, max(0, fade))
    }

    /// Distance approximative entre la caméra (posée derrière le bloc actif) et
    /// un point de la piste : recul de la caméra plus écart le long de la piste.
    static func cameraDistance(to progress: Double, activeProgress: Double) -> Double {
        let gap = abs(worldPoint(progress).z - worldPoint(activeProgress).z)
        return cameraDistance(activeProgress) + gap
    }

    /// `hecJourneyFogVisibility` appliquée depuis le bloc actif : c'est
    /// l'opacité des blocs dans `HecJourneySceneView`.
    static func visibility(progress: Double, activeProgress: Double) -> Double {
        fogVisibility(distance: cameraDistance(to: progress, activeProgress: activeProgress))
    }
}
