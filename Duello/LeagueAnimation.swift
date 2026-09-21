//
//  LeagueAnimation.swift
//  Duello
//
//  Socle d'animation des promotions de ligue Elo : interpolation linéaire par
//  morceaux, courbes d'assouplissement et styles dérivés de la progression.
//
//  Fichiers source Expo portés (formules reprises à l'identique) :
//    - src/hooks/useEloLeaguePromotionStyles.ts     (styles animés)
//    - src/hooks/useEloLeaguePromotionLifecycle.ts  (durées, courbes)
//
//  `react-native-reanimated` n'existe pas côté SwiftUI : la progression est
//  pilotée par `TimelineView(.animation)` et les mêmes interpolations sont
//  recalculées à la main, comme dans `ExGPerfectCelebration.swift`.
//  Cible : iOS 16.
//
import Foundation

/// Interpolation et courbes d'assouplissement de Reanimated, transposées.
///
/// `interpolate` reproduit `interpolate(value, inputRange, outputRange)` ;
/// `clamped` reproduit `Extrapolation.CLAMP` (sinon la courbe prolonge la
/// dernière pente, comportement par défaut de Reanimated).
enum LeagueAnimation {
    /// Borne une valeur dans `[0, 1]`.
    static func clamp01(_ value: Double) -> Double {
        min(1, max(0, value))
    }

    /// `Easing.out(Easing.cubic)`.
    static func cubicOut(_ t: Double) -> Double {
        let x = clamp01(t)
        return 1 - pow(1 - x, 3)
    }

    /// `Easing.in(Easing.cubic)`.
    static func cubicIn(_ t: Double) -> Double {
        let x = clamp01(t)
        return x * x * x
    }

    /// `Easing.inOut(Easing.cubic)`.
    static func cubicInOut(_ t: Double) -> Double {
        let x = clamp01(t)
        if x < 0.5 { return 4 * x * x * x }
        return 1 - pow(-2 * x + 2, 3) / 2
    }

    /// `Easing.quad` (accélération quadratique, `t ↦ t²`).
    static func quadIn(_ t: Double) -> Double {
        let x = clamp01(t)
        return x * x
    }

    /// Interpolation linéaire par morceaux, comme `interpolate` de Reanimated.
    static func interpolate(_ value: Double, _ input: [Double], _ output: [Double],
                            clamped: Bool = false) -> Double {
        guard input.count >= 2, input.count == output.count else { return output.first ?? 0 }
        let last = input.count - 1
        if value <= input[0] {
            return clamped ? output[0]
                : linear(value, input[0], input[1], output[0], output[1])
        }
        if value >= input[last] {
            return clamped ? output[last]
                : linear(value, input[last - 1], input[last], output[last - 1], output[last])
        }
        for index in 1...last where value <= input[index] {
            return linear(value, input[index - 1], input[index], output[index - 1], output[index])
        }
        return output[last]
    }

    /// Segment linéaire entre deux points.
    static func linear(_ value: Double, _ x0: Double, _ x1: Double,
                       _ y0: Double, _ y1: Double) -> Double {
        guard x1 > x0 else { return y1 }
        return y0 + (y1 - y0) * (value - x0) / (x1 - x0)
    }
}

/// Styles animés d'une promotion (`useEloLeaguePromotionStyles`), dérivés de la
/// progression révélée `progress ∈ [0, 1]`.
struct LeaguePromotionAnimation {
    /// Progression révélée : 0 = invisible, 1 = pleinement affichée.
    let progress: Double

    /// `backdropStyle` : opacité du voile sombre.
    var backdropOpacity: Double {
        LeagueAnimation.interpolate(progress, [0, 0.32, 1], [0, 1, 1])
    }

    /// `cardStyle.opacity`.
    var cardOpacity: Double {
        LeagueAnimation.interpolate(progress, [0, 0.2, 1], [0, 1, 1])
    }

    /// `cardStyle.transform.translateY`.
    var cardOffsetY: Double {
        LeagueAnimation.interpolate(progress, [0, 0.65, 1], [30, 0, 0], clamped: true)
    }

    /// `cardStyle.transform.scale`.
    var cardScale: Double {
        LeagueAnimation.interpolate(progress, [0, 0.65, 1], [0.94, 1, 1], clamped: true)
    }

    /// `badgeStyle.transform.scale` : le blason grossit d'un coup.
    var badgeScale: Double {
        LeagueAnimation.interpolate(progress, [0, 0.22, 0.72, 1], [0.45, 0.45, 1.08, 1], clamped: true)
    }

    /// `badgeStyle.transform.rotate`, en degrés.
    var badgeRotation: Double {
        LeagueAnimation.interpolate(progress, [0.22, 1], [-10, 0], clamped: true)
    }

    /// `sparkleStyle.opacity` : les étincelles apparaissent puis se posent.
    var sparkleOpacity: Double {
        LeagueAnimation.interpolate(progress, [0, 0.42, 0.7, 1], [0, 0, 1, 0.72], clamped: true)
    }

    /// `sparkleStyle.transform.scale`.
    var sparkleScale: Double {
        LeagueAnimation.interpolate(progress, [0.42, 0.78, 1], [0.55, 1.12, 1], clamped: true)
    }
}
