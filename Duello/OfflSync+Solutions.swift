//
//  OfflSync+Solutions.swift
//  Duello
//
//  Corrigés unitaires du registre de contenu.
//
//  Fichier source Expo porté : `src/content/contentStore.ts`
//  (`applyExerciseSolution`, `hasExerciseSolutionResult`, `exerciseSolution`).
//
//  Un corrigé est « connu » dès qu'il a été posé, y compris pour confirmer une
//  absence (`solution == nil`) : le dictionnaire distingue donc une absence
//  confirmée d'une absence d'information.
//
//  Cible : iOS 16.
//
import Foundation

extension OfflSync {
    /// `applyExerciseSolution` : corrigé téléchargé, ou absence confirmée.
    static func applyExerciseSolution(_ itemId: String, solution: String?) {
        if let existing = exerciseSolutions[itemId], existing == solution { return }
        exerciseSolutions.updateValue(solution, forKey: itemId)
        revision += 1
        announce()
    }

    /// `hasExerciseSolutionResult` : une réponse existe pour cet exercice.
    static func hasExerciseSolutionResult(_ itemId: String) -> Bool {
        exerciseSolutions.keys.contains(itemId)
    }

    /// `exerciseSolution` : corrigé, ou `nil` si absence (confirmée ou non).
    static func exerciseSolution(_ itemId: String) -> String? {
        exerciseSolutions[itemId] ?? nil
    }
}
