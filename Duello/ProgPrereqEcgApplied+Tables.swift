//
//  ProgPrereqEcgApplied+Tables.swift
//  Duello
//
//  Phase 1a — tables calculées de `ecgAppliedPrerequisites.ts` (RN) :
//    - `EXERCISE_PREREQUISITE_OVERRIDES` = surcharge littérale + les oraux HEC
//      2025 + les deux banques (`bankPrerequisites`, `authorizedDrivePrerequisites`) ;
//    - `REVIEWED_APPLIED_EXERCISES` = les feuilles de calcul relues + les clés
//      des trois tables ci-dessus + les entrées littérales
//      (`explicitReviewedAppliedExercises`).
//
//  Les tables volumineuses sous-jacentes vivent dans
//  `ProgPrereqEcgAppliedData.swift` (GÉNÉRÉ).
//
//  Cible : iOS 16, aucune dépendance externe.
//
import Foundation

extension ProgPrereqEcgApplied {

    /// `EXERCISE_PREREQUISITE_OVERRIDES` : une surcharge par clé de revue, la
    /// dernière source gagnant (oraux HEC, puis banque, puis recueils Drive),
    /// comme les `spread` successifs de la source.
    static let exercisePrerequisiteOverrides: [String: [SubjChapterPrerequisite]] =
        ["2:appliquees-2-espaces-vectoriels:td-espaces-vectoriels-exercice-21": [secondYearVectorSpaces, systems]]
            .merging(hecOralEspPrerequisites) { _, new in new }
            .merging(bankPrerequisites) { _, new in new }
            .merging(authorizedDrivePrerequisites) { _, new in new }

    /// `REVIEWED_APPLIED_EXERCISES`.
    static let reviewedAppliedExercises: Set<String> = Set(
        reviewedCalculationSheetExercises
            + Array(hecOralEspPrerequisites.keys)
            + Array(bankPrerequisites.keys)
            + Array(authorizedDrivePrerequisites.keys)
            + explicitReviewedAppliedExercises
    )
}
