//
//  AcctSearchConstants.swift
//  Duello
//
//  Seuils de la recherche de personnes de l'écran Compte — port des constantes
//  de `src/screens/AccountScreen.tsx` (l. 237-240) : la liste garde cinq
//  personnes visibles et fait défiler les suivantes, chaque ligne mesurant
//  62 points, et la saisie est regroupée par un debounce de 140 ms.
//
//  Aucune vue ici : ces valeurs sont figées pour le lot de l'annuaire
//  (recherche, pagination et hauteur des résultats).
//
//  Cible : iOS 16.
//
import CoreGraphics

/// Seuils de la recherche d'annuaire (`AccountScreen.tsx`).
enum AcctSearchConstants {
    /// `SEARCH_VISIBLE_RESULT_COUNT` : personnes visibles avant défilement.
    static let visibleResultCount = 5

    /// `SEARCH_RESULT_HEIGHT` : hauteur d'une ligne de résultat, en points.
    static let resultHeight: CGFloat = 62

    /// `SEARCH_DEBOUNCE_MS` : regroupement de la saisie, en millisecondes.
    static let debounceMilliseconds = 140

    /// `maxHeight: SEARCH_RESULT_HEIGHT * SEARCH_VISIBLE_RESULT_COUNT` :
    /// hauteur maximale de la liste défilante des résultats.
    static var resultsMaxHeight: CGFloat {
        resultHeight * CGFloat(visibleResultCount)
    }

    /// `distanceFromBottom <= SEARCH_RESULT_HEIGHT * 2` : approche du bas qui
    /// déclenche le chargement de la page suivante de l'annuaire.
    static var loadMoreThreshold: CGFloat { resultHeight * 2 }

    /// Le debounce exprimé en secondes, pour `Task.sleep`.
    static var debounceSeconds: Double { Double(debounceMilliseconds) / 1000 }
}

/// Assets de marque repris de l'écran Compte (`AccountScreen.tsx`, l. 97-99).
///
/// Regroupés ici faute de fichier dédié dans ce lot : la constante n'est ni une
/// mesure de recherche ni une vue, mais un actif partagé par l'écran Compte.
enum AcctBrandAssets {
    /// `DUELLO_CUBE_LOGO_SOURCE` : le cube de Duello (arêtes noires sur fond
    /// blanc), embarqué par Expo via `require('../../assets/duello-logo.png')`
    /// et affiché devant la ligne « Duello » du menu des réglages.
    ///
    /// L'app Swift n'embarque pas ce PNG : le catalogue d'assets ne fournit que
    /// `DuelloLogo` (variante blanche). La constante nomme donc le logo de
    /// marque disponible ; le rendu (et un éventuel repli) appartient à
    /// l'appelant, et non à ce fichier.
    static let cubeLogoAssetName = "DuelloLogo"
}
