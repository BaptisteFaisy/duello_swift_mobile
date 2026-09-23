//
//  AcctIntSearchRow.swift
//  Duello
//
//  Ligne de recherche de l'onglet « Mon compte » (préfixe `AcctInt`).
//
//  Fichier source Expo porté : `src/screens/AccountScreen.tsx`, `searchRow`
//  (l. 2404-2516) — le champ « Nom, filière, spécialité, Elo ou XP… », la
//  cloche des notifications (`notifications` / `notifications-outline`, pastille
//  du nombre non lu) et la roue des réglages (`settings-outline`).
//
//  Réutilise sans le recréer : `AcctSearchView` (champ, menu de résultats,
//  fiche publique) et lui ajoute l'accessoire de droite. La cloche et la roue
//  sont des `settingsIconButton` de la source : 40 × 40, bord 1, rayon 12.
//
//  Repli documenté : le nombre de notifications non lues n'est pas publié
//  localement, la cloche reste donc en trait (`bell`) — jamais une pastille
//  inventée.
//
//  Cible : iOS 16, aucune API iOS 17.
//
import SwiftUI

/// Ligne de recherche du profil : champ, cloche des notifications, réglages.
@MainActor
struct AcctIntSearchRow: View {
    @ObservedObject var model: AcctSearchModel
    let onOpenNotifications: () -> Void
    let onOpenSettings: () -> Void

    var body: some View {
        AcctSearchView(
            model: model,
            canProposeChallenge: false,
            onProposeChallenge: { _ in },
            onBlock: { _ in },
            onReport: { _ in },
            rowAccessory: AnyView(accessories)
        )
    }

    /// Les deux boutons carrés de droite (`searchRow` de la source).
    private var accessories: some View {
        HStack(spacing: 9) {
            iconButton(icon: "bell", label: "Ouvrir les notifications", action: onOpenNotifications)
            iconButton(icon: "gearshape", label: "Ouvrir les paramètres", action: onOpenSettings)
        }
    }

    private func iconButton(
        icon: String,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .frame(width: 40, height: 40)
                .background(Theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}
