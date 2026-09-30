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
//  V2 (29/09/2026, parité RN dev) — le **producteur de masquage** manquait : la
//  source masque la barre au défilement des écrans
//  (`onBottomNavigationVisibilityChange` → `setBottomNavigationHiddenForScreen`,
//  `App.tsx:707-756,2788+`, via `useScrollChromeVisibility`). Il est porté
//  **dans ce fichier** : `DuelloBottomBarChrome` (état réactif du hook, seuils de
//  `ConsentChromeVisibility`) qu'un écran d'onglet alimente avec l'offset de son
//  défilement, et `.duelloBottomBarChrome(_:forTab:)` qui déclare la visibilité à
//  la racine (`RootChromeModel.setBottomNavigationHidden`). La barre garde sa
//  signature `visible:` : elle consomme `bottomBarHidden` (`MainTabView.swift`).
//  À raccorder (lot W02, `MainTabView.swift` + écrans hôtes) : chaque écran
//  d'onglet possède un `DuelloBottomBarChrome`, lui remet `beginDrag`/`scroll`/
//  `endDrag` depuis sa sonde d'offset et applique `.duelloBottomBarChrome(_:forTab:)`.
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
    /// Sortie verticale de la barre masquée (`hiddenTranslateY`,
    /// `App.tsx:459-473`) : `max(80, hauteur + 8)` une fois la hauteur mesurée.
    @State private var hiddenTranslateY: CGFloat = 80

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
                    .offset(y: (1 - progress) * hiddenTranslateY)
                    .scaleEffect(0.96 + 0.04 * progress)
                    .allowsHitTesting(visible)
                    .accessibilityHidden(!visible)
                    // `onLayout` (`App.tsx:462-473`) : la hauteur réelle de la
                    // barre fixe sa sortie — au moins 80, sinon hauteur + 8,
                    // pour qu'elle finisse entièrement sous l'écran.
                    .background(
                        GeometryReader { proxy in
                            Color.clear.preference(
                                key: DuelloBottomBarHeightKey.self,
                                value: proxy.size.height
                            )
                        }
                    )
            }
        }
        .onPreferenceChange(DuelloBottomBarHeightKey.self) { height in
            let next = max(80, (height + 8).rounded(.up))
            if next != hiddenTranslateY { hiddenTranslateY = next }
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

/// Hauteur mesurée de la barre basse (`onLayout`, `App.tsx:462`), pour calculer
/// sa sortie verticale masquée.
private struct DuelloBottomBarHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

// MARK: - Producteur de masquage

/// Producteur de masquage de la barre basse : équivalent réactif de
/// `useScrollChromeVisibility` (la logique pure vit dans `ConsentChromeVisibility`).
/// Un écran d'onglet le possède (`@StateObject`), lui remet l'offset de son
/// défilement (`beginDrag` / `scroll` / `endDrag`) et applique
/// `.duelloBottomBarChrome(_:forTab:)` : la racine en déduit la visibilité de
/// `DuelloAnimatedBottomBar` (`RootChromeModel.bottomBarHidden`).
final class DuelloBottomBarChrome: ObservableObject {
    /// `visible` du hook : vrai tant qu'un défilement vers le bas ne l'a pas
    /// masqué ; le sommet de liste le rétablit toujours.
    @Published private(set) var visible = true

    /// `ScrollChromeVisibilitySession` en cours, ou `nil` entre deux gestes.
    private var session: ConsentChromeVisibility.Session?

    /// `handleScrollBeginDrag` : ouvre la session au sommet courant.
    func beginDrag(offset: Double) {
        session = ConsentChromeVisibility.beginSession(visible: visible, startOffset: offset)
    }

    /// `handleScroll` : avance la session et publie toute bascule de visibilité.
    func scroll(offset: Double) {
        let current = session
            ?? ConsentChromeVisibility.beginSession(visible: visible, startOffset: offset)
        let next = ConsentChromeVisibility.sessionAfterScroll(current, nextOffset: offset)
        session = next
        if next.visible != visible { visible = next.visible }
    }

    /// `handleScrollEndDrag` / `handleScrollMomentumEnd` : ferme la session ; le
    /// geste suivant ré-ancrera la mesure.
    func endDrag() {
        session = nil
    }

    /// `reset` : revient à visible (écran quitté ou inactif).
    func reset() {
        session = nil
        if !visible { visible = true }
    }
}

/// Rapporte la visibilité du producteur à la racine
/// (`RootChromeModel.setBottomNavigationHidden`), onglet par onglet — équivalent
/// du `useEffect` d'`AccountScreen.tsx:681-693` qui remonte `!visible` à
/// `onBottomNavigationVisibilityChange`. Le rappel est posé sur le fil principal
/// (`Task { @MainActor in … }`), comme `DismissKeyboardOnAppBackground`.
private struct DuelloBottomBarChromeReporter: ViewModifier {
    @ObservedObject var chrome: DuelloBottomBarChrome
    let tab: Int
    @EnvironmentObject private var root: RootChromeModel

    func body(content: Content) -> some View {
        content
            .onAppear { report(hidden: !chrome.visible) }
            .onChange(of: chrome.visible) { visible in report(hidden: !visible) }
            .onDisappear { report(hidden: false) }
    }

    /// Déclare la visibilité courante à la racine, sur le fil principal.
    private func report(hidden: Bool) {
        Task { @MainActor in root.setBottomNavigationHidden(hidden, forTab: tab) }
    }
}

extension View {
    /// Branche un producteur de masquage sur la barre basse de la racine.
    func duelloBottomBarChrome(_ chrome: DuelloBottomBarChrome, forTab tab: Int) -> some View {
        modifier(DuelloBottomBarChromeReporter(chrome: chrome, tab: tab))
    }
}
