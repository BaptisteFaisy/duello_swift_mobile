//
//  CollEmptyState.swift
//  Duello
//
//  Page vide du classement ou de l'historique d'un exercice : un pictogramme et
//  son titre suffisent, l'absence de contenu n'a rien de plus à expliquer.
//
//  Fichiers source Expo portés :
//    - src/components/ExercisePageEmptyState.tsx
//        `ExercisePageEmptyState`, styles `state` / `stateTitle` de
//        `exerciseLeaderboardPageStyles.ts`.
//
//  Cible : iOS 16, aucune dépendance externe.
//
import SwiftUI

/// État vide centré, icône SF Symbols et titre.
struct CollEmptyState: View {
    /// Nom d'un symbole SF, transposé de l'icône Ionicons de la source.
    let icon: String
    let title: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(Theme.primary)
            Text(title)
                .font(.system(size: 19, weight: .black))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
