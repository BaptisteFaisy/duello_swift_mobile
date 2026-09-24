//
//  DropdownOverlayView.swift
//  Duello
//
//  Lot « KIT partagé » — menu déroulant ancré : voile flottant plein écran.
//
//  Fichier source Expo porté (repris à l'identique) :
//    - src/components/DropdownOverlay.tsx (DropdownOverlay,
//      `registeredDropdowns`, `SCREEN_GUTTER`, `MENU_GAP`)
//
//  Usages Expo recensés :
//    - src/screens/SubjectsScreen.tsx (5 menus, portée `subjects-screen`) :
//        · BadgeFilterDropdown      (l. 1356, `minWidth` 210 pour « Difficulté »)
//        · NotionsDropdown          (l. 1442, menu vide)
//        · ClassiqueDropdown        (l. 1497)
//        · SubjFlashcardTypeDropdown(l. 1646)
//        · SubjFlashcardChapterDropdown (l. 1738)
//    - src/screens/EnhancedProgressScreen.tsx (l. 321, portée
//      `enhanced-progress`) : filtre de matières ;
//    - src/components/ProfileSafetyMenu.tsx (l. 86, `minWidth` 164, sans
//      portée) : menu d'actions ;
//    - src/components/DesktopChallengeForm.tsx (l. 54 et 73, portée
//      `desktop-challenge`, `maxHeight` 286) — non porté (desktop-only).
//
//  Le voile RN est une `Modal` transparente. Une couche plein écran ferme le
//  menu à l'appui et, quand l'appui tombe sur le déclencheur d'un **autre**
//  menu de la même portée, lui transmet l'ouverture (un seul menu ouvert à la
//  fois). Le menu est posé en absolu au bord du déclencheur :
//    · largeur = max(largeur du déclencheur, `minWidth`), bornée aux gouttières ;
//    · écart de 6 pt sous le déclencheur, bascule **au-dessus** quand la place
//      manque en dessous et qu'il y en a davantage au-dessus ;
//    · hauteur plafonnée (`maxHeight`, 360 par défaut) ;
//    · opacité 0 tant que la hauteur du menu n'est pas connue (évite un saut).
//
//  Cible : iOS 16, aucune API iOS 17.
//
import Combine
import SwiftUI

// MARK: - Constantes

/// Mesures de `DropdownOverlay.tsx`.
enum DropdownOverlayMetrics {
    /// `SCREEN_GUTTER` : marge entre le menu et les bords sûrs.
    static let screenGutter: CGFloat = 12
    /// `MENU_GAP` : écart entre le déclencheur et le menu.
    static let menuGap: CGFloat = 6
    /// `maxHeight` par défaut du composant RN.
    static let defaultMaxHeight: CGFloat = 360
}

/// Libellés du composant (`DropdownOverlay.tsx`).
enum DropdownOverlayCopy {
    /// `accessibilityLabel` du voile qui ferme le menu.
    static let closeLabel = "Fermer le menu déroulant"
}

// MARK: - Registre des déclencheurs

/// Registre des déclencheurs, calqué sur la `Map` `registeredDropdowns` du RN.
/// Une entrée par déclencheur : son cadre (mesuré comme `measureInWindow`), sa
/// portée (`coordinationScope`) et l'action qui ouvre son menu.
///
/// À conserver dans l'écran (`@StateObject`) pour qu'il survive aux
/// recompositions, et à partager entre un déclencheur et son menu.
final class DropdownOverlayRegistry: ObservableObject {
    private struct Entry {
        var frame: CGRect?
        var scope: String?
        var onRequestOpen: (() -> Void)?
    }

    private var entries: [String: Entry] = [:]
    /// Ordre d'inscription — `registeredDropdownTarget` balaie à l'envers.
    private var order: [String] = []

    /// `registeredDropdowns.set(...)` : à l'apparition du déclencheur.
    func register(_ id: String, scope: String?, onRequestOpen: (() -> Void)?) {
        var entry = entries[id] ?? Entry()
        entry.scope = scope
        entry.onRequestOpen = onRequestOpen
        entries[id] = entry
        if !order.contains(id) { order.append(id) }
    }

    /// `registeredDropdowns.delete(...)` : à la disparition du déclencheur.
    func unregister(_ id: String) {
        entries[id] = nil
        order.removeAll { $0 == id }
    }

    /// `anchorView.measureInWindow(...)` : le cadre du déclencheur.
    func setFrame(_ id: String, _ frame: CGRect?) {
        entries[id]?.frame = frame
    }

    /// Le cadre mémorisé du déclencheur, ou `nil`.
    func frame(_ id: String) -> CGRect? {
        entries[id]?.frame
    }

    /// `registeredDropdownTarget` : dernier déclencheur inscrit, d'une autre
    /// identité, de même portée, dont le cadre contient le point et qui sait
    /// s'ouvrir.
    func target(excluding id: String, scope: String?, at point: CGPoint) -> (() -> Void)? {
        guard let scope else { return nil }
        for other in order.reversed() where other != id {
            guard let entry = entries[other],
                  entry.scope == scope,
                  let handler = entry.onRequestOpen,
                  let frame = entry.frame,
                  frame.contains(point)
            else { continue }
            return handler
        }
        return nil
    }
}

// MARK: - Déclencheur

/// Publie le cadre d'un déclencheur dans le registre (mesure en coordonnées
/// globales, comme `measureInWindow`) et inscrit son action d'ouverture.
private struct DropdownAnchorModifier: ViewModifier {
    let id: String
    let registry: DropdownOverlayRegistry
    let scope: String?
    let onRequestOpen: (() -> Void)?

    func body(content: Content) -> some View {
        content
            .background {
                GeometryReader { proxy in
                    Color.clear
                        .onAppear {
                            registry.register(id, scope: scope, onRequestOpen: onRequestOpen)
                            registry.setFrame(id, proxy.frame(in: .global))
                        }
                        .onChange(of: proxy.frame(in: .global)) { frame in
                            registry.setFrame(id, frame)
                        }
                }
            }
            .onDisappear { registry.unregister(id) }
    }
}

extension View {
    /// Marque une vue comme déclencheur de menu déroulant : sa position est
    /// publiée dans `registry` et `onRequestOpen` permet à un menu frère de la
    /// même `scope` de lui rendre la main (coordination du voile RN).
    func dropdownAnchor(
        _ id: String,
        in registry: DropdownOverlayRegistry,
        scope: String? = nil,
        onRequestOpen: (() -> Void)? = nil
    ) -> some View {
        modifier(
            DropdownAnchorModifier(
                id: id,
                registry: registry,
                scope: scope,
                onRequestOpen: onRequestOpen
            )
        )
    }
}

// MARK: - Géométrie

/// Position et taille du menu, transposition littérale du calcul de
/// `DropdownOverlay`. Les coordonnées sont celles de la couche (le
/// déclencheur y est ramené par son cadre global).
private struct DropdownMenuGeometry {
    let left: CGFloat
    let top: CGFloat
    let width: CGFloat
    let resolvedHeight: CGFloat

    init(
        anchor: CGRect,
        insets: EdgeInsets,
        regionSize: CGSize,
        minWidth: CGFloat,
        maxHeight: CGFloat,
        menuHeight: CGFloat?
    ) {
        let gutter = DropdownOverlayMetrics.screenGutter
        let gap = DropdownOverlayMetrics.menuGap

        let safeTop = insets.top + gutter
        let safeBottom = regionSize.height - insets.bottom - gutter
        let safeLeft = insets.leading + gutter
        let safeRight = regionSize.width - insets.trailing - gutter

        let availableBelow = safeBottom - (anchor.maxY + gap)
        let availableAbove = anchor.minY - safeTop - gap
        let measuredHeight = min(menuHeight ?? maxHeight, maxHeight)
        let opensAbove = measuredHeight > availableBelow && availableAbove > availableBelow
        let availableHeight = max(0, min(maxHeight, opensAbove ? availableAbove : availableBelow))

        // `Math.min(Math.max(anchor.width, minWidth), safeRight - safeLeft)` ;
        // le garde `max(0,…)` évite une largeur négative que SwiftUI refuse.
        let maxWidth = max(0, safeRight - safeLeft)
        let width = min(max(anchor.width, minWidth), maxWidth)
        self.width = width
        self.left = min(max(safeLeft, anchor.minX), safeRight - width)
        self.top = opensAbove
            ? max(safeTop, anchor.minY - gap - measuredHeight)
            : anchor.maxY + gap
        self.resolvedHeight = min(menuHeight ?? maxHeight, availableHeight)
    }
}

// MARK: - Couche flottante

/// La couche flottante : voile plein écran + menu ancré. Rendue par
/// `DropdownOverlay` seulement quand il est présenté.
private struct DropdownOverlayLayer<Menu: View>: View {
    let anchorFrame: CGRect
    let minWidth: CGFloat
    let maxHeight: CGFloat
    let scrollable: Bool
    let onBackdropTap: (CGPoint) -> Void
    @Binding var menuHeight: CGFloat?
    @ViewBuilder let menu: () -> Menu

    var body: some View {
        GeometryReader { proxy in
            let layerOrigin = proxy.frame(in: .global).origin
            let anchor = anchorFrame.offsetBy(dx: -layerOrigin.x, dy: -layerOrigin.y)
            let geometry = DropdownMenuGeometry(
                anchor: anchor,
                insets: proxy.safeAreaInsets,
                regionSize: proxy.size,
                minWidth: minWidth,
                maxHeight: maxHeight,
                menuHeight: menuHeight
            )

            ZStack(alignment: .topLeading) {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture(coordinateSpace: .local) { point in
                        onBackdropTap(CGPoint(x: point.x + layerOrigin.x, y: point.y + layerOrigin.y))
                    }
                    .accessibilityLabel(DropdownOverlayCopy.closeLabel)
                    .accessibilityAddTraits(.isButton)

                menuBody(geometry: geometry)
                    .opacity(menuHeight == nil ? 0 : 1)
                    .offset(x: geometry.left, y: geometry.top)
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
        }
        .ignoresSafeArea()
    }

    /// Le menu, dimensionné comme RN : largeur imposée, hauteur = hauteur du
    /// contenu plafonnée par la place disponible.
    @ViewBuilder
    private func menuBody(geometry: DropdownMenuGeometry) -> some View {
        if scrollable {
            // Contenu défilant (RN : `<ScrollView style={styles.badgeFilterMenu}>`).
            ScrollView {
                menuContent(width: geometry.width)
            }
            .frame(width: geometry.width, height: geometry.resolvedHeight)
        } else {
            // Contenu simple (RN : `<View>` dans `overflow: hidden`).
            menuContent(width: geometry.width)
                .frame(width: geometry.width, height: geometry.resolvedHeight, alignment: .top)
                .clipped()
        }
    }

    /// Le contenu du menu, à la largeur imposée, plus la mesure de sa hauteur
    /// naturelle (`onLayout` du RN).
    private func menuContent(width: CGFloat) -> some View {
        menu()
            .frame(width: width, alignment: .leading)
            .background { menuHeightReader }
    }

    /// Mesure la hauteur naturelle du contenu (proposition non bornée).
    private var menuHeightReader: some View {
        GeometryReader { proxy in
            Color.clear
                .onAppear { menuHeight = proxy.size.height }
                .onChange(of: proxy.size.height) { height in menuHeight = height }
        }
    }
}

// MARK: - Menu déroulant

/// Menu déroulant ancré à un déclencheur (`DropdownOverlay.tsx`).
///
/// À poser en superposition de l'écran — `.overlay { DropdownOverlay(…) }` sur
/// la vue racine — une instance par menu. Le déclencheur, lui, porte
/// `.dropdownAnchor(id:in:scope:onRequestOpen:)` et partage le même `registry`.
///
/// Le **contenu** passé au menu est le panneau seul (fond, bord, ombre, et son
/// éventuel `marginTop` — `badgeFilterMenu` en porte un de 6) ; le composant
/// se charge du défilement et du rognage, comme la `Modal` du RN.
struct DropdownOverlay<Menu: View>: View {
    @Binding var isPresented: Bool
    /// Identité du déclencheur dans `registry` (l'`anchorRef` du RN).
    let anchorID: String
    let registry: DropdownOverlayRegistry
    /// `coordinationScope` : deux menus de même portée ne s'ouvrent pas
    /// ensemble — l'appui sur le voile ouvre le menu visé.
    var coordinationScope: String? = nil
    /// `minWidth` : largeur minimale du menu (164 pour le menu d'actions, 210
    /// pour « Difficulté »).
    var minWidth: CGFloat = 0
    /// `maxHeight` : plafond de hauteur (360 par défaut, 286 en défi desktop).
    var maxHeight: CGFloat = DropdownOverlayMetrics.defaultMaxHeight
    /// `true` quand le RN enveloppe le contenu dans un `ScrollView`
    /// (`badgeFilterMenu`, menu du défi desktop) ; `false` pour un panneau
    /// simple (`pickerPanel`, `emptyNotionsMenu`, actions de sécurité), alors
    /// rogné comme l'`overflow: hidden` du RN.
    var scrollable: Bool = true
    @ViewBuilder let menu: () -> Menu

    @State private var menuHeight: CGFloat?

    var body: some View {
        Group {
            if isPresented, let anchorFrame = registry.frame(anchorID) {
                DropdownOverlayLayer(
                    anchorFrame: anchorFrame,
                    minWidth: minWidth,
                    maxHeight: maxHeight,
                    scrollable: scrollable,
                    onBackdropTap: handleBackdropTap,
                    menuHeight: $menuHeight,
                    menu: menu
                )
            }
        }
        .onChange(of: isPresented) { presented in
            if !presented { menuHeight = nil }
        }
    }

    /// `handleBackdropPress` : ferme le menu, puis transmet l'ouverture au
    /// menu frère dont le déclencheur contient l'appui.
    private func handleBackdropTap(_ globalPoint: CGPoint) {
        let target = registry.target(
            excluding: anchorID,
            scope: coordinationScope,
            at: globalPoint
        )
        isPresented = false
        target?()
    }
}
