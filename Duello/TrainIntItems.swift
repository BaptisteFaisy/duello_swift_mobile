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
//  V1 2026-09-26 (U06#1) : la fiche ouvre l'énoncé (`isOpenable: true`,
//  `onOpen` réel vers `openTrainingReader`, qui pose `readerEntry` et monte
//  `AnnReaderView` en plein écran). Le titre reste affiché (`showsTitle` par
//  défaut), comme la liste de chapitres de la source. La disposition grille de
//  la source n'est pas reprise ici : la grille est utilisée en une seule
//  colonne pleine largeur (`isGrid: false`).
//
//  Dépendance documentée (seam honnête) : le lecteur d'énoncé propre à l'unité
//  U18 n'est pas porté ; la route exacte (`onOpenSubject` →
//  `openTrainingItemInstantly` → `openAnnaleItem`) est câblée vers le lecteur
//  d'annale déjà porté (`AnnReaderView`, `AnnalesScreen.swift`), alimenté par
//  l'énoncé servi (`TrainExercise.statement`) et le corrigé (`solution`).
//
//  La signature `exerciseList(_:chapter:)` et le contexte de prérequis de main
//  sont conservés ; seule l'ouverture de la fiche change.
//
//  Les prérequis d'une fiche (`missingPrerequisites`, `startedPrerequisites`,
//  comptes de questions) sont construits par `TrainIntItems+Prereq.swift`.
//
//  Cible iOS 16, aucune dépendance externe.
//
import SwiftUI

extension TrainingCatalogView {

    /// Fiches des sujets visibles d'un chapitre, dans l'ordre déjà calculé par
    /// `visibleExercises(_:)`. Le chapitre ouvert porte le contexte des
    /// prérequis (noms de chapitres et statuts de cours). L'appui ouvre
    /// l'énoncé (`openSubject`) : jamais une confirmation à franchir.
    func exerciseList(_ visible: [TrainExercise], chapter: TrackChapter) -> some View {
        let context = prerequisiteCardContext()
        return TrainGridExerciseGrid(count: visible.count, isGrid: false) { index in
            let exercise = visible[index]
            SubjItemCard(
                model: itemCardModel(exercise, chapter: chapter, context: context),
                itemNumber: index + 1,
                progress: progress.items[exercise.id],
                isOpenable: true,
                onOpen: { openTrainingReader(exercise) }
            )
        }
    }

    /// `openAnnaleItem` : pose l'énoncé à lire (`readerEntry`), que la feuille
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

/// Adapte un sujet servi (`TrainExercise`) vers le lecteur (`AnnReaderView`) :
/// l'énoncé et le corrigé servis alimentent l'entrée de lecture.
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
