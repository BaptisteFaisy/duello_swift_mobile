//
//  ProgPrereqEcgApplied+Helpers.swift
//  Duello
//
//  Phase 1a — fabriques de prérequis propres aux ECG appliquées et constantes
//  nommées de la source (`during`/`after`/`inFirstYear`/`fromFirstYear`/
//  `duringSecondYear`/`afterSecondYear`, `editorialQuestionReview`).
//
//  Ces helpers sont consommés par `ProgPrereqEcgAppliedData.swift` (table de
//  ventilation par question, générée) et par `+Tables.swift`.
//
//  Cible : iOS 16, aucune dépendance externe.
//
import Foundation

extension ProgPrereqEcgApplied {

    /// `EditorialQuestionGroup` : questions partageant la même fiche.
    struct EditorialQuestionGroup {
        var ids: [String]
        var prerequisites: [SubjChapterPrerequisite]
    }

    // MARK: - Fabriques d'année 1

    /// `firstYearRequirement`.
    static func firstYearRequirement(
        _ chapterId: String, _ requiredStatus: SubjRequiredCourseStatus, _ reason: String
    ) -> SubjChapterPrerequisite {
        SubjChapterPrerequisite(
            year: .first, chapterId: chapterId, requiredStatus: requiredStatus, reason: reason
        )
    }

    /// `during` : chapitre de 1re année à travailler en parallèle.
    static func during(_ chapterId: String, _ reason: String) -> SubjChapterPrerequisite {
        firstYearRequirement(chapterId, .inProgress, reason)
    }

    /// `after` : chapitre de 1re année déjà vu.
    static func after(_ chapterId: String, _ reason: String) -> SubjChapterPrerequisite {
        firstYearRequirement(chapterId, .completed, reason)
    }

    /// `inFirstYear` (alias de `during`).
    static func inFirstYear(_ chapterId: String, _ reason: String) -> SubjChapterPrerequisite {
        during(chapterId, reason)
    }

    /// `fromFirstYear` (alias de `after`).
    static func fromFirstYear(_ chapterId: String, _ reason: String) -> SubjChapterPrerequisite {
        after(chapterId, reason)
    }

    // MARK: - Fabriques d'année 2

    /// `secondYearRequirement`.
    static func secondYearRequirement(
        _ chapterId: String, _ requiredStatus: SubjRequiredCourseStatus, _ reason: String
    ) -> SubjChapterPrerequisite {
        SubjChapterPrerequisite(
            year: .second, chapterId: chapterId, requiredStatus: requiredStatus, reason: reason
        )
    }

    /// `duringSecondYear`.
    static func duringSecondYear(_ chapterId: String, _ reason: String) -> SubjChapterPrerequisite {
        secondYearRequirement(chapterId, .inProgress, reason)
    }

    /// `afterSecondYear`.
    static func afterSecondYear(_ chapterId: String, _ reason: String) -> SubjChapterPrerequisite {
        secondYearRequirement(chapterId, .completed, reason)
    }

    // MARK: - Ventilation éditoriale

    /// `editorialQuestionReview` : associe chaque id de question à sa fiche.
    static func editorialQuestionReview(
        _ groups: EditorialQuestionGroup...
    ) -> [String: [SubjChapterPrerequisite]] {
        var byQuestion: [String: [SubjChapterPrerequisite]] = [:]
        for group in groups {
            for id in group.ids { byQuestion[id] = group.prerequisites }
        }
        return byQuestion
    }

    // MARK: - Constantes nommées (année 1)

    static let logic = fromFirstYear(
        "appliquees-1-logique", "La preuve utilise un raisonnement quantifié ou une récurrence."
    )
    static let functions = fromFirstYear(
        "appliquees-1-generalites-fonctions", "La question étudie une fonction réelle."
    )
    static let limits = fromFirstYear(
        "appliquees-1-limites-fonctions", "La question calcule ou utilise une limite de fonction."
    )
    static let continuity = fromFirstYear(
        "appliquees-1-continuite", "L'existence ou le passage à la limite utilise la continuité."
    )
    static let derivatives = fromFirstYear(
        "appliquees-1-derivabilite", "La question utilise une dérivée ou un tableau de variations."
    )
    static let sequences = fromFirstYear(
        "appliquees-1-generalites-suites", "La question manipule une suite et sa définition."
    )
    static let systems = fromFirstYear(
        "appliquees-1-systemes-lineaires", "Le calcul demande la résolution d’un système linéaire."
    )
    static let pythonAlgorithms = fromFirstYear(
        "python-appliquees-1-algorithmique-listes", "La question demande une boucle, une fonction ou une liste Python."
    )
    static let convergentSequences = inFirstYear(
        "appliquees-1-convergence-suites", "La question porte sur la convergence ou la limite d’une suite."
    )
    static let integrals = inFirstYear(
        "appliquees-1-integration-segment", "La question utilise une intégrale sur un segment."
    )
    static let series = inFirstYear(
        "appliquees-1-series-numeriques", "La question porte sur la convergence ou la somme d’une série."
    )
    static let matrices = inFirstYear(
        "appliquees-1-matrices", "La question effectue un calcul matriciel."
    )
    static let finiteProbabilities = inFirstYear(
        "appliquees-1-probabilites-finies", "La question utilise les probabilités sur un univers fini."
    )
    static let infiniteProbabilities = inFirstYear(
        "appliquees-1-probabilites-infinies", "La question utilise une famille infinie d’événements."
    )
    static let discreteVariables = inFirstYear(
        "appliquees-1-variables-discretes", "La question étudie la loi ou les moments d’une variable discrète."
    )
    static let pythonApproximation = inFirstYear(
        "python-appliquees-1-approximation-numerique", "La question met en œuvre une approximation numérique."
    )

    // MARK: - Constantes nommées (année 2)

    static let secondYearFunctions = duringSecondYear(
        "appliquees-2-fonctions", "La question étudie une fonction avec les outils de deuxième année."
    )
    static let secondYearPythonLoops = afterSecondYear(
        "python-appliquees-2-boucles-sommes", "La question écrit ou utilise une fonction Python."
    )
    static let secondYearVectorSpaces = duringSecondYear(
        "appliquees-2-espaces-vectoriels", "La question vérifie ou manipule une structure vectorielle."
    )
    static let secondYearDifferentialSystems = afterSecondYear(
        "appliquees-2-systemes-differentiels", "La question utilise la linéarité d’une équation différentielle."
    )
    static let secondYearIntegration = afterSecondYear(
        "appliquees-2-integration", "La question utilise la linéarité de l’intégrale."
    )
    static let secondYearDiscreteVariables = afterSecondYear(
        "appliquees-2-variables-discretes", "La question identifie une variable discrète et sa loi."
    )
    static let secondYearDensityVariables = duringSecondYear(
        "appliquees-2-variables-densite", "La question transforme une variable à densité."
    )
}
