//
//  AcctIntSettingsSheet.swift
//  Duello
//
//  LOT 17 — réglages « Mes informations » de l'onglet « Mon compte »
//  (préfixe `AcctInt`).
//
//  Hôte de `AcctInfoSettingsView` (lot 10-C), qui route entre les quatre pages
//  du menu « informations » (`informationSettingsPage` de
//  `src/screens/AccountScreen.tsx`, l. 3590-4132). Les sorties sont câblées aux
//  écrans déjà portés.
//
//  Replis documentés : la suppression de compte (`onDeleteAccount`) est un
//  no-op — aucun point de terminaison de suppression n'est porté ; la bascule
//  biométrique (`onBiometricChange`) reste au repli par défaut de
//  `AcctInfoSettingsView` (la politique `AcctSecBiometricPolicy` n'est pas
//  branchée ici).
//
//  Cible : iOS 16, aucune API iOS 17.
//
import SwiftUI

/// Écran ouvert par une sortie des réglages « informations ».
enum AcctIntSettingsTarget: String, Identifiable {
    case feedback, privacy, terms, email, password, blocked

    var id: String { rawValue }
}

/// Feuille « Mes informations » : réglages, sécurité et pages légales.
struct AcctIntSettingsSheet: View {
    @EnvironmentObject private var session: SessionStore
    @Environment(\.dismiss) private var dismiss
    @StateObject private var notificationStore = NotificationPreferencesStore()
    @State private var presented: AcctIntSettingsTarget?

    var body: some View {
        NavigationStack {
            AcctInfoSettingsView(
                notificationStore: notificationStore,
                isGuest: !session.isSignedIn,
                displayName: session.profile.displayName,
                year: session.profile.year,
                onOpenFeedback: { presented = .feedback },
                onOpenPrivacy: { presented = .privacy },
                onOpenTerms: { presented = .terms },
                onOpenEmail: { presented = .email },
                onOpenPassword: { presented = .password },
                onOpenBlocked: { presented = .blocked },
                onLogout: { Task { await session.signOut() } },
                onDeleteAccount: {}
            )
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
            .sheet(item: $presented) { target in
                destination(target)
            }
        }
    }

    /// Écran ouvert par une sortie des réglages.
    @ViewBuilder
    private func destination(_ target: AcctIntSettingsTarget) -> some View {
        switch target {
        case .feedback: FeedbackView()
        case .privacy: PrivacyPolicyView()
        case .terms: TermsOfUseView()
        case .email: AcctSecEmailView()
        case .password: AcctSecPasswordView()
        case .blocked: BlockedUsersView()
        }
    }
}
