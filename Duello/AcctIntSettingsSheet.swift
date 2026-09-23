//
//  AcctIntSettingsSheet.swift
//  Duello
//
//  Hôte des réglages du profil : porte l'écran `AcctInfoSettingsView` (onglets
//  « Paramètres | Premium » et pages du menu) et câble ses sorties aux écrans
//  déjà portés.
//
//  Fichier source Expo porté : `src/screens/AccountScreen.tsx`, page
//  `'settings'` — le rendu hors `page === 'profile'`, qui empile
//  `SETTINGS_SWIPE_PAGES` dans un `OrderedTabPager`.
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
    /// Feuille ouverte par-dessus les réglages. En mode capture,
    /// `ScreenshotTour` la fige d'emblée.
    @State private var presented: AcctIntSettingsTarget? = ScreenshotTour.accountSettings?.leaf

    init(email: String = "", token: String? = nil) {
        _premium = StateObject(wrappedValue: PremCodeSync(email: email, token: token))
    }

    var body: some View {
        NavigationStack {
            AcctInfoSettingsView(
                notificationStore: notificationStore,
                isGuest: !session.isSignedIn,
                initialTab: ScreenshotTour.accountSettings?.tab ?? .informations,
                initialPage: ScreenshotTour.accountSettings?.page ?? .menu,
                displayName: session.profile.displayName,
                year: session.profile.year,
                onOpenFeedback: { presented = .feedback },
                onOpenPrivacy: { presented = .privacy },
                onOpenTerms: { presented = .terms },
                onOpenEmail: { presented = .email },
                onOpenPassword: { presented = .password },
                onOpenBlocked: { presented = .blocked },
                onLogout: { Task { await session.signOut() } },
                onDeleteAccount: {},
                token: session.token,
                premiumDaysLabel: premiumDaysLabel,
                onClose: { dismiss() }
            )
            // Les réglages dessinent leur propre en-tête (retour + onglets) :
            // la barre de navigation ne doit rien ajouter.
            .toolbar(.hidden, for: .navigationBar)
            .sheet(item: $presented) { target in
                destination(target)
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
        case .privacy: PrivacyPolicyView()
        case .terms: TermsOfUseView()
        case .email: AcctSecEmailView()
        case .password: AcctSecPasswordView()
        case .blocked: AcctSubBlockedUsersView()
        }
    }
}
