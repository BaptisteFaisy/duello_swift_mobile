//
//  ExGCorrectionDock.swift
//  Duello
//
//  La correction occupe-t-elle la « partie 3 » du lecteur d'exercice ?
//
//  Fichier source Expo porté (libellés repris mot pour mot) :
//    - src/utils/exerciseCorrectionPanes.ts (`correctionDockVisible`).
//
//  Vrai dès la soumission d'un exercice ou d'une colle, et jusqu'à ce que
//  l'élève quitte le sujet. La partie 3 ne prend que la place du bouton de
//  soumission : le sablier pendant la correction, le bouton de nouveau après.
//  Trois contextes gardent la priorité et gardent donc le bilan en page : le
//  tableau blanc et le corrigé en plein écran n'ont pas de place pour lui, les
//  annales interactives corrigent question par question, et l'ordinateur
//  installé compose l'exercice en deux colonnes.
//
//  Cible : iOS 16, aucune dépendance externe.
//
import Foundation

/// Contexte d'affichage de la correction (`correctionDockVisible`).
struct ExGCorrectionDockOptions {
    var wholeExerciseSubmissionOnly: Bool
    var correctionStarted: Bool
    var whiteboardExpanded: Bool
    var documentOnSolution: Bool
    var desktopAnswerSplit: Bool
}

/// `correctionDockVisible` de `utils/exerciseCorrectionPanes.ts`.
enum ExGCorrectionDock {
    /// La correction occupe la partie 3, sauf dans les trois contextes
    /// prioritaires.
    static func visible(_ options: ExGCorrectionDockOptions) -> Bool {
        options.wholeExerciseSubmissionOnly
            && options.correctionStarted
            && !options.whiteboardExpanded
            && !options.documentOnSolution
            && !options.desktopAnswerSplit
    }
}
