//
//  SubjCourseProgress.swift
//  Duello
//
//  Lot 9-H « lignes de chapitre, étiquettes et barre de progression »
//  (préfixe `Subj`).
//
//  Fichier source Expo porté :
//    - src/utils/courseDocument.ts : `normalizedCoursePosition`,
//      `courseStatusAtPosition`, `courseProgressFraction`
//
//  Le statut de cours (`TrainCourseStatus`) et ses libellés viennent de
//  `TrainCourseStatus.swift` : rien n'est redéfini ici, seul le calcul de la
//  part affichée dans la barre d'un chapitre de cours est porté.
//  Cible iOS 16, aucune API iOS 17.
//
import Foundation

/// Part affichée dans la barre d'un chapitre de la vue Cours
/// (`courseProgressFraction`).
///
/// Dès qu'un repère a été placé dans le PDF, sa position précise devient la
/// source de vérité visuelle. Un document importé sans repère commence à zéro :
/// sa barre ne doit pas reprendre l'ancien statut du chapitre. Les trois statuts
/// historiques restent uniquement le repli des chapitres sans document.
enum SubjCourseProgress {
    /// `normalizedCoursePosition` : position bornée à [0, 1] ; `nil` quand la
    /// valeur n'est pas un nombre fini (`unknown` côté source).
    static func normalizedPosition(_ value: Double?) -> Double? {
        guard let value, value.isFinite else { return nil }
        return min(1, max(0, value))
    }

    /// `courseStatusAtPosition` : statut intrinsèque d'une position placée dans
    /// le cours. `nil` quand aucun repère n'existe.
    static func status(atPosition value: Double?) -> TrainCourseStatus? {
        guard let position = normalizedPosition(value) else { return nil }
        if position <= 0 { return .notStarted }
        if position >= 1 { return .completed }
        return .inProgress
    }

    /// Part remplie de la barre d'un chapitre de cours.
    ///
    /// - `position` : repère placé par l'élève, prioritaire dès qu'il existe ;
    /// - `status` : repli des chapitres sans document ;
    /// - `hasCourseDocument` : un document importé sans repère part de zéro.
    static func fraction(
        position: Double?,
        status: TrainCourseStatus,
        hasCourseDocument: Bool = false
    ) -> Double {
        if let normalized = normalizedPosition(position) { return normalized }
        if hasCourseDocument { return 0 }
        switch status {
        case .completed: return 1
        case .inProgress: return 0.5
        case .notStarted: return 0
        }
    }
}
