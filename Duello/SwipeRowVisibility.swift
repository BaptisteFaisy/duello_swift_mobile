//
//  SwipeRowVisibility.swift
//  Duello
//
//  Lot 7-G « gestes d'onglets et visibilité de ligne » (préfixe `Swipe`).
//
//  Fichiers source Expo portés :
//    - src/hooks/useLeaderboardCurrentRowVisibility.ts — `VISIBILITY_INSET` (8),
//      `measureInWindow` (ligne et écran mesurés dans le même repère) et la
//      règle `rowY < screenY + screenHeight - INSET && rowY + rowHeight >
//      screenY + INSET` ;
//    - src/screens/RankingsScreen.tsx (472) et WeeklyXpRankingScreen.tsx (196) —
//      `showCurrentUserDock = loadState === 'ready' && Boolean(currentEntry) &&
//      !currentRowVisible`.
//
//  Décisions **pures** de visibilité : la ligne du joueur courant est-elle à
//  l'écran, et faut-il ancrer sa fiche en bas de l'écran ? Aucune mesure ici :
//  le suivi SwiftUI vit dans `SwipeRowVisibilityTracking.swift`.
//
//  Limites documentées : la source mesure à la fenêtre (`measureInWindow`) ;
//  le portage utilise le repère `.global` de SwiftUI, équivalent pour une app
//  plein écran. Une mesure indisponible laisse la ligne visible, comme la
//  source (`if (!screen || !row) setCurrentRowVisible(true)`).
//
import CoreGraphics
import Foundation

/// Décisions de visibilité de la ligne courante
/// (`useLeaderboardCurrentRowVisibility.ts`).
enum SwipeRowVisibility {

    /// Marge de sécurité en haut et en bas (`VISIBILITY_INSET`).
    static let inset: CGFloat = 8

    /// Visibilité par défaut quand aucune mesure n'est disponible.
    static let defaultVisible = true

    /// Visibilité à partir des ordonnées mesurées dans le même repère
    /// (`measureInWindow` de la ligne et de l'écran).
    static func isVisible(
        rowY: CGFloat,
        rowHeight: CGFloat,
        screenY: CGFloat,
        screenHeight: CGFloat
    ) -> Bool {
        rowY < screenY + screenHeight - inset && rowY + rowHeight > screenY + inset
    }

    /// Même règle, à partir des rectangles `CGRect` (repère `.global`).
    static func isVisible(row: CGRect, screen: CGRect) -> Bool {
        isVisible(
            rowY: row.minY,
            rowHeight: row.height,
            screenY: screen.minY,
            screenHeight: screen.height
        )
    }

    /// Ancre du joueur courant : fiche épinglée dès que sa ligne quitte
    /// l'écran (`showCurrentUserDock` des deux écrans de classement).
    static func shouldShowCurrentUserDock(
        loadStateReady: Bool,
        hasCurrentEntry: Bool,
        isRowVisible: Bool
    ) -> Bool {
        loadStateReady && hasCurrentEntry && !isRowVisible
    }
}
