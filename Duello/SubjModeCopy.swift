// [SubjModeCopy] Libellés accordés des modes d'entraînement et disponibilités.
// Porté de `src/screens/SubjectsScreen.tsx` (lignes 918-1003 : `getModeLabel`,
// `getItemLabel`, `availabilityLabel`, `successLabel`, `modeSuccessLabel`,
// `usesDissertations`, `ModeAvailability`, `EMPTY_AVAILABILITY`).

import Foundation

/// Règles de matière partagées par les onglets et les libellés.
enum SubjSubjectRules {
    /// Matière à laquelle sont réservés le Cours et les Annales.
    static let mathsSubjectId = "maths"

    /// Les matières qui composent au lieu de calculer n'ont pas d'onglet
    /// « Exercices » (`usesDissertations`).
    static func usesDissertations(_ subjectId: String) -> Bool {
        subjectId == "esh" || subjectId == "hgg"
    }
}

/// Libellés accordés d'un mode, repris mot pour mot de `SubjectsScreen.tsx`.
/// L'accord repose sur la nature du sujet (`TrainExerciseKind`) déjà portée.
enum SubjModeCopy {
    /// Nom d'un item du mode, accordé au nombre annoncé (`getItemLabel`).
    static func itemLabel(_ mode: SubjChapterTrainingMode, count: Int) -> String {
        mode.kind.noun(count: count)
    }

    /// « 12 exercices disponibles », « 3 colles disponibles »
    /// (`availabilityLabel`).
    static func availability(_ mode: SubjChapterTrainingMode, count: Int) -> String {
        TrainCopy.availability(mode.kind, count: count)
    }

    /// « 0/32 exercices réussis », « 1/8 colles réussies » : le pluriel suit le
    /// nombre total annoncé par le dénominateur (`successLabel`).
    static func success(
        _ mode: SubjChapterTrainingMode,
        succeeded: Int,
        available: Int,
        withNoun: Bool = true
    ) -> String {
        TrainCopy.success(
            mode.kind,
            succeeded: succeeded,
            available: available,
            withNoun: withNoun
        )
    }

    /// Même décompte, étendu au Cours et aux Annales : l'en-tête d'une matière
    /// ouverte annonce les sujets du seul onglet affiché (`modeSuccessLabel`).
    static func modeSuccess(_ mode: SubjTrainingMode, succeeded: Int, total: Int) -> String {
        switch mode {
        case .cours:
            let plural = total > 1 ? "s" : ""
            return "\(succeeded)/\(total) chapitre\(plural) terminé\(plural)"
        case .annales:
            let plural = total > 1 ? "s" : ""
            return "\(succeeded)/\(total) annale\(plural) réussie\(plural)"
        case .exercices, .colles, .dissertations:
            guard let chapterMode = mode.chapterMode else { return "" }
            return success(chapterMode, succeeded: succeeded, available: total)
        }
    }
}

/// Ce qu'une matière propose déjà dans un mode, tous chapitres confondus
/// (`ModeAvailability`).
struct SubjModeAvailability: Equatable {
    var available: Int = 0
    var withSolution: Int = 0
    var chapters: Int = 0
    var succeeded: Int = 0

    /// `EMPTY_AVAILABILITY` : matière vierge dans le mode considéré.
    static let empty = SubjModeAvailability()
}
