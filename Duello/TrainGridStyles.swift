//
//  TrainGridStyles.swift
//  Duello
//
//  Constantes de la grille d'exercices du catalogue d'entraînement, reprises à
//  l'identique de `src/components/trainingGridStyles.ts` et consommées par
//  `src/screens/SubjectsScreen.tsx` (mode grille `trainingGrid`) ainsi que par
//  `src/components/ProgressiveList.tsx`.
//
//  Fichiers source Expo portés :
//    - src/components/trainingGridStyles.ts
//        `chapterExerciseColumns`, `trainingGridStyles` → `chapterExerciseCell`,
//        `filters`, `grid`, `cell`, `heading`.
//    - src/screens/SubjectsScreen.tsx (lignes 213, 3703, 9224-9231, 10022)
//        usage du mode grille : `numColumns={chapterExerciseColumns}` (4) sinon 1,
//        `chapterExerciseCell` sur chaque cellule, `filters` sur la ligne de
//        filtres, et `key` de la `FlatList` (« training-grid » / « training-list »).
//    - src/components/ProgressiveList.tsx (lignes 59-80)
//        disposition `grid` + cellules `cell` (trois colonnes), `gridColumns`
//        paramétrable.
//
//  Disposition : chaque cellule porte `paddingHorizontal: 6` et la grille porte
//  `marginHorizontal: -6`. La gouttière entre cellules vaut donc 12 pt et les
//  bords extérieurs restent alignés sur le conteneur. `TrainGridExerciseGrid`
//  reproduit ces deux valeurs telles quelles via `LazyVGrid`.
//
//  La source ne définit aucun libellé visible pour le mode grille ; les seules
//  chaînes littérales liées à la grille sont les `key` de la `FlatList`, reprises
//  ici sous `gridIdentity` / `listIdentity`.
//
//  Cible : iOS 16, aucune dépendance externe.
//
import SwiftUI

/// Feuille de style de la grille d'entraînement (`trainingGridStyles`).
///
/// Les valeurs sont figées : la source les calcule une seule fois
/// (`StyleSheet.create`) et la grille n'a pas de variante responsive.
enum TrainGridStyles {

    // MARK: - Colonnes

    /// `chapterExerciseColumns` : nombre de colonnes du mode grille.
    static let chapterExerciseColumns = 4

    /// Nombre de colonnes de la disposition par domaines (`chapterColumns`).
    static let threeColumnCellCount = 3

    // MARK: - Largeurs de cellule

    /// Largeur de `chapterExerciseCell` : `100 / chapterExerciseColumns` → 25 %.
    static let chapterExerciseCellFraction: CGFloat = 1.0 / CGFloat(chapterExerciseColumns)

    /// Largeur de `cell` : `'33.333333%'` (trois colonnes égales).
    static let threeColumnCellFraction: CGFloat = 33.333333 / 100

    // MARK: - Paddings et marges

    /// `paddingHorizontal: 6` des cellules (`chapterExerciseCell`, `cell`).
    static let cellHorizontalPadding: CGFloat = 6

    /// `paddingHorizontal: 6` du titre pleine largeur (`heading`).
    static let headingHorizontalPadding: CGFloat = 6

    /// `marginHorizontal: -6` de la grille (`grid`) : compense le padding des
    /// cellules pour aligner les bords extérieurs sur le conteneur.
    static let gridHorizontalMargin: CGFloat = -6

    /// Gouttière effective entre deux cellules : deux paddings de 6 pt.
    static var columnGutter: CGFloat { cellHorizontalPadding * 2 }

    // MARK: - Ligne de filtres

    /// `alignItems: 'flex-end'` de `filters` : les menus s'alignent en bas.
    static let filterRowAlignment: VerticalAlignment = .bottom

    /// `flexWrap: 'nowrap'` de `filters` : une seule ligne, jamais de retour.
    /// Un `HStack` ne revient jamais à la ligne : la constante documente
    /// l'intention et sert de garde-fou si un jour la ligne doit se replier.
    static let filterRowWraps = false

    // MARK: - Identités de liste

    /// `key` de la `FlatList` en mode grille (`trainingGrid` vrai).
    static let gridIdentity = "training-grid"

    /// `key` de la `FlatList` en mode liste (`trainingGrid` faux).
    static let listIdentity = "training-list"
}
