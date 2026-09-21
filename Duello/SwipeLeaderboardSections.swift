//
//  SwipeLeaderboardSections.swift
//  Duello
//
//  Lot 7-G « gestes d'onglets et visibilité de ligne » (préfixe `Swipe`).
//
//  Fichiers source Expo portés :
//    - src/utils/leaderboardSectionSwipe.ts — `LeaderboardSection`,
//      `LeaderboardSwipeTarget`, `LEADERBOARD_SECTIONS`,
//      `resolveLeaderboardSectionSwipe` ;
//    - src/screens/LeaderboardScreen.tsx — `SECTIONS` (« Ligues Elo », « XP »)
//      et le ruban `OrderedTabPager` qui les fait défiler.
//
//  Les sections suivent leur ordre visuel : glisser vers la gauche avance des
//  ligues Elo vers les XP, glisser vers la droite revient aux ligues Elo, et un
//  retour depuis « Ligues Elo » ferme l'écran (`back`).
//
//  Limite documentée : `velocityX` en points par seconde (pixels par seconde
//  côté source) ; le rendu du ruban reste assuré par `Ui2OrderedTabPager` (lot
//  7-F, déjà livré), monté par `SwipeLeaderboardRibbon.swift`.
//
import CoreGraphics
import Foundation

/// Décisions du ruban de classement (`leaderboardSectionSwipe.ts`).
enum SwipeLeaderboardSections {

    /// Section de classement (`LeaderboardSection`).
    enum Section: String, CaseIterable, Identifiable {
        case elo
        case xp

        var id: String { rawValue }

        /// Libellé d'onglet (`SECTIONS` de `LeaderboardScreen.tsx`).
        var label: String {
            switch self {
            case .elo: return "Ligues Elo"
            case .xp: return "XP"
            }
        }
    }

    /// Ruban ordonné des sections (`LEADERBOARD_SECTIONS`).
    static let sections: [Section] = [.elo, .xp]

    /// Section visée au relâchement : `nil` (ruban qui revient en place), la
    /// section voisine, ou `back` pour fermer depuis la première section.
    static func swipe(
        currentSection: Section,
        translationX: CGFloat,
        velocityX: CGFloat
    ) -> SwipeOrderedTabs.PageTarget<Section>? {
        SwipeOrderedTabs.swipe(
            pages: sections,
            current: currentSection,
            translationX: translationX,
            velocityX: velocityX
        )
    }
}
