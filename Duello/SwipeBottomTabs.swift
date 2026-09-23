//
//  SwipeBottomTabs.swift
//  Duello
//
//  Lot 7-G « gestes d'onglets et visibilité de ligne » (préfixe `Swipe`).
//
//  Fichiers source Expo portés :
//    - src/utils/bottomTabSwipe.ts — `BOTTOM_TAB_ORDER`,
//      `BOTTOM_TAB_PRESS_TRANSITION_DURATION_MS`,
//      `resolveImmediateBottomTabPreviewIndex`, `resolveBottomTabDragIndex`,
//      `resolveBottomTabPagerProgress`, `bottomTabIndexFromPagerPosition`,
//      `bottomTabPagerDragPosition`, `resolveBottomTabGestureTargetIndex`,
//      `resolveEarlyBottomTabGestureTargetIndex`, `resolveBottomTabPagerSync`,
//      `adjacentBottomTabs` ;
//    - src/components/BottomTabPager.native.tsx — résistance `0.16` au-delà des
//      extrémités, durée d'appui de 180 ms.
//
//  Décisions **pures** du pager d'onglets principal : sensibilité, direction,
//  index visuel et réconciliation d'un rendu tardif. Aucune vue ici : le rendu
//  reste assuré par `Ui2OrderedTabPager` (lot 7-F, déjà livré).
//
//  Limites documentées (aucun compilateur Swift ici, aucun équivalent direct de
//  Reanimated / gesture-handler) :
//   • la vitesse (`velocityX`) est exprimée en points par seconde, comme les
//     pixels par seconde de la source ; SwiftUI l'approxime par
//     `predictedEndTranslation` moins `translation` (voir `Ui2OrderedTabPager`) ;
//   • `pageCount` est passé explicitement : la source le déduit de
//     `BOTTOM_TAB_ORDER` (`SwipeBottomTabs.order.count`) ;
//   • l'onglet « program » reste masqué, comme dans `BOTTOM_TAB_ORDER`.
//
import CoreGraphics
import Foundation

/// Décisions du pager d'onglets principal (`bottomTabSwipe.ts`).
enum SwipeBottomTabs {

    /// Onglet de la barre basse (`BottomTabKey`).
    enum Key: String, CaseIterable, Identifiable {
        case account
        case training
        case challenges

        var id: String { rawValue }

        /// Libellé de la barre, repris de `BottomNavigation.tsx` : `Profil`,
        /// `Entraînement`, `Défis` (et non « Mon compte », qui était une erreur
        /// de portage — la source écrit bien `Profil`).
        var label: String {
            switch self {
            case .account: return "Profil"
            case .training: return "Entraînement"
            case .challenges: return "Défis"
            }
        }
    }

    /// Ordre unique partagé par la barre et le pager (`BOTTOM_TAB_ORDER`).
    static let order: [Key] = [.account, .training, .challenges]

    /// Durée de l'appui dans la barre
    /// (`BOTTOM_TAB_PRESS_TRANSITION_DURATION_MS`).
    static let pressTransitionDurationMS = 180

    /// Sort d'un rendu intermédiaire (`BottomTabPagerSync`).
    enum PagerSync: String {
        case snap
        case preserve
        case acknowledge
    }

    /// Distance qui déclenche un changement de page
    /// (`GESTURE_PAGE_CHANGE_DISTANCE`).
    static let pageChangeDistance: CGFloat = 32
    /// Distance minimale d'un flick (`GESTURE_PAGE_CHANGE_MIN_FLICK_DISTANCE`).
    static let pageChangeMinFlickDistance: CGFloat = 12
    /// Vitesse minimale d'un flick (`GESTURE_PAGE_CHANGE_VELOCITY`).
    static let pageChangeVelocity: CGFloat = 380
    /// Résistance appliquée au-delà des extrémités (`EDGE_RESISTANCE`).
    static let edgeResistance: CGFloat = 0.16

    /// Icône voisine anticipée dès le premier pixel horizontal reconnu
    /// (`resolveImmediateBottomTabPreviewIndex`).
    static func immediatePreviewIndex(
        selectedPage: Int,
        translationX: CGFloat,
        pageCount: Int
    ) -> Int {
        let lastPage = max(0, pageCount - 1)
        let safeSelectedPage = max(0, min(lastPage, selectedPage))
        if abs(translationX) <= 1 { return safeSelectedPage }
        let direction = translationX < 0 ? 1 : -1
        return max(0, min(lastPage, safeSelectedPage + direction))
    }

    /// Onglet le plus proche du centre du rectangle glissé dans la barre
    /// (`resolveBottomTabDragIndex`).
    static func dragIndex(
        indicatorX: CGFloat,
        navigationWidth: CGFloat,
        indicatorWidth: CGFloat
    ) -> Int {
        if navigationWidth <= 0 { return 0 }
        let tabWidth = navigationWidth / CGFloat(order.count)
        let centeredIndex = (indicatorX + indicatorWidth / 2 - tabWidth / 2) / tabWidth
        return max(0, min(order.count - 1, Int(centeredIndex.rounded())))
    }

    /// Progression continue du ruban dans la barre
    /// (`resolveBottomTabPagerProgress`).
    static func pagerProgress(
        pagerPositionX: CGFloat,
        viewportWidth: CGFloat,
        pageCount: Int
    ) -> CGFloat {
        if viewportWidth <= 0 { return 0 }
        let lastPage = CGFloat(max(0, pageCount - 1))
        return max(0, min(lastPage, -pagerPositionX / viewportWidth))
    }

    /// Page visuellement la plus proche, y compris pendant un ressort
    /// (`bottomTabIndexFromPagerPosition`).
    static func indexFromPagerPosition(
        pagerPositionX: CGFloat,
        viewportWidth: CGFloat,
        pageCount: Int
    ) -> Int {
        if viewportWidth <= 0 { return 0 }
        let index = (-pagerPositionX / viewportWidth).rounded()
        return max(0, min(max(0, pageCount - 1), Int(index)))
    }

    /// Position du ruban pendant le geste, avec résistance aux deux extrémités
    /// (`bottomTabPagerDragPosition`).
    static func pagerDragPosition(
        gestureOriginX: CGFloat,
        translationX: CGFloat,
        viewportWidth: CGFloat,
        pageCount: Int
    ) -> CGFloat {
        let firstPosition: CGFloat = 0
        let lastPosition = -CGFloat(max(0, pageCount - 1)) * viewportWidth
        let rawPosition = gestureOriginX + translationX
        if rawPosition > firstPosition {
            return firstPosition + (rawPosition - firstPosition) * edgeResistance
        }
        if rawPosition < lastPosition {
            return lastPosition + (rawPosition - lastPosition) * edgeResistance
        }
        return rawPosition
    }

    /// Page finale au relâchement (`resolveBottomTabGestureTargetIndex`) :
    /// un glissement franc, ou un flick court mais rapide.
    static func gestureTargetIndex(
        gestureStartIndex: Int,
        translationX: CGFloat,
        velocityX: CGFloat
    ) -> Int {
        let distance = abs(translationX)
        let shouldChangePage = distance > pageChangeDistance
            || (distance > pageChangeMinFlickDistance && abs(velocityX) > pageChangeVelocity)
        if !shouldChangePage { return gestureStartIndex }

        let swipeDirection = abs(translationX) > 2 ? translationX : velocityX
        let direction = swipeDirection < 0 ? 1 : -1
        return max(0, min(order.count - 1, gestureStartIndex + direction))
    }

    /// Transition native lancée avant le relâchement du doigt
    /// (`resolveEarlyBottomTabGestureTargetIndex`).
    static func earlyGestureTargetIndex(
        gestureStartIndex: Int,
        translationX: CGFloat
    ) -> Int {
        if abs(translationX) < 20 { return gestureStartIndex }
        let direction = translationX < 0 ? 1 : -1
        return max(0, min(order.count - 1, gestureStartIndex + direction))
    }

    /// Réconciliation d'un rendu React avec le ruban animé
    /// (`resolveBottomTabPagerSync`) : un rendu intermédiaire ne doit jamais
    /// annuler le ressort déjà lancé vers la dernière destination.
    static func pagerSync(activeIndex: Int, committedSwipeIndex: Int) -> PagerSync {
        if committedSwipeIndex < 0 { return .snap }
        return committedSwipeIndex == activeIndex ? .acknowledge : .preserve
    }

    /// Onglets à préparer autour de l'écran visible
    /// (`adjacentBottomTabs`), dans l'ordre du pager.
    static func adjacentTabs(active: Key) -> [Key] {
        guard let activeIndex = order.firstIndex(of: active) else { return [] }
        return [activeIndex - 1, activeIndex + 1].compactMap { index in
            order.indices.contains(index) ? order[index] : nil
        }
    }
}
