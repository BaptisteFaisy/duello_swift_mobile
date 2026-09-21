//
//  OnbGiftProgressiveReveal.swift
//  Duello
//
//  LOT K — extras d’onboarding : la montée par tranches d’une longue liste.
//
//  Fichier source Expo porté : `src/utils/progressiveReveal.ts`
//  (`revealPlan`, `RevealState`, `RevealPlan`).
//
//  Un chapitre de quatre-vingt-dix exercices créait toutes ses cartes dans le
//  rendu déclenché par l’appui : le doigt quittait l’écran avant que la liste
//  n’apparaisse. La première tranche remplit la hauteur visible immédiatement,
//  les suivantes s’ajoutent image par image, avec une taille bornée. Le nombre
//  d’éléments montés ne diminue jamais tant que la liste garde la même
//  identité ; changer d’identité — un autre chapitre, un autre filtre — ramène
//  la révélation à sa première tranche.
//
//  Les fonctions sont pures : l’appelant garde l’état et programme la tranche
//  suivante (`plan.next`).
//
//  Cible : iOS 16.
//
import Foundation

/// Calcul de la prochaine tranche d’éléments à monter dans une liste.
enum OnbGiftProgressiveReveal {
    /// Identité de la liste dont ce compte a été établi (`RevealState`).
    struct RevealState: Equatable {
        var key: String
        var count: Int
    }

    /// Ce qu’il faut monter maintenant, et l’état de l’image suivante
    /// (`RevealPlan`).
    struct RevealPlan: Equatable {
        /// Nombre d’éléments à monter maintenant.
        var count: Int
        /// Vrai lorsque toute la liste est montée : plus rien à programmer.
        var complete: Bool
        /// État à appliquer à l’image suivante, `nil` si la liste est complète.
        var next: RevealState?
    }

    /// `revealPlan` : première tranche immédiate, tranches suivantes bornées à
    /// `firstBatch`, jamais régressives tant que l’identité ne change pas.
    static func plan(
        state: RevealState,
        key: String,
        total: Int,
        firstBatch: Int
    ) -> RevealPlan {
        let first = max(1, Int(floor(Double(firstBatch))))
        let revealed = state.key == key ? max(first, state.count) : first
        let complete = revealed >= total

        return RevealPlan(
            count: complete ? max(0, total) : revealed,
            complete: complete,
            next: complete ? nil : RevealState(key: key, count: min(total, revealed + first)))
    }
}
