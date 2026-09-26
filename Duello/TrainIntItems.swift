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
//    - src/screens/SubjectsScreen.tsx (lignes 3185, 6681, 6243, 9156) :
//      `onOpenSubject` → `openTrainingItemInstantly` → `openAnnaleItem` → `<AnnaleViewer>`.
//
//  V1 2026-09-26 (U06#1) : la fiche ouvre l'énoncé (`isOpenable: true`,
//  `onOpen` réel vers `openTrainingReader`, qui pose `readerEntry` et monte
//  `AnnReaderView` en plein écran). Le titre reste affiché (`showsTitle` par
//  défaut), comme la liste de chapitres de la source (U06 P1#6, V2). La
//  disposition grille de la source n'est pas reprise ici : la grille est
//  utilisée en une seule colonne pleine largeur (`isGrid: false`).
//
//  Dépendance documentée (SPEC-V1, cadrage ; seam honnête) : le lecteur
//  d'énoncé d'exercice/colle propre à l'unité U18 n'est pas porté. La route
//  exacte est câblée (`onOpenSubject` → `openTrainingItemInstantly` →
//  `openAnnaleItem`) et pointe vers le lecteur déjà porté (`AnnReaderView`,
//  `AnnalesScreen.swift`) alimenté par l'énoncé servi (`TrainExercise.statement`)
//  et le corrigé (`solution`). Quand U18 livrera son lecteur, seule la
//  destination change : les appelants (`exerciseList`, `resume`) restent.
//
//  Cible iOS 16, aucune dépendance externe.
//
import SwiftUI

extension TrainingCatalogView {

    /// Fiches des sujets visibles d'un chapitre, dans l'ordre déjà calculé par
    /// `visibleExercises(_:)`. L'appui ouvre l'énoncé (`openSubject`) : jamais
    /// une confirmation à franchir.
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
                isOpenable: true,
                onOpen: { openTrainingReader(exercise) }
            )
        }
    }

    /// `openAnnaleItem` : pose l'énoncé à lire (`openAnnale`), que la feuille
    /// de lecture (`readerCover`) monte en plein écran.
    private func openTrainingReader(_ exercise: TrainExercise) {
        readerEntry = TrainReaderLink.entry(
            exercise,
            mode: activeMode,
            chapterName: chapterName(of: exercise.chapterId)
        )
    }

    /// Nom du chapitre d'un sujet, pour l'adaptation vers le lecteur.
    private func chapterName(of chapterId: String) -> String {
        subject.chapters.first { $0.id == chapterId }?.name ?? chapterId
    }
}

/// Adapte un sujet servi (`TrainExercise`) vers le lecteur (`AnnReaderView`)
/// : l'énoncé et le corrigé servis alimentent l'entrée de lecture.
enum TrainReaderLink {
    /// Entrée de lecture d'un sujet (`ChapterItem` → `openAnnaleItem`).
    static func entry(_ exercise: TrainExercise, mode: SubjTrainingMode, chapterName: String) -> AnnEntry {
        AnnEntry(
            id: exercise.id,
            title: exercise.title,
            source: chapterName,
            theme: nil,
            difficulty: exercise.difficulty ?? 3,
            statement: exercise.statement,
            solution: exercise.solution,
            questions: [AnnQuestion(id: "q1", label: "1 - Sujet")]
        )
    }
}
