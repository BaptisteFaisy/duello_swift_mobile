//
//  SwipeRowVisibilityTracking.swift
//  Duello
//
//  Lot 7-G « gestes d'onglets et visibilité de ligne » (préfixe `Swipe`).
//
//  Fichier source Expo porté :
//    - src/hooks/useLeaderboardCurrentRowVisibility.ts — `screenRef`,
//      `currentRowRef`, `currentRowVisible`, `onScreenLayout`,
//      `onCurrentRowLayout`, `onScroll` (mesure replanifiée à chaque
//      défilement et à chaque changement de mise en page).
//
//  Équivalent SwiftUI des références mesurées de la source : le conteneur
//  publie son cadre `.global` par l'environnement, la ligne courante remonte le
//  sien par préférence, et la règle pure de `SwipeRowVisibility` tranche.
//
//  Limites documentées : SwiftUI n'a ni `measureInWindow` ni `onScroll`
//  impératifs ; la mesure est donc **réactive** (le cadre `.global` de la ligne
//  change pendant le défilement, ce qui déclenche `onPreferenceChange`) et le
//  cadre nul (aucune mesure) retombe sur `SwipeRowVisibility.defaultVisible`.
//  Cible iOS 16 (pas d'`onScrollGeometryChange`).
//
import SwiftUI

/// Cadre de l'écran hôte dans le repère `.global`.
private struct SwipeScreenFrameKey: EnvironmentKey {
    static let defaultValue: CGRect = .zero
}

extension EnvironmentValues {
    /// Cadre de l'écran hôte : équivalent du `screenRef` + `measureInWindow`.
    var swipeScreenFrame: CGRect {
        get { self[SwipeScreenFrameKey.self] }
        set { self[SwipeScreenFrameKey.self] = newValue }
    }
}

/// Conteneur d'écran qui publie son cadre global à ses lignes
/// (`screenRef` de `useLeaderboardCurrentRowVisibility`).
struct SwipeScreenFrameReader<Content: View>: View {
    @ViewBuilder var content: () -> Content

    /// Initialiseur explicite, comme `Ui2OrderedTabPager` (lot 7-F).
    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        GeometryReader { proxy in
            content()
                .environment(\.swipeScreenFrame, proxy.frame(in: .global))
        }
    }
}

/// Cadre de la ligne courante, remonté par préférence
/// (`currentRowRef` + `onCurrentRowLayout`).
private struct SwipeRowFrameKey: PreferenceKey {
    static let defaultValue: CGRect = .zero

    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        let next = nextValue()
        if next != .zero { value = next }
    }
}

/// Mesure la ligne courante et publie sa visibilité à chaque défilement
/// (`useLeaderboardCurrentRowVisibility`).
struct SwipeCurrentRowVisibilityModifier: ViewModifier {
    @Environment(\.swipeScreenFrame) private var screenFrame
    @Binding var isVisible: Bool

    /// Initialiseur explicite : le cadre d'écran vient de l'environnement.
    init(isVisible: Binding<Bool>) {
        _isVisible = isVisible
    }

    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: SwipeRowFrameKey.self,
                        value: proxy.frame(in: .global)
                    )
                }
            )
            .onPreferenceChange(SwipeRowFrameKey.self) { frame in
                publish(frame)
            }
    }

    /// Applique la règle du hook à la mesure courante ; sans mesure, la ligne
    /// reste visible (`defaultVisible`).
    private func publish(_ frame: CGRect) {
        guard frame != .zero, screenFrame != .zero else {
            isVisible = SwipeRowVisibility.defaultVisible
            return
        }
        isVisible = SwipeRowVisibility.isVisible(row: frame, screen: screenFrame)
    }
}

extension View {
    /// Rend une ligne « courante » mesurée à l'écran
    /// (`currentRowRef` de `useLeaderboardCurrentRowVisibility`).
    func swipeCurrentRowVisibility(_ isVisible: Binding<Bool>) -> some View {
        modifier(SwipeCurrentRowVisibilityModifier(isVisible: isVisible))
    }
}
