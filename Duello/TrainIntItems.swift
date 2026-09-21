//
//  TrainIntItems.swift
//  Duello
//
//  Lot 16 « intégration de l'onglet Entraînement » (préfixe `TrainInt`).
//
//  Liste des sujets d'un chapitre ouvert : les fiches d'item portées
//  (`SubjItemCard`), posées dans la grille réutilisable (`TrainGridExerciseGrid`).
//
//  Fichiers source Expo portés :
//    - src/screens/SubjectsScreen.tsx (lignes 9224-9231, 10155) : `FlatList` /
//      `ProgressiveList` des sujets, chaque cellule étant une `ExerciseItemCard`.
//
//  Limite assumée : aucun lecteur d'énoncé n'est porté dans cet écran, la fiche
//  est donc **de consultation** (`isOpenable: false`) — elle montre l'état, la
//  difficulté et l'avancement du sujet, mais son appui n'ouvre rien. Le titre
//  reste affiché (`showsTitle` par défaut), comme la liste de chapitres de la
//  source. La disposition grille de la source n'est pas reprise ici : la grille
//  est utilisée en une seule colonne pleine largeur (`isGrid: false`).
//
//  Cible iOS 16, aucune dépendance externe.
//
import SwiftUI

extension TrainingCatalogView {

    /// Fiches des sujets visibles d'un chapitre, dans l'ordre déjà calculé par
    /// `visibleExercises(_:)`.
    func exerciseList(_ visible: [TrainExercise]) -> some View {
        TrainGridExerciseGrid(count: visible.count, isGrid: false) { index in
            let exercise = visible[index]
            SubjItemCard(
                model: SubjItemCardModel(
                    title: exercise.title,
                    difficulty: exercise.difficulty
                ),
                itemNumber: index + 1,
                progress: progress.items[exercise.id],
                isOpenable: false,
                onOpen: {}
            )
        }
    }
}
