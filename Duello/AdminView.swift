//
//  AdminView.swift
//  Duello
//
//  Racine de l'espace d'administration.
//
//  Fichiers source Expo portés :
//    - src/admin/AdminApp.tsx  (navigation par onglets, en-tête, clé d'accès,
//      exception d'inscription, mot de passe, déconnexion)
//    - src/utils/auth.ts       (`AdminAccount`)
//
//  Invariant du projet : l'espace admin est une **surface produit séparée**. Il
//  ne charge ni `UserProfile`, ni progression, ni planning, et n'affiche aucun
//  écran élève ; il travaille sur le registre `AdmAccount`. Sa barre d'onglets
//  lui est propre et ne réutilise pas `MainTabView`.
//
//  Le mot de passe et la déconnexion sont **injectés** par l'appelant : cet
//  écran ne connaît ni le hachage des identifiants, ni la session élève.
//
//  Cible : iOS 16. Aucune dépendance externe.
//

import SwiftUI

/// `AdminApp` : racine de l'espace d'administration.
struct AdminView: View {
    /// Compte administrateur (registre séparé, jamais un `UserProfile`).
    var account: AdmAccount
    /// `onChangePassword` : changement du mot de passe administrateur.
    var onChangePassword: (String) async throws -> Void
    /// `onLogout` : fermeture de la session administrateur.
    var onLogout: () async throws -> Void

    @State private var activeTab: AdmTab = .admin
    @State private var apiToken = ""
    @State private var isTokenLoaded = false
    @State private var persistTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 0) {
            content
            AdmTabBar(active: $activeTab)
        }
        .background(Theme.background)
        .task { await loadToken() }
        .onChange(of: apiToken) { newValue in
            persistToken(newValue)
        }
    }

    /// Contenu de l'onglet actif. Aucun écran de l'espace élève n'y figure.
    @ViewBuilder
    private var content: some View {
        switch activeTab {
        case .admin:
            AdmHomeTab(
                account: account,
                apiToken: $apiToken,
                onChangePassword: onChangePassword,
                onLogout: onLogout
            )
        case .analytics:
            AdmAnalyticsScreen(token: apiToken)
        case .users:
            AdmUsersScreen(token: apiToken)
        case .waitlist:
            AdmWaitlistScreen(token: apiToken)
        case .promo:
            AdmPromoCodesScreen(token: apiToken)
        case .reports:
            AdmReportsScreen(token: apiToken)
        case .feedback:
            AdmFeedbackScreen(token: apiToken)
        }
    }

    /// Relit la clé d'accès mémorisée dans le stockage isolé du compte admin.
    @MainActor
    private func loadToken() async {
        apiToken = AdmAccountRegistry.loadApiToken()
        isTokenLoaded = true
    }

    /// `useEffect([apiToken, apiTokenLoaded])` du source : l'écriture est
    /// **différée de 300 ms** (`setTimeout`) et annulée à chaque nouvelle frappe.
    @MainActor
    private func persistToken(_ value: String) {
        guard isTokenLoaded else { return }
        persistTask?.cancel()
        persistTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            if Task.isCancelled { return }
            AdmAccountRegistry.saveApiToken(value)
        }
    }
}
