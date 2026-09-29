//
//  Ui2OrderedTabPager.swift
//  Duello
//
//  Lot 7-F « UI générique » (préfixe `Ui2`).
//
//  Fichiers source Expo portés :
//    - src/components/OrderedTabPager.tsx (`OrderedTabPager`, `dragPosition`,
//      `SPRING_CONFIG`, `EDGE_RESISTANCE`)
//    - src/utils/orderedTabSwipe.ts (`resolveOrderedTabSwipeIndex`, seuils
//      `TAB_SWIPE_DISTANCE`, `TAB_SWIPE_MIN_FLICK_DISTANCE`, `TAB_SWIPE_VELOCITY`)
//    - src/utils/horizontalGesture.ts (`resolveHorizontalGestureIntent`, seuils
//      `HORIZONTAL_ACTIVATION_DISTANCE`, `VERTICAL_FAILURE_DISTANCE`,
//      `HORIZONTAL_DOMINANCE_RATIO`)
//
//  Pager horizontal léger pour les sous-pages ordonnées. Toutes les pages sont
//  déjà dans le « ruban » : le voisin apparaît donc sous le doigt, sans attendre
//  un rendu au relâchement.
//
//  Écarts assumés (2026-09-29) :
//   • `SPRING_CONFIG.overshootClamping` n'a pas d'équivalent SwiftUI direct ;
//     il est néanmoins satisfait par construction — avec `damping: 34`,
//     `stiffness: 300`, `mass: 0.7`, le ratio d'amortissement vaut
//     34 / (2·√(300·0.7)) ≈ 1,17 > 1 : le ressort est sur-amorti, donc sans
//     dépassement. `energyThreshold` n'est pas transposé (seuil de repos interne).
//
//  Approximations SwiftUI (aucun équivalent direct de Reanimated /
//  gesture-handler) :
//   • le ruban est un `HStack` décalé ; chaque page doit occuper la largeur
//     disponible (`frame(maxWidth: .infinity)`), comme les pages RN (`flex: 1`) ;
//   • `pageProgress` (SharedValue) et `instantTransitions` (sauts sans suivi du
//     doigt) ne sont pas repris : la position suit le doigt et le ressort natif
//     gère le relâchement ;
//   • la vitesse de relâchement est approchée par `predictedEndTranslation` ;
//   • l'élasticité de bord reprend la résistance `EDGE_RESISTANCE` de la source.
//
//  V2 (29/09/2026, parité RN dev) : le geste se raccorde au pager d'onglets
//  parent via le jeton `SwipeBottomTabGestureHandle` (`#10`) — le sous-pager le
//  revendique sur l'intention `.horizontal` (`claimByNestedPager()`), le rend au
//  relâchement (`releaseNestedPager()`), et, depuis la première page, cède un
//  swipe vers la droite au parent (`shouldYieldBackSwipeToTabPager`, activé par
//  `yieldBackSwipeToTabPager`). Inerte hors d'un pager parent.
//  Cible iOS 16.
//
import SwiftUI

/// Ressort de relâchement du pager, aligné sur `SPRING_CONFIG` de la source
/// (`damping: 34, stiffness: 300, mass: 0.7`). Sur-amorti (ratio ≈ 1,17), il ne
/// dépasse pas — `overshootClamping: true` est ainsi respecté.
///
/// Constante **de fichier** (et non `private static` dans le type) : un membre
/// statique stocké est interdit dans un type générique
/// (`Ui2OrderedTabPager<Content: View>`).
private let ui2OrderedPagerSettleSpring: Animation = .interpolatingSpring(
    mass: 0.7,
    stiffness: 300,
    damping: 34
)

/// Cible d'un geste de pagination (`OrderedTabSwipeIndexTarget`).
enum Ui2OrderedTabSwipeTarget: Equatable {
    case page(Int)
    case back
}

/// Math du geste (`orderedTabSwipe.ts` + `horizontalGesture.ts`).
enum Ui2OrderedTabSwipe {
    /// Résistance appliquée au-delà des vraies fins (`EDGE_RESISTANCE`).
    static let edgeResistance: CGFloat = 0.16
    private static let swipeDistance: CGFloat = 32
    private static let minFlickDistance: CGFloat = 12
    private static let swipeVelocity: CGFloat = 380

    /// Intention d'axe (`resolveHorizontalGestureIntent`).
    enum Intent { case pending, horizontal, vertical }

    static func intent(translationX: CGFloat, translationY: CGFloat) -> Intent {
        let distanceX = abs(translationX)
        let distanceY = abs(translationY)
        if distanceY >= 4 && distanceY >= distanceX { return .vertical }
        if distanceX >= 9 && distanceX > distanceY * 1.5 { return .horizontal }
        return .pending
    }

    /// Page visée au relâchement (`resolveOrderedTabSwipeIndex`).
    static func target(
        pageCount: Int,
        currentIndex: Int,
        translationX: CGFloat,
        velocityX: CGFloat
    ) -> Ui2OrderedTabSwipeTarget? {
        let distance = abs(translationX)
        let isQuickFlick = distance > minFlickDistance && abs(velocityX) > swipeVelocity
        if distance <= swipeDistance && !isQuickFlick { return nil }
        if currentIndex < 0 || currentIndex >= pageCount { return nil }

        let direction = abs(translationX) > 2 ? translationX : velocityX
        if direction < 0 {
            let nextIndex = currentIndex + 1
            return nextIndex < pageCount ? .page(nextIndex) : nil
        }
        let previousIndex = currentIndex - 1
        return previousIndex >= 0 ? .page(previousIndex) : .back
    }

    /// Position du ruban pendant le geste, avec résistance aux vraies fins
    /// (`dragPosition` de la source).
    static func dragPosition(
        originX: CGFloat,
        translationX: CGFloat,
        viewportWidth: CGFloat,
        pageCount: Int,
        startPage: Int,
        leadingBackEnabled: Bool
    ) -> CGFloat {
        let firstNeighbor = max(0, startPage - 1)
        let lastNeighbor = min(pageCount - 1, startPage + 1)
        let firstPosition = (startPage == 0 && leadingBackEnabled)
            ? viewportWidth
            : -CGFloat(firstNeighbor) * viewportWidth
        let lastPosition = -CGFloat(lastNeighbor) * viewportWidth
        let rawPosition = originX + translationX

        if rawPosition > firstPosition {
            return firstPosition + (rawPosition - firstPosition) * edgeResistance
        }
        if rawPosition < lastPosition {
            return lastPosition + (rawPosition - lastPosition) * edgeResistance
        }
        return rawPosition
    }
}

/// Pager horizontal léger pour sous-pages ordonnées (`OrderedTabPager.tsx`).
struct Ui2OrderedTabPager<Content: View>: View {
    /// Anime le ruban ; à désactiver pour un simple changement de section.
    var animated: Bool = true
    /// Nombre de pages du ruban (la source le déduit des enfants ; ici fourni).
    let pageCount: Int
    /// Index contrôlé par les onglets de la sous-page.
    let page: Int
    /// Notifie un changement de page provoqué par un geste.
    let onPageSelected: (Int) -> Void
    /// Autorise le geste de retour au-delà de la première page.
    var onBack: (() -> Void)? = nil
    /// Laisse un conteneur parent prendre en charge le geste horizontal.
    var swipeEnabled: Bool = true
    /// Rend le geste de retour au pager d'onglets parent depuis la première page
    /// (`yieldBackSwipeToTabPager` d'`OrderedTabPager`). Inerte sans pager parent.
    var yieldBackSwipeToTabPager: Bool = false
    @ViewBuilder var content: () -> Content

    /// Jeton du pager d'onglets parent (`BottomTabSwipeGestureContext`) : le
    /// sous-pager le revendique pendant un mouvement horizontal et le lui rend au
    /// relâchement ; `nil` hors d'un pager parent.
    @Environment(\.swipeBottomTabGesture) private var nestedGesture: SwipeBottomTabGestureHandle?

    @State private var settledPage: Int
    @State private var dragOffset: CGFloat = 0
    @State private var dragStartPage = 0
    @State private var isDragging = false

    init(
        animated: Bool = true,
        pageCount: Int,
        page: Int,
        onPageSelected: @escaping (Int) -> Void,
        onBack: (() -> Void)? = nil,
        swipeEnabled: Bool = true,
        yieldBackSwipeToTabPager: Bool = false,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.animated = animated
        self.pageCount = pageCount
        self.page = page
        self.onPageSelected = onPageSelected
        self.onBack = onBack
        self.swipeEnabled = swipeEnabled
        self.yieldBackSwipeToTabPager = yieldBackSwipeToTabPager
        self.content = content
        _settledPage = State(initialValue: Ui2OrderedTabPager.clamp(page, pageCount))
    }

    private static func clamp(_ value: Int, _ count: Int) -> Int {
        guard count > 0 else { return 0 }
        return max(0, min(count - 1, value))
    }

    private var leadingBackEnabled: Bool { onBack != nil }

    var body: some View {
        GeometryReader { proxy in
            let width = max(1, proxy.size.width)
            ZStack(alignment: .leading) {
                HStack(spacing: 0) {
                    Group { content() }.frame(maxWidth: .infinity)
                }
                .frame(width: width * CGFloat(max(pageCount, 1)), alignment: .leading)
                .offset(x: -CGFloat(settledPage) * width + dragOffset)
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .leading)
            .contentShape(Rectangle())
            .simultaneousGesture(swipeGesture(width: width))
        }
        .clipped()
        .onChange(of: page) { newValue in
            let target = Self.clamp(newValue, pageCount)
            guard target != settledPage else { return }
            commit(target, notify: false)
        }
    }

    /// Geste de pagination : intention d'axe, suivi du doigt, relâchement.
    private func swipeGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard swipeEnabled, pageCount > 0 else { return }
                if !isDragging {
                    let intent = Ui2OrderedTabSwipe.intent(
                        translationX: value.translation.width,
                        translationY: value.translation.height
                    )
                    switch intent {
                    case .vertical, .pending: return
                    case .horizontal:
                        // Depuis la première page, un swipe vers la droite
                        // appartient au pager d'onglets parent : on le lui rend
                        // au lieu de le revendiquer (`shouldYieldBackSwipe…`).
                        guard !yieldsBackSwipeToTabPager(translationX: value.translation.width)
                        else { return }
                        isDragging = true
                        dragStartPage = settledPage
                        nestedGesture?.claimByNestedPager()
                    }
                }
                let position = Ui2OrderedTabSwipe.dragPosition(
                    originX: -CGFloat(dragStartPage) * width,
                    translationX: value.translation.width,
                    viewportWidth: width,
                    pageCount: pageCount,
                    startPage: dragStartPage,
                    leadingBackEnabled: leadingBackEnabled
                )
                dragOffset = position + CGFloat(dragStartPage) * width
            }
            .onEnded { value in
                guard isDragging else { return }
                isDragging = false
                // Rend le mouvement au pager principal (`release()`).
                nestedGesture?.releaseNestedPager()
                settle(value: value)
            }
    }

    /// Relâchement : page visée (`resolveOrderedTabSwipeIndex`) ou retour.
    private func settle(value: DragGesture.Value) {
        let velocity = value.predictedEndTranslation.width - value.translation.width
        let target = Ui2OrderedTabSwipe.target(
            pageCount: pageCount,
            currentIndex: dragStartPage,
            translationX: value.translation.width,
            velocityX: velocity
        )
        switch target {
        case .page(let index):
            commit(index, notify: true)
        case .back:
            resetOffset()
            onBack?()
        case nil:
            resetOffset()
        }
    }

    /// Depuis la première page, un swipe vers la droite appartient au pager
    /// d'onglets parent : le sous-pager échoue alors pour lui rendre le geste
    /// (`shouldYieldBackSwipeToTabPager`, `orderedTabSwipe.ts:74-83`).
    private func yieldsBackSwipeToTabPager(translationX: CGFloat) -> Bool {
        guard let handle = nestedGesture else { return false }
        return handle.shouldYieldBackSwipeToTabPager(
            gestureStartPage: settledPage,
            translationX: translationX,
            yieldEnabled: yieldBackSwipeToTabPager
        )
    }

    /// Fixe la page et le décalage ; `notify` distingue geste et prop contrôlée.
    private func commit(_ index: Int, notify: Bool) {
        if animated {
            withAnimation(ui2OrderedPagerSettleSpring) {
                settledPage = index
                dragOffset = 0
            }
        } else {
            settledPage = index
            dragOffset = 0
        }
        if notify { onPageSelected(index) }
    }

    /// Ramène le ruban à sa position de repos.
    private func resetOffset() {
        if animated {
            withAnimation(ui2OrderedPagerSettleSpring) {
                dragOffset = 0
            }
        } else {
            dragOffset = 0
        }
    }
}
