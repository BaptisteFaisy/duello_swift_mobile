//
//  TrainIntProgram.swift
//  Duello
//
//  Lot 16 « intégration de l'onglet Entraînement » (préfixe `TrainInt`).
//
//  Passerelles entre le programme porté (`TrackSubject` / `TrackChapter`, de
//  `Programs.swift`) et les types attendus par les composants de l'écran
//  Matières (`SubjSubject` / `SubjChapter`, de `SubjProgramMerge.swift`), plus
//  le mode d'entraînement par défaut d'une matière.
//
//  Fichiers source Expo portés :
//    - src/screens/SubjectsScreen.tsx : `resolveTrainingMode` (lignes 7195-7207,
//      mode par défaut « exercices », « dissertations » pour ESH / HGG) ;
//    - src/utils/subjectProgress.ts : forme d'un chapitre fusionné.
//
//  Aucune donnée n'est inventée : les prérequis et le niveau de maîtrise du
//  programme Swift (`TrackChapter`) ne sont pas encore portés, la fusion les
//  laisse donc vides, comme `SubjProgramMerge.mergeWithProgram`.
//
//  Cible iOS 16, aucune dépendance externe.
//
import Foundation

/// Fabrique les vues de programme attendues par les lignes de chapitre de
/// l'écran Matières, et résout le mode ouvert au lancement.
enum TrainIntProgram {
    /// Un chapitre de programme dans la forme lue par `SubjChapterRow` /
    /// `SubjCourseChapterRow` : le statut de cours vient du store local
    /// (`TrainCourseStatusStore`), faute de store partagé pour ce champ.
    static func subjChapter(
        _ chapter: TrackChapter,
        status: TrainCourseStatus
    ) -> SubjChapter {
        SubjChapter(
            id: chapter.id,
            name: chapter.name,
            domain: chapter.domain,
            prerequisites: [],
            courseStatus: status,
            masteryLevel: nil,
            colleStatus: .todo
        )
    }

    /// Mode ouvert par défaut d'une matière (`resolveTrainingMode`, avec un
    /// choix de matière encore vierge) : les Dissertations en ESH / HGG, les
    /// Exercices partout ailleurs. Le Cours et les Annales ne sont jamais le
    /// mode d'entrée.
    static func defaultMode(forSubjectId subjectId: String) -> SubjTrainingMode {
        SubjSubjectRules.usesDissertations(subjectId) ? .dissertations : .exercices
    }
}
