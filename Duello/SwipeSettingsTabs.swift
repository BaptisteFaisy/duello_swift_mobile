//
//  SwipeSettingsTabs.swift
//  Duello
//
//  Lot 7-G « gestes d'onglets et visibilité de ligne » (préfixe `Swipe`).
//
//  Fichiers source Expo portés :
//    - src/utils/settingsTabSwipe.ts — `SettingsSwipePage`,
//      `SettingsSwipeTarget`, `SETTINGS_SWIPE_PAGES`, `resolveSettingsTabSwipe` ;
//    - src/screens/AccountScreen.tsx — `SETTINGS_SWIPE_PAGES` (374),
//      `SETTINGS_INSTANT_PAGE_TRANSITIONS = [[0, 1]]` (376) et l'index de ruban
//      `settingsTab === 'remote' ? 1 : SETTINGS_SWIPE_PAGES.indexOf(settingsTab)`
//      (3487-3491).
//
//  Les réglages forment un ruban ordonné : « informations », puis le catalogue
//  Premium. Le doigt glissé vers la gauche avance vers la droite, et un retour
//  depuis « informations » ferme les réglages. La page « remote » (connexion au
//  PC, ouverte depuis la fiche photo) reste **hors ruban** : elle ne doit
//  jamais surgir sous le doigt d'un swipe, mais occupe l'emplacement Premium
//  lorsque le pager l'affiche.
//
//  Limite documentée : `velocityX` en points par seconde (pixels par seconde
//  côté source) ; le rendu reste assuré par `Ui2OrderedTabPager` (lot 7-F).
//
import CoreGraphics
import Foundation

/// Décisions du ruban de réglages (`settingsTabSwipe.ts`).
enum SwipeSettingsTabs {

    /// Page de réglages (`SettingsSwipePage`) : `remote` existe hors ruban.
    enum Page: String, CaseIterable, Identifiable {
        case informations
        case remote
        case premium

        var id: String { rawValue }
    }

    /// Ruban ordonné des réglages (`SETTINGS_SWIPE_PAGES`).
    static let pages: [Page] = [.informations, .premium]

    /// Paires qui basculent sans suivre le doigt
    /// (`SETTINGS_INSTANT_PAGE_TRANSITIONS`).
    static let instantTransitions: [SwipeOrderedTabs.InstantTransition] = [
        SwipeOrderedTabs.InstantTransition(from: 0, to: 1)
    ]

    /// Index de la page dans le ruban : « remote » occupe l'emplacement
    /// Premium (`AccountScreen.tsx`, ligne 3487).
    static func pageIndex(for page: Page) -> Int {
        switch page {
        case .informations: return 0
        case .premium, .remote: return 1
        }
    }

    /// Page visée au relâchement : `nil` (ruban qui revient en place), la page
    /// voisine, ou `back` pour fermer les réglages depuis « informations ».
    static func swipe(
        currentPage: Page,
        translationX: CGFloat,
        velocityX: CGFloat
    ) -> SwipeOrderedTabs.PageTarget<Page>? {
        SwipeOrderedTabs.swipe(
            pages: pages,
            current: currentPage,
            translationX: translationX,
            velocityX: velocityX
        )
    }
}
