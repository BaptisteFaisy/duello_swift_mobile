//
//  AcctIntSearchRow.swift
//  Duello
//
//  Ligne de recherche de l'onglet « Mon compte » (préfixe `AcctInt`).
//
//  Fichier source Expo porté : `src/screens/AccountScreen.tsx`, `searchRow`
//  — le champ « Nom, filière, spécialité, Elo ou XP… », la cloche des
//  notifications (`notifications` / `notifications-outline`, pastille du nombre
//  non lu, `:2628-2663`) et la roue des réglages (`settings-outline`).
//
//  Réutilise sans le recréer : `AcctSearchView` (champ, menu de résultats,
//  fiche publique) et lui ajoute l'accessoire de droite. La cloche et la roue
//  sont des `settingsIconButton` de la source : 40 × 40, bord 1, rayon 12.
//
//  V2 (28/09/2026, écarts 20 #4/B2 + A2) : la cloche bascule
//  `notifications` (plein) / `notifications-outline` selon
//  `AcctNotificationsStore.unreadCount` et porte la pastille du nombre non lu
//  (`notificationBadge`, « 9+ » au-delà de 9) ; retour d'appui `pressed`
//  (opacité 0,75) ; icônes rendues par `IonIcon` (noms exacts du RN).
//
//  Cible : iOS 16, aucune API iOS 17.
//
import SwiftUI

/// Ligne de recherche du profil : champ, cloche des notifications, réglages.
@MainActor
struct AcctIntSearchRow: View {
    @ObservedObject var model: AcctSearchModel
    @ObservedObject private var notifications = AcctNotificationsStore.shared
    /// État de publication du profil à l'annuaire (`publication` d'Expo),
    /// transmis tel quel au bandeau d'état de la recherche.
    var publication: ReportDirectoryPublication? = nil
    let onOpenNotifications: () -> Void
    let onOpenSettings: () -> Void

    var body: some View {
        AcctSearchView(
            model: model,
            canProposeChallenge: false,
            onProposeChallenge: { _ in },
            publication: publication,
            rowAccessory: AnyView(accessories)
        )
    }

    /// Les deux boutons carrés de droite (`searchRow` de la source).
    private var accessories: some View {
        HStack(spacing: 9) {
            notificationButton
            iconButton(icon: "settings-outline", label: "Ouvrir les paramètres", action: onOpenSettings)
        }
    }

    /// Cloche des notifications (`settingsIconButton` + `notificationBadge`).
    private var notificationButton: some View {
        Button(action: onOpenNotifications) {
            IonIcon(
                name: unread > 0 ? "notifications" : "notifications-outline",
                size: 20,
                color: Theme.ink
            )
            .frame(width: 40, height: 40)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1)
            )
            .overlay(alignment: .topTrailing) {
                if unread > 0 { badge }
            }
        }
        .buttonStyle(AcctPressButtonStyle())
        .accessibilityLabel(accessibilityLabel)
    }

    /// `notificationBadge` : fond `like`, min 17 × 17, rayon pilule, texte
    /// blanc 9/900, « 9+ » au-delà de neuf non-lues.
    private var badge: some View {
        Text(unread > 9 ? "9+" : "\(unread)")
            .font(.system(size: 9, weight: .black))
            .foregroundStyle(Theme.white)
            .padding(.horizontal, 4)
            .frame(minWidth: 17, minHeight: 17)
            .background(Theme.like)
            .clipShape(Capsule())
            .padding(.top, 6)
            .padding(.trailing, 6)
    }

    /// Libellé a11y de la cloche (`AccountScreen.tsx:2630-2634`).
    private var accessibilityLabel: String {
        unread > 0
            ? "Ouvrir les notifications, \(unread) non lue\(unread > 1 ? "s" : "")"
            : "Ouvrir les notifications"
    }

    /// Nombre de notifications non lues, lu sur le magasin partagé.
    private var unread: Int { notifications.unreadCount }

    private func iconButton(
        icon: String,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            IonIcon(name: icon, size: 20, color: Theme.ink)
                .frame(width: 40, height: 40)
                .background(Theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1)
                )
        }
        .buttonStyle(AcctPressButtonStyle())
        .accessibilityLabel(label)
    }
}
