//
//  LoginIntAssembly.swift
//  Duello
//
//  LOT 20 — assemblage de l'écran de connexion **sombre** dans l'application.
//
//  Fournit les rappels de `LoginScrProps` (lot 14-A, porté de
//  `src/screens/LoginScreen.tsx`) à `LoginScrScreen`, en les câblant sur
//  l'application : `SessionStore` (connexion serveur), fermeture de la feuille
//  (« lien de retour ») et demande de lien de réinitialisation
//  (`ForgotPasswordView`, unité 03 : `openPasswordResetRequest` de
//  `App.tsx:2226-2228` → `ForgotPasswordScreen`). C'est ce type que branche
//  `LoginView`.
//
//  V1 2026-09-26 — écart #1 du rapport `out/02-connexion.md`. Le registre local
//  (`utils/auth.ts` : `saveAccount` / `loadAccounts`) est porté par
//  `LoginScrRegistry.swift` et câblé ici, comme la source (`App.tsx:2514-2515`) :
//    - `accounts` vient du registre persisté, un administrateur neuf y est
//      semé comme au démarrage (`App.tsx:867-875`) ;
//    - `account` est le compte utilisateur proposé
//      (`preferredUserLoginAccount`), il pré-remplit l'adresse ;
//    - `persistAccount` écrit réellement le compte rouvert / activé ;
//    - `onPasswordLogin` mémorise le compte élève validé par le serveur
//      (`loginWithRemotePassword`, `App.tsx:2017-2022`), ce qui alimente le
//      registre en comptes utilisateurs (pré-remplissage, réouverture).
//  La connexion compte connu, l'activation et la récupération administrateur et
//  la proposition biométrie ne sont donc plus inatteignables.
//
//  Limite assumée : l'ouverture de session par biométrie (sans mot de passe)
//  exige la reconnexion serveur par preuve d'appareil
//  (`restoreServerSessionFromDevice`), non portée ; `onLogin` le dit
//  explicitement au lieu d'un échec silencieux.
//  La connexion Apple passe par `LoginIntSession` (pont documenté).
//
//  Cible : iOS 16. Aucune dépendance externe.
//

import SwiftUI

/// Écran de connexion sombre branché sur `SessionStore`.
struct LoginIntAssembly: View {
    @EnvironmentObject private var session: SessionStore
    @Environment(\.dismiss) private var dismiss

    /// Adresse préremplie de la demande de lien (feuille `ForgotPasswordView`).
    @State private var resetEmail: String?
    /// Message d'échec fournisseur (Apple), sans canal dans `LoginScrScreen`.
    @State private var providerError: String?
    /// Registre local des comptes (`LoginScrRegistry`), chargé au premier rendu
    /// pour que l'adresse du compte proposé soit pré-remplie (`account`).
    @State private var accounts: [LoginScrAccount] = LoginScrRegistry.load()

    var body: some View {
        LoginScrScreen(props: props)
            .sheet(isPresented: isResetPresented) {
                // Unité 03 : le lien « J'ai oublié mon mot de passe » ouvre
                // l'écran de **demande de lien** (`ForgotPasswordScreen`), pas
                // le formulaire de nouveau mot de passe (réservé au lien
                // entrant, `PasswordResetView`).
                ForgotPasswordView(initialEmail: resetEmail ?? "")
            }
            .alert("Connexion", isPresented: isProviderErrorPresented) {
                Button("OK", role: .cancel) { providerError = nil }
            } message: {
                Text(providerError ?? "")
            }
    }

    // MARK: Rappels

    /// `LoginScrProps` câblés sur l'application.
    private var props: LoginScrProps {
        LoginScrProps(
            account: LoginScrRegistry.preferredAccount(in: accounts),
            accounts: accounts,
            onLogin: { account, password in
                try await signInKnownAccount(account, password: password)
            },
            onPasswordLogin: { email, password in
                try await signInRecoveredAccount(email: email, password: password)
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
                        providerError = error.localizedDescription
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
                        providerError = error.localizedDescription
                    }
                }
            },
            onOpenPasswordReset: { email in
                resetEmail = email
            },
            persistAccount: { account in
                await persist(account)
            },
            onBack: { dismiss() }
        )
    }

    /// `onLogin` : compte déjà résolu par le registre local (`LoginScrRegistry`).
    /// Sans mot de passe (biométrie), l'ouverture exigerait la reconnexion
    /// serveur par preuve d'appareil (`restoreServerSessionFromDevice`), non
    /// portée : même message que la source pour cette branche (`App.tsx:1964`).
    private func signInKnownAccount(_ account: LoginScrAccount, password: String?) async throws {
        guard let password else {
            throw DirectoryError(
                message: "La reconnexion biométrique n’est pas encore préparée pour ce compte. "
                    + "Reconnecte-toi une fois avec ton mot de passe, Google ou Apple, "
                    + "puis réactive la biométrie."
            )
        }
        try await session.signIn(email: account.email, password: password)
    }

    /// `onPasswordLogin` : ouvre la session serveur, puis mémorise le compte
    /// élève (`loginWithRemotePassword`, `App.tsx:2017-2022` : `saveAccount`).
    /// Sans cela le registre ne contiendrait jamais de compte utilisateur.
    @MainActor
    private func signInRecoveredAccount(email: String, password: String) async throws {
        try await session.signIn(email: email, password: password)
        LoginScrRegistry.save(
            LoginScrRegistry.recoveredAccount(
                email: email,
                displayName: session.profile.displayName
            )
        )
        accounts = LoginScrRegistry.load()
    }

    /// `persistAccount` : écrit le compte rouvert / activé dans le registre.
    @MainActor
    private func persist(_ account: LoginScrAccount) async {
        LoginScrRegistry.save(account)
        accounts = LoginScrRegistry.load()
    }

    /// `resetEmail != nil` ⇔ feuille de réinitialisation présentée.
    private var isResetPresented: Binding<Bool> {
        Binding(
            get: { resetEmail != nil },
            set: { presented in if !presented { resetEmail = nil } }
        )
    }

    /// `providerError != nil` ⇔ alerte d'échec fournisseur présentée.
    private var isProviderErrorPresented: Binding<Bool> {
        Binding(
            get: { providerError != nil },
            set: { presented in if !presented { providerError = nil } }
        )
    }
}
