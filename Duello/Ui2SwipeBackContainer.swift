//
//  Ui2SwipeBackContainer.swift
//  Duello
//
//  Lot 7-F « UI générique » (préfixe `Ui2`).
//
//  Fichier source Expo porté :
//    - src/components/SwipeBackScreen.tsx (`SwipeBackScreen`,
//      `keepSinglePageSelected`)
//
//  Ajoute le retour horizontal commun à une sous-page unique. Le pager laisse le
//  défilement vertical à son contenu et ferme la page après un glissement vers
//  la droite, comme le ferait son chevron. Cible iOS 16.
//
import SwiftUI

/// Retour horizontal d'une sous-page unique (`SwipeBackScreen.tsx`).
struct Ui2SwipeBackContainer<Content: View>: View {
    /// Ferme la page (`onBack` de la source).
    let onBack: () -> Void
    @ViewBuilder var content: () -> Content

    var body: some View {
        Ui2OrderedTabPager(
            pageCount: 1,
            page: 0,
            onPageSelected: { _ in },
            onBack: onBack
        ) {
            content()
        }
    }
}
