//
//  AcctEvoChartLoading.swift
//  Duello
//
//  Chargement du graphique de performance (lot 10-B, préfixe `AcctEvo`).
//
//  Fichier source Expo porté (libellés repris mot pour mot) :
//    - src/screens/AccountScreen.tsx, lignes 481-491
//      (`PerformanceChartLoading`, style `performanceChartLoading`)
//
//  Réutilise : `Theme`.
//
//  Cible iOS 16 ; aucune dépendance externe.
//
import SwiftUI

/// `PerformanceChartLoading` : indicateur centré dans un cadre de 96 pt de haut,
/// annoncé comme barre de progression par VoiceOver.
struct AcctEvoPerformanceChartLoading: View {
    /// `performanceChartLoading.minHeight`.
    private let minimumHeight: CGFloat = 96

    var body: some View {
        ProgressView()
            .progressViewStyle(.circular)
            .tint(Theme.ink)
            .frame(maxWidth: .infinity)
            .frame(minHeight: minimumHeight)
            // `ProgressView` porte déjà le rôle « progressbar » ; on ne fournit
            // que le libellé, identique à la source.
            .accessibilityLabel("Chargement du graphique")
    }
}
