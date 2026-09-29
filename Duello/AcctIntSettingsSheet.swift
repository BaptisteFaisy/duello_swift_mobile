//
//  AcctIntSettingsSheet.swift
//  Duello
//
//  Hôte des réglages du profil : porte l'écran `AcctInfoSettingsView` (onglets
//  « Paramètres | Premium » et pages du menu) et câble ses sorties aux écrans
//  déjà portés.
//
//  Port de `src/screens/AccountScreen.tsx`, page `'settings'` : le rendu hors
//  `page === 'profile'` empile `SETTINGS_SWIPE_PAGES` dans un `OrderedTabPager`,
//  et chaque sous-page (`feedback`, `privacy`, `terms`, `email`, `password`,
//  `blocked`) **remplace tout l'écran** dans un `SwipeBackScreen`
//  (`AccountScreen.tsx:2401-2454`). Les six sorties sont donc rendues en plein
//  écran (`fullScreenCover`) dans `Ui2SwipeBackContainer` — plus de feuille
//  modale à carte pour les pages non légales (écarts U13#1 plein écran et
//  U13#2 retour par swipe sur les six sous-pages).
//
//  La bascule biométrique (`onBiometricChange`) est branchée sur
//  `AcctSecBiometricPolicy` et le drapeau `AcctStoredAccount.biometricEnabled`
//  (écart U08#21).
//
//  V1 (2026-09-26) — écart U08#2 : `onDeleteAccount` n'est plus un no-op ; il
//  exécute la suppression réelle du compte (`DELETE /auth/account` + purge,
//  `SessionStore.deleteAccount`). La fermeture de session qui s'ensuit fait
//  disparaître la racine connectée — donc cette feuille — sans appel explicite
//  à `dismiss`, comme `onLogout`.
//
//  Cible : iOS 16, aucune API iOS 17.
//
import SwiftUI

/// Écran ouvert par une sortie des réglages « informations ».
enum AcctIntSettingsTarget: String, Identifiable {
    case feedback, privacy, terms, email, password, blocked

    var id: String { rawValue }
}

/// Feuille de réglages : onglets « Paramètres | Premium », pages du menu et
/// sorties (légal, sécurité, comptes bloqués).
struct AcctIntSettingsSheet: View {
    @EnvironmentObject private var session: SessionStore
    @Environment(\.dismiss) private var dismiss
    @StateObject private var notificationStore = NotificationPreferencesStore()
    /// Abonnement local du compte, lu au montage : seule source du compteur
    /// « N jours Premium restants ». Aucun rythme de synchronisation n'est
    /// lancé ici — la source le fait au niveau de l'application, pas des
    /// réglages.
    @StateObject private var premium: PremCodeSync
    /// Sous-page ouverte par-dessus les réglages. En mode capture,
    /// `ScreenshotTour` la fige d'emblée.
    @State private var presented: AcctIntSettingsTarget? = ScreenshotTour.accountSettings?.leaf
    /// Bascule biométrique : état du compte, relu du registre local et réécrit
    /// à chaque changement (écart U08#21).
    @State private var biometricEnabled = false

    init(email: String = "", token: String? = nil) {
        _premium = StateObject(wrappedValue: PremCodeSync(email: email, token: token))
    }

    var body: some View {
        NavigationStack {
            AcctInfoSettingsView(
                notificationStore: notificationStore,
                profile: $session.profile,
                isGuest: !session.isSignedIn,
                initialTab: ScreenshotTour.accountSettings?.tab ?? .informations,
                initialPage: ScreenshotTour.accountSettings?.page ?? .menu,
                biometricEnabled: biometricEnabled,
                onBiometricChange: { enabled in
                    biometricEnabled = enabled
                    persistBiometric(enabled)
                },
                onOpenFeedback: { presented = .feedback },
                onOpenPrivacy: { presented = .privacy },
                onOpenTerms: { presented = .terms },
                onOpenEmail: { presented = .email },
                onOpenPassword: { presented = .password },
                onOpenBlocked: { presented = .blocked },
                onLogout: { await session.signOut() },
                // La déconnexion qui suit la suppression fait disparaître
                // `MainTabView` (donc cette feuille), comme pour `onLogout` :
                // aucune fermeture explicite n'est nécessaire.
                onDeleteAccount: { try await session.deleteAccount() },
                token: session.token,
                premiumDaysLabel: premiumDaysLabel,
                onProfileChange: { session.persistProfile() },
                onClose: { dismiss() }
            )
            .onAppear { biometricEnabled = storedBiometricEnabled }
            // Les réglages dessinent leur propre en-tête (retour + onglets) :
            // la barre de navigation ne doit rien ajouter.
            .toolbar(.hidden, for: .navigationBar)
            // Sous-pages des réglages : le RN les empile en plein écran dans un
            // `SwipeBackScreen` (`AccountScreen.tsx:2401-2454`), retour par
            // glissement vers la droite comme par le chevron. Les six pages
            // passent donc par le même conteneur plein écran — la page n'est
            // plus enfermée dans la carte de la feuille Paramètres.
            .fullScreenCover(item: $presented) { target in
                Ui2SwipeBackContainer(onBack: { presented = nil }) {
                    destination(target)
                }
            }
        }
    }

    /// `premiumDaysLabel` de la source : `nil` hors abonnement actif, « Premium
    /// actif » quand l'échéance n'est pas connue, sinon le décompte en jours.
    private var premiumDaysLabel: String? {
        let now = Date().timeIntervalSince1970 * 1000
        guard PremCodeSubscription.isActive(premium.subscription, now: now) else { return nil }
        guard let days = premium.daysRemaining else { return "Premium actif" }
        let unit = days == 1 ? "jour" : "jours"
        let state = days == 1 ? "restant" : "restants"
        return "\(days) \(unit) Premium \(state)"
    }

    /// Écran ouvert par une sortie des réglages.
    @ViewBuilder
    private func destination(_ target: AcctIntSettingsTarget) -> some View {
        switch target {
        case .feedback: ExtraFeedbackView(onBack: { presented = nil })
        case .privacy: PrivacyPolicyView(onBack: { presented = nil })
        case .terms: TermsOfUseView(onBack: { presented = nil })
        case .email: AcctSecEmailView()
        case .password: AcctSecPasswordView()
        case .blocked: AcctSubBlockedUsersView()
        }
    }

    /// Drapeau biométrique du compte connecté, relu du registre local
    /// (`AcctStoredAccount.biometricEnabled`).
    private var storedBiometricEnabled: Bool {
        AcctLocalRegistry.findAccountByEmail(
            AcctLocalRegistry.loadAccounts(),
            email: session.profile.email
        )?.biometricEnabled ?? false
    }

    /// Réécrit le drapeau biométrique du compte dans le registre local.
    private func persistBiometric(_ enabled: Bool) {
        let accounts = AcctLocalRegistry.loadAccounts()
        guard var account = AcctLocalRegistry.findAccountByEmail(
            accounts,
            email: session.profile.email
        ) else { return }
        account.biometricEnabled = enabled
        AcctLocalRegistry.saveAccount(account)
    }
}
