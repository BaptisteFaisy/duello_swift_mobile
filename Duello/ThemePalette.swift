//
//  ThemePalette.swift
//  Duello
//
//  Complément de palette : les entrées de `expo_ref/src/theme.ts` que
//  `Theme.swift` ne portait pas encore. Aucune valeur n'est inventée — chacune
//  est reprise **à l'identique** de `colors`, `chartSeries`, `radii` et
//  `cardShadow` du thème Expo, avec la clé source en commentaire.
//
//  Écrit en extension, hors de `Theme.swift` (fichier partagé par plusieurs
//  lots) : le type `Theme` reste unique, la palette devient complète.
//
//  Cible : iOS 16, aucune dépendance externe.
//
import SwiftUI

extension Theme {
    // MARK: - Couleurs signalétiques absentes de `Theme.swift`

    /// `mastery` de `theme.ts` : vert commun aux indicateurs de maîtrise et aux
    /// réussites en mathématiques.
    static let masteryHex = 0x22C55E
    static var mastery: Color { Color(hex: masteryHex) }

    /// `online` de `theme.ts` : même vert que la réussite, pour la pastille de
    /// présence d'un compte connecté.
    static var online: Color { mastery }

    /// `mutedSurfaceText` : texte des commandes sur fond gris. La valeur
    /// `default` du thème Expo (`Platform.select`) vaut `#555B58` sur mobile ;
    /// le noir franc ne concerne que le Web.
    static let mutedSurfaceTextHex = 0x555B58
    static var mutedSurfaceText: Color { Color(hex: mutedSurfaceTextHex) }

    /// `likeLight` : fond des avertissements et des mentions « je n'aime pas ».
    static let likeLightHex = 0xFDECEC
    static var likeLight: Color { Color(hex: likeLightHex) }

    /// `prerequisitesReady` : prérequis acquis.
    static let prerequisitesReadyHex = 0x15803D
    static var prerequisitesReady: Color { Color(hex: prerequisitesReadyHex) }

    /// `prerequisitesReadyLight` : fond du statut « acquis ».
    static let prerequisitesReadyLightHex = 0xE7F7EC
    static var prerequisitesReadyLight: Color { Color(hex: prerequisitesReadyLightHex) }

    /// `prerequisitesMissing` : prérequis incomplet.
    static let prerequisitesMissingHex = 0xB42318
    static var prerequisitesMissing: Color { Color(hex: prerequisitesMissingHex) }

    /// `prerequisitesMissingLight` : fond du statut « incomplet ».
    static let prerequisitesMissingLightHex = 0xFDECEC
    static var prerequisitesMissingLight: Color { Color(hex: prerequisitesMissingLightHex) }

    /// `white` de `theme.ts`.
    static let whiteHex = 0xFFFFFF
    static var white: Color { Color(hex: whiteHex) }

    /// `danger` de `theme.ts` : l'encre, comme `primary` — l'interface reste
    /// sans teinte.
    static var danger: Color { ink }

    // MARK: - Alias du thème Expo (mêmes valeurs, autres noms)

    /// `accent` de `theme.ts` (= `ink`).
    static var accent: Color { ink }
    /// `accentLight` de `theme.ts` (= `primaryLight`).
    static var accentLight: Color { primaryLight }
    /// `lime` de `theme.ts` (= `primaryLight`).
    static var lime: Color { primaryLight }
    /// `yellow` de `theme.ts` (= `surfaceMuted`).
    static var yellow: Color { surfaceMuted }
    /// `lavender` de `theme.ts` (= `surfaceMuted`).
    static var lavender: Color { surfaceMuted }

    /// `chartSeries` de `theme.ts` : séries d'un graphique empilé, dans un ordre
    /// fixe. Quatre pas de clair-obscur au plus, jamais de teinte.
    static let chartSeriesHexes: [Int] = [0x0A0D0C, 0x4B524F, 0x8B918E, 0xC6CBC9]
    static var chartSeries: [Color] { chartSeriesHexes.map { Color(hex: $0) } }

    /// `chartSeries` d'index donné, en repli sur la dernière nuance.
    static func chartSeriesColor(_ index: Int) -> Color {
        let hexes = chartSeriesHexes
        guard !hexes.isEmpty else { return ink }
        let clamped = min(max(index, 0), hexes.count - 1)
        return Color(hex: hexes[clamped])
    }

    // MARK: - Mesures

    /// `radii.pill` de `theme.ts` : rayon d'une pastille, jamais arrondi à la
    /// moitié d'une hauteur réelle.
    static let radiusPill: CGFloat = 999

    // MARK: - Ombre de carte

    /// `cardShadow` iOS de `theme.ts` : `#0A0D0C` à 4 %, décalage vertical de
    /// 2 pt, rayon de flou 8 pt.
    static let cardShadowHex = 0x0A0D0C
    static let cardShadowOpacity: Double = 0.04
    static let cardShadowRadius: CGFloat = 8
    static let cardShadowOffsetY: CGFloat = 2
    static var cardShadowColor: Color { Color(hex: cardShadowHex).opacity(cardShadowOpacity) }
}

extension View {
    /// Ombre de carte du thème Expo (`cardShadow` iOS), pour les surfaces qui ne
    /// passent pas par `.duelloCard()`.
    func duelloShadow() -> some View {
        shadow(
            color: Theme.cardShadowColor,
            radius: Theme.cardShadowRadius,
            x: 0,
            y: Theme.cardShadowOffsetY
        )
    }
}
