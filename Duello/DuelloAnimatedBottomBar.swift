//
//  DuelloAnimatedBottomBar.swift
//  Duello
//
//  Port de `AnimatedBottomNavigation` (`App.tsx:432-593`) : la barre basse
//  s'efface au défilement de l'écran et réapparaît ensuite.
//
//  Animation reprise telle quelle : opacité `0 → 1`, translation verticale
//  `80 → 0` (`BOTTOM_NAVIGATION_HIDDEN_TRANSLATE_Y`) et échelle `0.96 → 1`,
//  sur `BOTTOM_NAVIGATION_VISIBILITY_ANIMATION_MS` = 320 ms,
//  `Easing.out(Easing.cubic)`.
//
//  `reserveLayout` de la source vaut toujours `false` (`App.tsx:1559`) : la
//  barre libère donc sa ligne de mise en page une fois sortie, comme ici.
//
import SwiftUI

/// Barre basse animée au défilement (`AnimatedBottomNavigation`).
struct DuelloAnimatedBottomBar<Content: View>: View {
    /// La barre doit être visible (`bottomNavigationAvailable`).
    var visible: Bool = true
    @ViewBuilder var content: () -> Content

    /// Reste montée pendant toute la descente, puis libère sa place.
    @State private var rendered: Bool
    /// Progression de l'animation (`progress`, `Animated.Value`).
    @State private var progress: CGFloat

    init(visible: Bool = true, @ViewBuilder content: @escaping () -> Content) {
        self.visible = visible
        self.content = content
        _rendered = State(initialValue: visible)
        _progress = State(initialValue: visible ? 1 : 0)
    }

    var body: some View {
        Group {
            if rendered {
                content()
                    .opacity(progress)
                    .offset(y: (1 - progress) * 80)
                    .scaleEffect(0.96 + 0.04 * progress)
                    .allowsHitTesting(visible)
                    .accessibilityHidden(!visible)
            }
        }
        .onChange(of: visible) { newValue in
            if newValue { rendered = true }
            withAnimation(.timingCurve(0.215, 0.61, 0.355, 1, duration: 0.320)) {
                progress = newValue ? 1 : 0
            }
            if !newValue {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.340) {
                    if !visible { rendered = false }
                }
            }
        }
    }
}
