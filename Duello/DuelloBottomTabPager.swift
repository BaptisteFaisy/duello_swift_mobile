//
//  DuelloBottomTabPager.swift
//  Duello
//
//  Port de `src/components/BottomTabPager.native.tsx` — le pager principal des
//  trois onglets de la barre basse — remplaçant le `TabView(.page)` natif, qui
//  ne rend ni la progression continue de la barre, ni la résistance de bord, ni
//  le verrou de geste de la source.
//
//  Physique reprise telle quelle de `bottomTabSwipe.ts` (via `SwipeBottomTabs`) :
//  résistance `0.16` aux deux extrémités, seuils `32 / 12 / 380` au relâchement ;
//  ressort `SPRING_CONFIG` (mass 0.7 / stiffness 300 / damping 34) pour un swipe,
//  courbe `PRESS_TIMING_CONFIG` (180 ms, `Easing.out(Easing.cubic)`) pour un
//  appui ; intention d'axe `horizontalGesture.ts` (9 / 4 / ×1.5).
//
//  Approximations SwiftUI (aucun équivalent direct de Reanimated /
//  gesture-handler, cible iOS 16) :
//   • `manualActivation`/`onTouchesMove` → une intention d'axe évaluée dans le
//     premier `onChanged` d'un `DragGesture(minimumDistance: 0)` ;
//   • la vitesse de relâchement est approchée par `predictedEndTranslation` ;
//   • le jeton `SwipeBottomTabGestureHandle` (`#10`) n'est lu qu'au début du
//     geste : le fichier du jeton n'est pas propriété de cette unité, il n'est
//     donc pas rendu observable ici.
//
import SwiftUI
import UIKit

/// Modèle partagé du pager : progression continue du ruban, en pages
/// (`navigationPage`, `App.tsx:689`). Un `ObservableObject` évite de faire
/// re-rendre tout `MainTabView` à chaque image du geste — seule la barre, qui
/// interpole son onglet actif, s'y abonne (`BottomNavigation.tsx:136-148`).
@MainActor
final class DuelloTabPagerModel: ObservableObject {
    /// Position continue du ruban, en pages.
    @Published var progress: CGFloat

    init(progress: CGFloat = 0) {
        self.progress = progress
    }
}

/// Inset bas de la fenêtre clé (`insets.bottom` de `useSafeAreaInsets`,
/// `BottomNavigation.tsx:63`).
enum DuelloWindowInsets {
    static var bottomSafeArea: CGFloat {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return (scenes.compactMap(\.keyWindow).first ?? UIWindow()).safeAreaInsets.bottom
    }
}

/// Décision d'axe du geste (`horizontalGesture.ts`).
private enum DuelloTabSwipeIntent { case pending, horizontal, vertical }

/// Seuils `HORIZONTAL_ACTIVATION_DISTANCE` 9, `VERTICAL_FAILURE_DISTANCE` 4,
/// `HORIZONTAL_DOMINANCE_RATIO` 1.5.
private func duelloTabSwipeIntent(_ translation: CGSize) -> DuelloTabSwipeIntent {
    let distanceX = abs(translation.width)
    let distanceY = abs(translation.height)
    if distanceY >= 4 && distanceY >= distanceX { return .vertical }
    if distanceX >= 9 && distanceX > distanceY * 1.5 { return .horizontal }
    return .pending
}

/// Pager horizontal des trois onglets racine (`BottomTabPager.native.tsx`).
///
/// Trois pages explicites (et non un tableau d'`AnyView`) : l'identité
/// structurelle des écrans lourds est conservée, un geste ne les reconstruit
/// donc pas.
struct DuelloBottomTabPager<P0: View, P1: View, P2: View>: View {
    /// Progression continue publiée vers la barre (`navigationPage`).
    let model: DuelloTabPagerModel
    /// Page validée, source de vérité de `MainTabView` (`page`).
    @Binding var page: Int
    /// Autorise le geste horizontal (`scrollEnabled`, `App.tsx:1639-1644`).
    var scrollEnabled: Bool = true
    /// Notifie la page atteinte par un geste (`onPageSelected`).
    var onPageSelected: (Int) -> Void = { _ in }
    /// Notifie le début/fin d'une interaction (`onInteractionChange`).
    var onInteractionChange: (Bool) -> Void = { _ in }

    private let pageCount = 3

    private let page0: () -> P0
    private let page1: () -> P1
    private let page2: () -> P2

    /// Jeton partagé, exposé aux sous-pagers (`BottomTabSwipeGestureContext`) :
    /// un sous-pager qui suit un mouvement horizontal le revendique et le pager
    /// principal se neutralise alors (`block()`, `BottomTabPager.native.tsx:430`).
    @State private var sharedGesture = SwipeBottomTabGestureHandle()

    /// Position continue du ruban, en pages ; le ruban suit `-position × largeur`.
    @State private var position: CGFloat
    /// Dernière page validée localement (évite un double traitement).
    @State private var settled: Int
    /// Position du ruban (points) au moment où le geste a pris la main.
    @State private var dragOriginX: CGFloat = 0
    /// Page visible au début du geste (`gestureStartPage`).
    @State private var dragStartPage = 0
    @State private var isDragging = false
    @State private var interactionActive = false

    init(
        model: DuelloTabPagerModel,
        page: Binding<Int>,
        initialPage: Int,
        scrollEnabled: Bool = true,
        onPageSelected: @escaping (Int) -> Void = { _ in },
        onInteractionChange: @escaping (Bool) -> Void = { _ in },
        @ViewBuilder page0: @escaping () -> P0,
        @ViewBuilder page1: @escaping () -> P1,
        @ViewBuilder page2: @escaping () -> P2
    ) {
        self.model = model
        self._page = page
        self.scrollEnabled = scrollEnabled
        self.onPageSelected = onPageSelected
        self.onInteractionChange = onInteractionChange
        self.page0 = page0
        self.page1 = page1
        self.page2 = page2
        let clamped = max(0, min(2, initialPage))
        _position = State(initialValue: CGFloat(clamped))
        _settled = State(initialValue: clamped)
    }

    var body: some View {
        GeometryReader { proxy in
            let width = max(1, proxy.size.width)
            ZStack(alignment: .leading) {
                HStack(spacing: 0) {
                    page0().frame(width: width, height: proxy.size.height)
                    page1().frame(width: width, height: proxy.size.height)
                    page2().frame(width: width, height: proxy.size.height)
                }
                .frame(width: width * CGFloat(pageCount), alignment: .leading)
                .offset(x: -position * width)
                // Le contenu cesse d'accepter les appuis pendant la transition
                // (`contentInteractionActive`, `App.tsx:1589`) ; le geste du
                // pager, lui, reste actif.
                .allowsHitTesting(!interactionActive)
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .leading)
            .contentShape(Rectangle())
            .simultaneousGesture(swipeGesture(width: width))
        }
        .clipped()
        .environment(\.swipeBottomTabGesture, sharedGesture)
        .onAppear { model.progress = position }
        .onChange(of: page) { newValue in
            navigate(to: newValue)
        }
    }

    /// Un appui (ou une navigation impérative) désigne une destination : la
    /// barre saute directement dessus (`navigationPage.value = targetPage`),
    /// tandis que le ruban suit la courbe d'appui `PRESS_TIMING_CONFIG`.
    private func navigate(to requested: Int) {
        guard !isDragging else { return }
        let target = max(0, min(pageCount - 1, requested))
        guard target != settled else { return }
        settled = target
        beginInteraction()
        model.progress = CGFloat(target)
        withAnimation(.timingCurve(0.215, 0.61, 0.355, 1, duration: 0.180)) {
            position = CGFloat(target)
        }
        endInteraction(after: 0.180)
    }

    /// Geste de pagination : intention d'axe, suivi du doigt (résistance de
    /// bord), puis ressort de relâchement (`SPRING_CONFIG`).
    private func swipeGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard scrollEnabled else { return }
                if !isDragging {
                    guard sharedGesture.isMainPagerSwipeEnabled else { return }
                    switch duelloTabSwipeIntent(value.translation) {
                    case .vertical, .pending:
                        return
                    case .horizontal:
                        isDragging = true
                        dragOriginX = -position * width
                        dragStartPage = max(0, min(pageCount - 1, Int(position.rounded())))
                        beginInteraction()
                    }
                }
                let dragged = SwipeBottomTabs.pagerDragPosition(
                    gestureOriginX: dragOriginX,
                    translationX: value.translation.width,
                    viewportWidth: width,
                    pageCount: pageCount
                )
                let next = min(CGFloat(pageCount - 1), max(0, -dragged / width))
                position = next
                model.progress = next
            }
            .onEnded { value in
                guard isDragging else { return }
                isDragging = false
                let velocity = value.predictedEndTranslation.width - value.translation.width
                settleGesture(translation: value.translation.width, velocity: velocity)
            }
    }

    /// Relâchement : page finale (`resolveBottomTabGestureTargetIndex`) atteinte
    /// par le ressort `SPRING_CONFIG`.
    private func settleGesture(translation: CGFloat, velocity: CGFloat) {
        let target = SwipeBottomTabs.gestureTargetIndex(
            gestureStartIndex: dragStartPage,
            translationX: translation,
            velocityX: velocity
        )
        let clamped = max(0, min(pageCount - 1, target))
        withAnimation(.interpolatingSpring(mass: 0.7, stiffness: 300, damping: 34)) {
            position = CGFloat(clamped)
            model.progress = CGFloat(clamped)
        }
        if clamped != settled {
            settled = clamped
            onPageSelected(clamped)
        }
        endInteraction(after: 0.45)
    }

    private func beginInteraction() {
        interactionActive = true
        onInteractionChange(true)
    }

    private func endInteraction(after delay: Double) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            interactionActive = false
            onInteractionChange(false)
        }
    }
}
