//
//  ProgPrereqLycee.swift
//  Duello
//
//  Phase 1a — prérequis du lycée : Seconde, Première spécialité et Terminale
//  spécialité. Port de `src/data/secondePrerequisites.ts`,
//  `premierePrerequisites.ts`, `terminalePrerequisites.ts` et
//  `lyceeProgram.ts` (RN) : graphe de chapitres, règle de difficulté, empreinte
//  de banque et revue par exercice.
//
//  Le niveau se lit dans le scope de `bankId` (`seconde` / `premiere` /
//  `terminale`) ; chaque niveau porte sa revue dans une extension dédiée
//  (`ProgPrereqLycee+Seconde.swift`, `+Premiere.swift`, `+Terminale.swift`).
//
//  Réutilise sans les redéfinir : `SubjChapterPrerequisite` et
//  `SubjRequiredCourseStatus` (`SubjChapterPrerequisites.swift`),
//  `SubjProgramYear` (`SubjFlashcardSelection.swift`) et
//  `ProgPrereqMpsiMpGraph.uniqueChapterPrerequisites(_:)` (socle).
//
//  Cible : iOS 16, aucune dépendance externe.
//
import Foundation

/// Prérequis du lycée : trois niveaux projetés sur une seule année de programme.
enum ProgPrereqLycee {

    // MARK: - Programme du lycée

    /// `LYCEE_PROGRAM_YEAR` (`lyceeProgram.ts`) : année sur laquelle
    /// l'application adresse les chapitres du lycée. Les trois niveaux y sont
    /// projetés, la même que celle que le profil résout et que le catalogue
    /// déclare ; une fiche écrite sur une autre année serait inerte.
    static let LYCEE_PROGRAM_YEAR: SubjProgramYear = .second

    /// `COMPLETED_CHAPTER_DIFFICULTY` : difficulté à partir de laquelle un sujet
    /// suppose le chapitre terminé et non seulement commencé. Même seuil pour
    /// les trois niveaux, comme les banques de prépa.
    static let COMPLETED_CHAPTER_DIFFICULTY = 3

    // MARK: - Aiguillage par niveau

    /// Scope d'une banque : premier segment de `bankId`
    /// (`scope:exercice:chapterId`). Un `bankId` sans « : » est son propre scope.
    private static func bankScope(of bankId: String) -> String {
        guard let separator = bankId.firstIndex(of: ":") else { return bankId }
        return String(bankId[bankId.startIndex..<separator])
    }

    /// Aiguillage par le scope de `bankId` vers la revue portée du niveau.
    ///
    /// `ProgPrereq.review(_:)` (phase 1b) ne présente ici que les trois scopes
    /// du lycée ; tout autre scope retombe sur le niveau d'entrée, Seconde.
    static func review(_ input: ProgPrereq.ReviewInput) -> ProgPrereqReview {
        switch bankScope(of: input.bankId) {
        case "premiere":
            return premiereExercisePrerequisiteReview(input)
        case "terminale":
            return terminaleExercisePrerequisiteReview(input)
        default:
            return secondeExercisePrerequisiteReview(input)
        }
    }
}
