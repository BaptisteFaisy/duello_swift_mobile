//
//  OnbGiftEasing.swift
//  Duello
//
//  Courbes d’interpolation de la célébration du cadeau Premium de l’onboarding.
//
//  Fichiers source Expo portés : les easing de `react-native-reanimated`
//  employés par `src/components/OnboardingPremiumGift*.tsx` —
//  `Easing.bezier(0.4, 0, 0.2, 1)` (timeline maîtresse de
//  `OnboardingPremiumGiftStep.tsx`), `Easing.inOut(Easing.quad)` (flottement du
//  cadeau, main qui appuie, scintillement des étincelles) et
//  `Easing.inOut(Easing.cubic)` (tracé du graphique de
//  `OnboardingMathProgressChart.tsx`).
//
//  Reanimated n’existe pas côté Swift : les courbes sont évaluées à la main,
//  à chaque image, par le `TimelineView` de `OnbGiftStepView` — voir
//  `OnbGiftTimeline.interpolate` pour l’équivalent d’`interpolate(..., CLAMP)`.
//
//  Cible : iOS 16.
//
import Foundation

/// Courbes normalisées `[0, 1] → [0, 1]`, valeurs hors bornes ramenées dans
/// l’intervalle (l’équivalent des interpolations bornées de la source).
enum OnbGiftEasing {
    /// `Easing.bezier(0.4, 0, 0.2, 1)` : l’easing maître de la séquence.
    static func standard(_ x: Double) -> Double {
        bezier(x, x1: 0.4, y1: 0, x2: 0.2, y2: 1)
    }

    /// `Easing.inOut(Easing.quad)`.
    static func quadInOut(_ x: Double) -> Double {
        let t = clamp(x)
        return t < 0.5 ? 2 * t * t : 1 - pow(2 - 2 * t, 2) / 2
    }

    /// `Easing.inOut(Easing.cubic)`.
    static func cubicInOut(_ x: Double) -> Double {
        let t = clamp(x)
        return t < 0.5 ? 4 * t * t * t : 1 - pow(2 - 2 * t, 3) / 2
    }

    /// Évaluation de la courbe cubique de Bézier `(0,0) (x1,y1) (x2,y2) (1,1)`
    /// pour une abscisse `x` : résolution de `t` par dichotomie, puis `y(t)`.
    static func bezier(
        _ x: Double,
        x1: Double,
        y1: Double,
        x2: Double,
        y2: Double
    ) -> Double {
        let target = clamp(x)
        var low = 0.0
        var high = 1.0
        var t = target
        for _ in 0..<24 {
            if component(t, x1, x2) < target {
                low = t
            } else {
                high = t
            }
            t = (low + high) / 2
        }
        return component(t, y1, y2)
    }

    /// Coordonnée d’une courbe de Bézier cubique de pôles `0 … 1` en `t`.
    private static func component(_ t: Double, _ a: Double, _ b: Double) -> Double {
        let m = 1 - t
        return 3 * m * m * t * a + 3 * m * t * t * b + t * t * t
    }

    /// Ramène une valeur dans `[0, 1]`.
    private static func clamp(_ x: Double) -> Double {
        min(max(x, 0), 1)
    }
}
