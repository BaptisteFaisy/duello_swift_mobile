//
//  ChallengesView.swift
//  Duello
//
//  Onglet « Défis » (lot 18 — intégration).
//
//  Fichier source Expo porté : `src/screens/ChallengesScreen.tsx`
//  (l'écran complet : accueil Défis / Événements, blason, file d'attente,
//  révélation de l'adversaire, déroulé des manches et bilan).
//
//  Le corps de l'onglet vit dans `ChalIntChallengesTab` : cet ancien fichier
//  réduit (appariement + deux cartes de classement) est remplacé par
//  l'assemblage des composants déjà portés. `ChallengesView` reste le point
//  d'entrée attendu par `MainTabView`.
//
//  R7 (2026-09-27, U07 partB#2) : reçoit la relève racine des invitations
//  (`ChalInvitationCoordinator`), la partie acceptée ailleurs (`incomingMatch`)
//  et les remises de la racine — transit vers `ChalIntChallengesTab`.
//
//  R01 (2026-09-29, raccords d'hôtes) : relaie `onContinueTraining` (reprise
//  d'un exercice de défi dans l'Entraînement) et déclare le chrome de l'onglet
//  au `RootChromeModel` (`DuelloBottomBarChrome`).
//
//  S01 (2026-09-30, producteurs de chrome) : relaie l'indice d'onglet
//  (`tabIndex`) vers `ChalIntChallengesTab`, qui déclare alors son verrou de
//  geste au `RootChromeModel`.
//
//  Cible : iOS 16, aucune API iOS 17.
//
import SwiftUI

/// Onglet « Défis » : assemblé par `ChalIntChallengesTab`.
struct ChallengesView: View {
    /// Relève racine des invitations, montée par `MainTabView`.
    var invites: ChalInvitationCoordinator
    /// Partie acceptée depuis un autre onglet, remise par `MainTabView`.
    var incomingMatch: MatchView? = nil
    /// Remise consommée : invalide la copie parente (`onIncomingMatchHandled`).
    var onIncomingMatchHandled: (() -> Void)? = nil
    /// Signale à la racine que l'écran est occupé (`onBusyChange`).
    var onBusyChange: ((Bool) -> Void)? = nil
    /// Retour par balayage vers l'onglet Entraînement (`onBackToTraining`,
    /// `OrderedTabPager.yieldBackSwipeToTabPager`) : fourni par la racine, qui
    /// seule pilote le pager d'onglets.
    var onBackToTraining: (() -> Void)? = nil
    /// Indice de l'onglet dans le pager (`MainTabView.challengesTabIndex`), pour
    /// la déclaration de chrome au `RootChromeModel`.
    var tabIndex: Int = 2
    /// Reprise de l'exercice dans l'onglet Entraînement après un défi
    /// (`onContinueTraining`, `ChallengesScreen.tsx:2426-2437,2703`) : relayé
    /// depuis la racine, qui seule bascule d'onglet.
    var onContinueTraining: ((ChalRunTrainingTarget) -> Void)? = nil

    /// Producteur de masquage de la barre basse (`useScrollChromeVisibility`) :
    /// l'onglet Défis déclare sa visibilité à la racine. Son alimentation par
    /// l'offset du défilement vit dans `ChalIntChallengesTab` (hors lot R01) —
    /// à raccorder (vague 6).
    @StateObject private var bottomBarChrome = DuelloBottomBarChrome()

    var body: some View {
        ChalIntChallengesTab(
            invites: invites,
            incomingMatch: incomingMatch,
            onIncomingMatchHandled: onIncomingMatchHandled,
            onBusyChange: onBusyChange,
            onBackToTraining: onBackToTraining,
            onContinueTraining: onContinueTraining,
            tabIndex: tabIndex
        )
        .duelloBottomBarChrome(bottomBarChrome, forTab: tabIndex)
    }
}

// MARK: - État de chargement partagé

/// Étapes du chargement d'un contenu lu sur le réseau.
///
/// Conservé ici : d'autres modules s'y réfèrent (`TrainingCatalogView+Entry`,
/// `ExGExerciseLeaderboard`, `RankingLoadStateViews`).
enum LoadState {
    case idle
    case loading
    case ready
    case error
}
