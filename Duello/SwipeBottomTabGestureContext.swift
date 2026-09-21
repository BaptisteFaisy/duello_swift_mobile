//
//  SwipeBottomTabGestureContext.swift
//  Duello
//
//  Lot 7-G « gestes d'onglets et visibilité de ligne » (préfixe `Swipe`).
//
//  Fichier source Expo porté :
//    - src/components/BottomTabSwipeGestureContext.ts — `createContext(null)` :
//      le geste du pager principal est exposé aux sous-pagers « afin qu'ils
//      puissent le bloquer nativement lorsqu'un même mouvement horizontal les
//      traverse ».
//
//  React transmet un objet de geste (gesture-handler) par contexte ; SwiftUI
//  n'a pas d'équivalent direct. Le portage expose donc un **jeton** dans
//  l'environnement : le sous-pager le revendique tant qu'il suit un mouvement
//  horizontal, et le pager principal se neutralise pendant ce temps
//  (`swipeEnabled` de `Ui2OrderedTabPager`, lot 7-F).
//
//  Limite documentée : la revendication est un drapeau de conversation, pas un
//  geste partagé ; elle ne remplace pas `requireExternalGestureToFail` de
//  gesture-handler (aucune API SwiftUI équivalente sur iOS 16).
//
import SwiftUI

/// Jeton partagé, équivalent de `BottomTabSwipeGestureContext`.
final class SwipeBottomTabGestureHandle {

    /// Un sous-pager suit un mouvement horizontal en cours.
    private(set) var isClaimedByNestedPager = false

    /// Le pager principal peut suivre le doigt tant que personne ne l'a pris.
    var isMainPagerSwipeEnabled: Bool { !isClaimedByNestedPager }

    /// Le sous-pager revendique le mouvement (`block()` de la source).
    func claimByNestedPager() {
        isClaimedByNestedPager = true
    }

    /// Le sous-pager relâche le mouvement (`release()` de la source).
    func releaseNestedPager() {
        isClaimedByNestedPager = false
    }
}

/// Clé d'environnement du geste partagé.
private struct SwipeBottomTabGestureKey: EnvironmentKey {
    static let defaultValue: SwipeBottomTabGestureHandle? = nil
}

extension EnvironmentValues {
    /// Geste du pager principal, exposé aux sous-pagers
    /// (`BottomTabSwipeGestureContext`) ; `nil` hors du pager.
    var swipeBottomTabGesture: SwipeBottomTabGestureHandle? {
        get { self[SwipeBottomTabGestureKey.self] }
        set { self[SwipeBottomTabGestureKey.self] = newValue }
    }
}
