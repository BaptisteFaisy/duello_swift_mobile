//
//  LoginIntAssembly.swift
//  Duello
//
//  LOT 20 — assemblage de l'écran de connexion **sombre** dans l'application.
//
//  Fournit les rappels de `LoginScrProps` (lot 14-A, porté de
//  `src/screens/LoginScreen.tsx`) à `LoginScrScreen`, en les câblant sur
//  l'application : `SessionStore` (connexion serveur), fermeture de la feuille
//  (« lien de retour ») et réinitialisation serveur du mot de passe
//  (`PasswordResetView`). C'est ce type que branche `LoginView`.
//
//  Limites assumées — le registre local (`utils/auth.ts` : `saveAccount` /
//  `loadAccounts`) n'est pas porté, donc :
//    - `accounts` reste vide : la récupération par code de secours
//      administrateur et l'activation de compte (`onLogin`) ne sont **pas
//      atteignables** ; le chemin réel est le compte inconnu du registre
//      (`onPasswordLogin` → `SessionStore.signIn`).
//    - `persistAccount` est un no-op documenté.
//  La connexion Apple passe par `LoginIntSession` (pont documenté).
//
//  Vague 3 (kit-alert) — l'échec d'ouverture d'une session fournisseur
//  (Apple/Google) était rendu par un `.alert` **natif** ; il passe désormais
//  par la fenêtre commune `AppAlert` (`AppAlertView.swift`), montée une seule
//  fois à la racine (`DuelloApp.swift` → `.appAlertHost()`), comme
//  `AppAlert.alert(...)` côté Expo.
//
//  Cible : iOS 16. Aucune dépendance externe.
//

import SwiftUI

/// Écran de connexion sombre branché sur `SessionStore`.
struct LoginIntAssembly: View {
    @EnvironmentObject private var session: SessionStore
    @Environment(\.dismiss) private var dismiss

    /// Adresse à réinitialiser (feuille `PasswordResetView`).
    @State private var resetEmail: String?

    var body: some View {
        LoginScrScreen(props: props)
            .sheet(isPresented: isResetPresented) {
                PasswordResetView(email: resetEmail ?? "")
            }
    }

    // MARK: Rappels

    /// `LoginScrProps` câblés sur l'application.
    private var props: LoginScrProps {
        LoginScrProps(
            account: nil,
            accounts: [],
            onLogin: { account, password in
                try await signInKnownAccount(account, password: password)
            },
            onPasswordLogin: { email, password in
                try await session.signIn(email: email, password: password)
            },
            onAppleAuthenticated: { identity, payload in
                Task { @MainActor in
                    do {
                        try LoginIntSession.openAppleSession(
                            session: session,
                            identity: identity,
                            payload: payload
                        )
                    } catch {
                        // Échec fournisseur : fenêtre commune `AppAlert`
                        // (jamais `.alert` natif), rendue à la racine.
                        AppAlert.alert("Connexion", error.localizedDescription)
                    }
                }
            },
            onGoogleAuthenticated: { identity, payload in
                Task { @MainActor in
                    do {
                        try LoginIntSession.openGoogleSession(
                            session: session,
                            identity: identity,
                            payload: payload
                        )
                    } catch {
                        AppAlert.alert("Connexion", error.localizedDescription)
                    }
                }
            },
            onOpenPasswordReset: { email in
                resetEmail = email
            },
            persistAccount: { _ in },
            onBack: { dismiss() }
        )
    }

    /// `onLogin` : compte déjà résolu par le registre local (aujourd'hui
    /// inatteignable, `accounts` étant vide). Sans mot de passe (biométrie), la
    /// session ne peut pas être ouverte faute de registre : erreur explicite.
    private func signInKnownAccount(_ account: LoginScrAccount, password: String?) async throws {
        guard let password else {
            throw DirectoryError(message: "Connexion biométrique indisponible sans registre local.")
        }
        try await session.signIn(email: account.email, password: password)
    }

    /// `resetEmail != nil` ⇔ feuille de réinitialisation présentée.
    private var isResetPresented: Binding<Bool> {
        Binding(
            get: { resetEmail != nil },
            set: { presented in if !presented { resetEmail = nil } }
        )
    }
}
