//
//  SubjHecGuidedCopy.swift
//  Duello
//
//  Libellés du parcours HEC guidé des maths (titres, descriptions, actions,
//  retour, cartes d'exemple de l'étape « flashcards »).
//
//  Fichiers source Expo portés :
//    - src/screens/SubjectsScreen.tsx (lignes 7630-7835)
//        JSX des six étapes : `guidedJourneyTitle`, `guidedJourneyDescription`,
//        `chapterWorkspaceStartButton` (« Continuer », « Oui », « Générer mes
//        flashcards », « Recevoir mes flashcards », « Apprendre mon cours »),
//        le libellé d'accessibilité du retour et les trois cartes d'exemple
//        (`flashcardsList` / `flashcard`).
//    - src/screens/SubjectsScreen.tsx (lignes 7838-7876)
//        espace de travail du chapitre : titre en capitales, bouton
//        « Commencer » et son libellé d'accessibilité.
//
//  Limite documentée : les cartes de l'étape « flashcards » sont, dans le
//  source, un jeu d'exemples figé dans le JSX — pas les cartes réellement
//  générées à partir du cours. Elles sont portées telles quelles, à titre de
//  démonstration, comme dans l'app Expo.
//
//  Cible : iOS 16.
//
import Foundation

/// Textes du parcours guidé, une entrée par étape.
enum SubjHecGuidedCopy {
    /// Titre de l'étape (`guidedJourneyTitle`).
    static func title(for step: SubjHecGuidedStep) -> String {
        switch step {
        case .duration:
            return "Combien de temps veux-tu travailler les maths aujourd’hui ?"
        case .programmeCheck:
            return "Ton programme, pour le moment, ne la remplit pas."
        case .courseUpload:
            return "Dépose ton cours de maths en PDF ou en photo pour générer tes flashcards."
        case .generating:
            return "Tes flashcards sont en train d’être générées."
        case .flashcards:
            return "Tes flashcards sont prêtes."
        case .learn:
            return "Les flashcards couvrent tout le cours."
        }
    }

    /// Description de l'étape (`guidedJourneyDescription`), absente quand le
    /// source n'en affiche pas.
    static func description(for step: SubjHecGuidedStep) -> String? {
        switch step {
        case .duration, .flashcards:
            return nil
        case .programmeCheck:
            return "On va construire ensemble le parcours de ce chapitre."
        case .courseUpload:
            return "Ton cours sera transformé en cartes de révision adaptées à ce que tu as déjà vu."
        case .generating:
            return "Fais défiler ton cours jusqu’à l’endroit où tu t’es arrêté en classe."
        case .learn:
            return "En révision, seules celles qui concernent le cours déjà vu te sont proposées."
        }
    }

    /// Libellé du bouton principal de l'étape. `nil` à l'étape `duration`, dont
    /// le bouton est « Continuer » (voir `durationActionTitle`) et reste
    /// désactivé tant qu'aucune durée n'est choisie.
    static func primaryAction(for step: SubjHecGuidedStep) -> String? {
        switch step {
        case .duration: return nil
        case .programmeCheck: return "Oui"
        case .courseUpload: return "Générer mes flashcards"
        case .generating: return "Recevoir mes flashcards"
        case .flashcards: return "Apprendre mon cours"
        case .learn: return nil
        }
    }

    /// Bouton de validation de l'étape 1, désactivé sans durée choisie.
    static let durationActionTitle = "Continuer"

    /// Libellé d'accessibilité du bouton retour, qui dépend de l'étape.
    static func backLabel(for step: SubjHecGuidedStep) -> String {
        switch step {
        case .programmeCheck: return "Revenir au choix de la durée"
        case .duration: return "Revenir au bloc du chapitre"
        default: return "Revenir à la page précédente"
        }
    }

    /// Espace de travail du chapitre (étape nulle).
    static let workspaceStartTitle = "Commencer"
    static let workspaceStartAccessibilityLabel = "Commencer le parcours guidé"

    /// Cartes d'exemple de l'étape « flashcards » (jeu figé du JSX source).
    static let sampleFlashcards: [(label: String, content: String)] = [
        ("Définition", "Une suite converge lorsqu’elle admet une limite."),
        ("Propriété", "Vérifier les conditions nécessaires avant d’appliquer le résultat."),
        ("Démonstration", "Restituer chaque étape logique de la preuve."),
    ]
}
