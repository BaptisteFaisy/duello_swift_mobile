//
//  SwipeOrderedTabs.swift
//  Duello
//
//  Lot 7-G « gestes d'onglets et visibilité de ligne » (préfixe `Swipe`).
//
//  Fichier source Expo porté :
//    - src/utils/orderedTabSwipe.ts — `OrderedTabSwipeTarget`,
//      `OrderedTabSwipeIndexTarget`, `OrderedTabInstantTransition`,
//      `isOrderedTabTransitionInstant`, `resolveOrderedTabSwipeIndex`,
//      `resolveOrderedTabSwipe`, seuils `TAB_SWIPE_DISTANCE` (32),
//      `TAB_SWIPE_MIN_FLICK_DISTANCE` (12), `TAB_SWIPE_VELOCITY` (380).
//
//  Résolveur commun des sous-pages à onglets : glisser vers la gauche avance
//  d'une page, glisser vers la droite recule d'une page et **ferme** la
//  sous-page depuis son début (`back`).
//
//  Limites documentées : `velocityX` est en points par seconde (pixels par
//  seconde côté source, gesture-handler) ; SwiftUI l'approxime par
//  `predictedEndTranslation` (voir `Ui2OrderedTabPager`). Le rendu du ruban
//  reste assuré par `Ui2OrderedTabPager` (lot 7-F) — ce fichier ne contient
//  que la décision.
//
import CoreGraphics
import Foundation

/// Décisions du swipe des sous-pages ordonnées (`orderedTabSwipe.ts`).
enum SwipeOrderedTabs {

    /// Cible indexée (`OrderedTabSwipeIndexTarget`).
    enum IndexTarget: Equatable {
        case page(Int)
        case back
    }

    /// Cible nommée (`OrderedTabSwipeTarget<Page>`) : la page voisine, ou la
    /// fermeture de la sous-page.
    enum PageTarget<Page: Equatable>: Equatable {
        case page(Page)
        case back
    }

    /// Paire de pages qui bascule sans suivre le doigt
    /// (`OrderedTabInstantTransition`).
    struct InstantTransition: Equatable {
        /// Première page de la paire.
        let from: Int
        /// Seconde page de la paire.
        let to: Int
    }

    /// Distance qui déclenche un changement de page (`TAB_SWIPE_DISTANCE`).
    static let swipeDistance: CGFloat = 32
    /// Distance minimale d'un flick (`TAB_SWIPE_MIN_FLICK_DISTANCE`).
    static let minFlickDistance: CGFloat = 12
    /// Vitesse minimale d'un flick (`TAB_SWIPE_VELOCITY`).
    static let swipeVelocity: CGFloat = 380

    /// Indique si une paire de pages bascule sans déplacement progressif
    /// (`isOrderedTabTransitionInstant`) ; la paire est symétrique.
    static func isInstantTransition(
        _ transitions: [InstantTransition],
        fromPage: Int,
        toPage: Int
    ) -> Bool {
        if fromPage == toPage { return false }
        return transitions.contains { pair in
            (pair.from == fromPage && pair.to == toPage)
                || (pair.from == toPage && pair.to == fromPage)
        }
    }

    /// Page visée au relâchement, version indexée
    /// (`resolveOrderedTabSwipeIndex`) : `nil` = le ruban revient en place.
    static func swipeIndex(
        pageCount: Int,
        currentIndex: Int,
        translationX: CGFloat,
        velocityX: CGFloat
    ) -> IndexTarget? {
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

    /// Même décision, exprimée avec les noms de pages
    /// (`resolveOrderedTabSwipe`) : `nil` si la page courante n'est pas dans le
    /// ruban (page ouverte hors ruban) ou si la cible est hors bornes.
    static func swipe<Page: Equatable>(
        pages: [Page],
        current: Page,
        translationX: CGFloat,
        velocityX: CGFloat
    ) -> PageTarget<Page>? {
        guard let currentIndex = pages.firstIndex(of: current) else { return nil }
        let target = swipeIndex(
            pageCount: pages.count,
            currentIndex: currentIndex,
            translationX: translationX,
            velocityX: velocityX
        )
        guard let target else { return nil }

        switch target {
        case .back:
            return .back
        case .page(let index):
            guard pages.indices.contains(index) else { return nil }
            return .page(pages[index])
        }
    }
}
