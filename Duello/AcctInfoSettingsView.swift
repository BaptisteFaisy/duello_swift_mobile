//
//  AcctInfoSettingsView.swift
//  Duello
//
//  Lot 10-C « réglages informations » (préfixe `AcctInfo`).
//  Hôte du menu « informations » : route entre les quatre pages et porte
//  l'état de navigation local (`informationSettingsPage` de la source).
//
//  Fichier source Expo porté :
//    - src/screens/AccountScreen.tsx : `informationSettingsPage` et ses
//      transitions `setInformationSettingsPage('menu' | 'duello' | 'personal'
//      | 'account')` (582-620, 3590-4132).
//
//  Découpé hors de `AcctInfoPages.swift` pour tenir la règle des 10 `func`
//  par fichier. À présenter dans un `NavigationStack` par l'écran hôte.
//
import SwiftUI

/// Écran de réglages « informations » : affiche la page courante et permet de
/// revenir au menu. Toutes les actions sortantes sont injectées par l'hôte.
struct AcctInfoSettingsView: View {
    @ObservedObject var notificationStore: NotificationPreferencesStore
    var isGuest: Bool = false
    var biometricEnabled: Bool = false
    var onBiometricChange: (Bool) -> Void = { _ in }
    var onOpenFeedback: () -> Void = {}
    var onOpenPrivacy: () -> Void = {}
    var onOpenTerms: () -> Void = {}
    var onOpenEmail: () -> Void = {}
    var onOpenPassword: () -> Void = {}
    var onOpenBlocked: () -> Void = {}
    var onLogout: () -> Void = {}
    var onDeleteAccount: () -> Void = {}

    @State private var page: AcctInfoPage
    @State private var displayName: String
    @State private var year: String

    init(
        notificationStore: NotificationPreferencesStore,
        isGuest: Bool = false,
        initialPage: AcctInfoPage = .menu,
        displayName: String = "",
        year: String = "",
        biometricEnabled: Bool = false,
        onBiometricChange: @escaping (Bool) -> Void = { _ in },
        onOpenFeedback: @escaping () -> Void = {},
        onOpenPrivacy: @escaping () -> Void = {},
        onOpenTerms: @escaping () -> Void = {},
        onOpenEmail: @escaping () -> Void = {},
        onOpenPassword: @escaping () -> Void = {},
        onOpenBlocked: @escaping () -> Void = {},
        onLogout: @escaping () -> Void = {},
        onDeleteAccount: @escaping () -> Void = {}
    ) {
        _notificationStore = ObservedObject(wrappedValue: notificationStore)
        self.isGuest = isGuest
        self.biometricEnabled = biometricEnabled
        self.onBiometricChange = onBiometricChange
        self.onOpenFeedback = onOpenFeedback
        self.onOpenPrivacy = onOpenPrivacy
        self.onOpenTerms = onOpenTerms
        self.onOpenEmail = onOpenEmail
        self.onOpenPassword = onOpenPassword
        self.onOpenBlocked = onOpenBlocked
        self.onLogout = onLogout
        self.onDeleteAccount = onDeleteAccount
        _page = State(initialValue: initialPage)
        _displayName = State(initialValue: displayName)
        _year = State(initialValue: year)
    }

    var body: some View {
        ScrollView {
            content
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
        }
        .background(Theme.background)
        .navigationTitle(page.navigationTitle ?? "Paramètres")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if page != .menu {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Paramètres") { page = .menu }
                }
            }
        }
    }

    /// Surface de la page courante (`renderedSettingsPage` + `informationSettingsPage`).
    @ViewBuilder private var content: some View {
        switch page {
        case .menu:
            AcctInfoMenuPage { page = $0 }
        case .duello:
            AcctInfoDuelloPage(
                onReportBug: onOpenFeedback,
                onOpenPrivacy: onOpenPrivacy,
                onOpenTerms: onOpenTerms
            )
        case .personal:
            AcctInfoPersonalPage(displayName: $displayName, year: $year, isGuest: isGuest)
        case .account:
            AcctInfoAccountPage(
                notificationStore: notificationStore,
                isGuest: isGuest,
                biometricEnabled: biometricEnabled,
                onBiometricChange: onBiometricChange,
                onOpenEmail: onOpenEmail,
                onOpenPassword: onOpenPassword,
                onOpenBlocked: onOpenBlocked,
                onLogout: onLogout,
                onDeleteAccount: onDeleteAccount
            )
        }
    }
}
