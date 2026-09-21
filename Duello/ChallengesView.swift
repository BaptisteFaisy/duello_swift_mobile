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
//  l'assemblage des composants déjà portés. `ChallengesView()` reste le point
//  d'entrée sans argument attendu par `MainTabView`.
//
//  Cible : iOS 16, aucune API iOS 17.
//
import SwiftUI

/// Onglet « Défis » : assemblé par `ChalIntChallengesTab`.
struct ChallengesView: View {
    var body: some View {
        ChalIntChallengesTab()
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
