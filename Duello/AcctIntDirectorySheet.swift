//
//  AcctIntDirectorySheet.swift
//  Duello
//
//  LOT 17 — annuaire de l'onglet « Mon compte » (préfixe `AcctInt`).
//
//  Hôte de `AcctSearchView` (lot 10-D) et de son modèle `AcctSearchModel`.
//  Correspond à la section annuaire de `src/screens/AccountScreen.tsx`
//  (`searchQuery`, `directoryProfiles`, `selectedMemberId`), présentée ici en
//  feuille depuis « Mon compte » plutôt qu'en ligne.
//
//  `@MainActor` sur la vue : `AcctSearchModel` est isolé au fil principal, or
//  son initialisation a lieu dans un initialiseur de propriété (non isolé par
//  défaut). C'est le motif déjà employé par `ChalHome2QueuePanel`.
//
//  Replis documentés : la proposition de défi (`canProposeChallenge`) est fixée
//  à faux — la passerelle vers `ChallengePlayerView` n'est pas reliée ici ; les
//  sorties « bloquer » et « signaler » sont des no-op (elles appartiennent au
//  lot « Social »). La vue reste pleinement fonctionnelle pour la recherche,
//  la fiche publique et l'abonnement local (`toggleFollow`).
//
//  Cible : iOS 16, aucune API iOS 17.
//
import SwiftUI

/// Feuille « Annuaire » : recherche d'élèves et fiche publique.
@MainActor
struct AcctIntDirectorySheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model = AcctSearchModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                AcctSearchView(
                    model: model,
                    canProposeChallenge: false,
                    onProposeChallenge: { _ in },
                    onBlock: { _ in },
                    onReport: { _ in }
                )
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(Theme.background)
            .navigationTitle("Annuaire")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
        }
    }
}
