//
//  TrainGridExerciseGrid.swift
//  Duello
//
//  Grille réutilisable des exercices du catalogue d'entraînement : quatre
//  colonnes égales en mode grille, une seule colonne pleine largeur sinon.
//
//  Fichiers source Expo portés :
//    - src/screens/SubjectsScreen.tsx (lignes 9224-9231) : `FlatList` dont
//      `numColumns` vaut `chapterExerciseColumns` (4) en grille et 1 sinon ;
//      chaque cellule reçoit `trainingGridStyles.chapterExerciseCell`.
//    - src/components/trainingGridStyles.ts : `grid` (`marginHorizontal: -6`) et
//      `chapterExerciseCell` (`paddingHorizontal: 6`).
//    - src/components/ProgressiveList.tsx (lignes 59-80) : grille enveloppée de
//      `grid` avec des cellules `cell`, `gridColumns` paramétrable (4 pour les
//      annales, 3 par défaut).
//
//  La gouttière de 12 pt entre cellules et l'alignement des bords extérieurs
//  viennent du couple `paddingHorizontal: 6` (cellule) / `marginHorizontal: -6`
//  (grille) ; les deux valeurs sont appliquées telles quelles à un `LazyVGrid`
//  à `spacing: 0`, ce qui reproduit exactement la géométrie de la source.
//
//  Cible : iOS 16, aucune dépendance externe.
//
import SwiftUI

/// Grille d'exercices : `LazyVGrid` de `columns` colonnes égales en mode grille,
/// une seule colonne pleine largeur sinon.
///
/// La cellule fournie par l'appelant gère son propre habillage (typiquement
/// `TrainExerciseCard`, qui applique déjà `.duelloCard()`), la grille ne pose
/// que les gouttières et les marges.
struct TrainGridExerciseGrid<Cell: View>: View {
    /// Nombre de cellules (les exercices déjà ordonnés).
    let count: Int
    /// `trainingGrid` : vrai en disposition grille, faux en liste.
    var isGrid: Bool = true
    /// Colonnes du mode grille (`chapterExerciseColumns` par défaut, 3 pour la
    /// disposition `cell`).
    var columns: Int = TrainGridStyles.chapterExerciseColumns
    /// Cellule d'indice donné, dans l'ordre d'affichage.
    @ViewBuilder var cell: (Int) -> Cell

    var body: some View {
        LazyVGrid(columns: gridColumns, spacing: 0) {
            ForEach(indices, id: \.self) { index in
                cell(index)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, isGrid ? TrainGridStyles.cellHorizontalPadding : 0)
            }
        }
        .padding(.horizontal, isGrid ? TrainGridStyles.gridHorizontalMargin : 0)
    }

    // MARK: - Dérivés

    /// Indices des cellules, bornés à zéro (un `count` négatif reste vide).
    private var indices: [Int] {
        Array(0..<max(0, count))
    }

    /// Colonnes effectives : `columns` en grille, une seule sinon.
    private var gridColumns: [GridItem] {
        let effectiveCount = isGrid ? max(1, columns) : 1
        return Array(repeating: GridItem(.flexible(), spacing: 0), count: effectiveCount)
    }
}
