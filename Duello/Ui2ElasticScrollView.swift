//
//  Ui2ElasticScrollView.swift
//  Duello
//
//  Lot 7-F « UI générique » (préfixe `Ui2`).
//
//  Fichier source Expo porté :
//    - src/components/ElasticScrollView.tsx (`ElasticScrollView`)
//
//  Défilement commun aux pages : le contenu occupe au moins la hauteur visible
//  et conserve l'élasticité verticale même lorsqu'il est trop court pour
//  défiler. Cible iOS 16.
//
//  Écarts assumés : `alwaysBounceVertical`, `bounces` et `overScrollMode` de la
//  source sont les valeurs par défaut des `ScrollView` iOS (rebond natif
//  toujours actif, résistance de bord gérée par le système) : aucune option à
//  reproduire ici.
//
import SwiftUI

/// Défilement commun aux pages (`ElasticScrollView.tsx`).
///
/// En vertical, le contenu est étiré à au moins la hauteur visible
/// (`flexGrow: 1` de la source) : une page courte garde ainsi son rebond.
struct Ui2ElasticScrollView<Content: View>: View {
    /// Défilement horizontal au lieu de vertical (comme `horizontal` de la source).
    var horizontal: Bool = false
    /// Affiche les indicateurs de défilement (masqués par défaut dans Duello).
    var showsIndicators: Bool = false
    @ViewBuilder var content: () -> Content

    var body: some View {
        if horizontal {
            ScrollView(.horizontal, showsIndicators: showsIndicators) {
                content()
            }
        } else {
            GeometryReader { proxy in
                ScrollView(.vertical, showsIndicators: showsIndicators) {
                    content()
                        .frame(
                            maxWidth: .infinity,
                            minHeight: proxy.size.height,
                            alignment: .top
                        )
                }
            }
        }
    }
}
