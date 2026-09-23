//
//  AcctIntNotificationsSheet.swift
//  Duello
//
//  Feuille « Notifications », ouverte par la cloche de la ligne de recherche de
//  l'onglet « Mon compte » (préfixe `AcctInt`).
//
//  Fichier source Expo porté : `src/screens/AccountScreen.tsx`, branche
//  `page === 'notifications'` (l. 1989-2130) :
//    - en-tête : retour + onglets `Notifications` / `Amis` ;
//    - page `notifications` : la carte de réglages des rappels
//      (`NotificationSettingsCard`) ;
//    - page `amis` : onglets `Followers` / `Followings`.
//
//  Replis documentés : la liste des notifications du serveur et les listes
//  Followers / Followings ne sont pas exposées localement (aucun store de
//  graphe social côté iOS) ; les onglets correspondants affichent leur état
//  vide — exactement ce que rend la source quand les listes sont vides.
//
//  Cible : iOS 16, aucune API iOS 17.
//
import SwiftUI

/// Onglets de tête de la feuille (`Notifications` / `Amis`).
private enum AcctIntNotificationsTab: String, CaseIterable, Identifiable {
    case notifications, friends

    var id: String { rawValue }
    var label: String { self == .notifications ? "Notifications" : "Amis" }
}

/// Onglets de la page `Amis` (`Followers` / `Followings`).
private enum AcctIntFriendsSection: String, CaseIterable, Identifiable {
    case followers, followings

    var id: String { rawValue }
    var label: String { self == .followers ? "Followers" : "Followings" }
    var emptyMessage: String {
        self == .followers ? "Aucun follower pour le moment." : "Tu ne suis encore personne."
    }
}

/// Feuille « Notifications » : réglages des rappels et onglets Amis.
struct AcctIntNotificationsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var notificationStore = NotificationPreferencesStore()
    @State private var tab: AcctIntNotificationsTab = .notifications
    @State private var friends: AcctIntFriendsSection = .followers

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    tabBar
                    switch tab {
                    case .notifications:
                        NotificationSettingsCard(store: notificationStore)
                    case .friends:
                        friendsBlock
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 24)
            }
            .background(Theme.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Retour") { dismiss() }
                }
            }
        }
    }

    /// Barre d'onglets `Notifications` / `Amis` (`settingsTabs` de la source).
    private var tabBar: some View {
        HStack(spacing: 8) {
            ForEach(AcctIntNotificationsTab.allCases) { value in
                AcctIntSegmentedPill(
                    label: value.label,
                    selected: tab == value,
                    onTap: { tab = value }
                )
            }
            Spacer(minLength: 0)
        }
    }

    /// Page `Amis` : onglets Followers / Followings et leur état vide.
    private var friendsBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                ForEach(AcctIntFriendsSection.allCases) { value in
                    AcctIntSegmentedPill(
                        label: value.label,
                        selected: friends == value,
                        onTap: { friends = value }
                    )
                }
                Spacer(minLength: 0)
            }
            DuelloEmptyState(
                icon: "person.2",
                title: friends.label,
                message: friends.emptyMessage
            )
        }
        .duelloCard()
    }
}

/// Puce d'onglet de la feuille (`settingsTab` / `selectedSettingsTab`) : le
/// libellé en gras, l'onglet choisi sur fond d'encre.
private struct AcctIntSegmentedPill: View {
    let label: String
    let selected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(label)
                .font(.system(size: 13, weight: selected ? .heavy : .semibold))
                .foregroundStyle(selected ? Theme.surface : Theme.inkSoft)
                .padding(.horizontal, 14)
                .frame(height: 34)
                .background(selected ? Theme.ink : Theme.surfaceMuted)
                .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }
}
