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
//  Câblage vague 2 (24/09/2026) :
//    - registre local (U8 §2) : `accounts` et `persistAccount` sont branchés sur
//      `AcctLocalRegistry`. La récupération par code de secours administrateur
//      et l'activation de compte (`onLogin`) ne sont plus des no-ops.
//      `LoginScrAccount` ne porte ni profil ni date de création : la
//      reconstruction d'un `AcctStoredAccount` reprend ces champs de
//      l'enregistrement existant (même identifiant).
//    - réouverture fournisseur (U13 §2) : `onGoogleAuthenticated` /
//      `onAppleAuthenticated` interrogent
//      `LoginScrProviderReuse.shouldConfirmProviderLogin` avant d'ouvrir la
//      session. Sur cet écran `authStage` vaut `"login"` — rouvrir le compte
//      existant est l'effet attendu — la garde ne se déclenche donc jamais ici,
//      mais le contexte est construit comme dans la source.
//
//  La connexion Apple passe par `LoginIntSession` (pont documenté).
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
    /// Message d'échec fournisseur (Apple), sans canal dans `LoginScrScreen`.
    @State private var providerError: String?
    /// Réouverture de compte fournisseur en attente de décision (U13 §2).
    @State private var pendingReuse: LoginIntProviderReuseAlert?

    var body: some View {
        LoginScrScreen(props: props)
            .sheet(isPresented: isResetPresented) {
                PasswordResetView(email: resetEmail ?? "")
            }
            .alert("Connexion", isPresented: isProviderErrorPresented) {
                Button("OK", role: .cancel) { providerError = nil }
            } message: {
                Text(providerError ?? "")
            }
            .alert(pendingReuse?.title ?? "", isPresented: isReusePresented) {
                Button("Ouvrir mon compte") {
                    let alert = pendingReuse
                    pendingReuse = nil
                    alert?.proceed()
                }
                Button("Continuer la création", role: .cancel) { pendingReuse = nil }
            } message: {
                Text(pendingReuse?.message ?? "")
            }
    }

    // MARK: Rappels

    /// `LoginScrProps` câblés sur l'application.
    private var props: LoginScrProps {
        LoginScrProps(
            account: nil,
            accounts: localAccounts,
            onLogin: { account, password in
                try await signInKnownAccount(account, password: password)
            },
            onPasswordLogin: { email, password in
                try await session.signIn(email: email, password: password)
            },
            onAppleAuthenticated: { identity, payload in
                Task { @MainActor in
                    authenticateProvider(
                        provider: .apple,
                        subject: identity.subject,
                        email: identity.email,
                        subjectKeyPath: \AcctStoredAccount.appleSubject,
                        proceed: { try LoginIntSession.openAppleSession(session: session, identity: identity, payload: payload) }
                    )
                }
            },
            onGoogleAuthenticated: { identity, payload in
                Task { @MainActor in
                    authenticateProvider(
                        provider: .google,
                        subject: identity.subject,
                        email: identity.email,
                        subjectKeyPath: \AcctStoredAccount.googleSubject,
                        proceed: { try LoginIntSession.openGoogleSession(session: session, identity: identity, payload: payload) }
                    )
                }
            },
            onOpenPasswordReset: { email in
                resetEmail = email
            },
            persistAccount: { account in
                saveLocalAccount(account)
            },
            onBack: { dismiss() }
        )
    }

    /// `accounts` : projection du registre local (`AcctLocalRegistry`, porté par
    /// U8) vers l'instantané lu par l'écran (`LoginScrAccount`). Lève la limite
    /// historique : la récupération par code de secours administrateur et
    /// l'activation de compte (`onLogin`) deviennent atteignables.
    private var localAccounts: [LoginScrAccount] {
        AcctLocalRegistry.loadAccounts().map { stored in
            LoginScrAccount(
                id: stored.id,
                email: stored.email,
                displayName: stored.displayName,
                role: stored.role,
                passwordHash: stored.passwordHash,
                googleSubject: stored.googleSubject,
                appleSubject: stored.appleSubject,
                biometricEnabled: stored.biometricEnabled,
                requiresPasswordSetup: stored.requiresPasswordSetup,
                recoveryCodeHash: stored.recoveryCodeHash,
                isGuest: stored.guest
            )
        }
    }

    /// `onLogin` : compte déjà résolu par le registre local. Sans mot de passe
    /// (biométrie), aucune entrée serveur ne peut ouvrir la session : erreur
    /// explicite.
    private func signInKnownAccount(_ account: LoginScrAccount, password: String?) async throws {
        guard let password else {
            throw DirectoryError(message: "Connexion biométrique indisponible sans registre local.")
        }
        try await session.signIn(email: account.email, password: password)
    }

    /// `persistAccount` : `saveAccount` du registre local (`utils/auth.ts`).
    /// `LoginScrAccount` ne portant ni profil ni date de création, ils sont
    /// repris de l'enregistrement existant (même identifiant), à défaut du
    /// profil courant de la session.
    private func saveLocalAccount(_ account: LoginScrAccount) {
        let existing = AcctLocalRegistry.loadAccounts().first { $0.id == account.id }
        AcctLocalRegistry.saveAccount(
            AcctStoredAccount(
                id: account.id,
                email: account.email,
                displayName: account.displayName,
                role: account.role,
                passwordHash: account.passwordHash,
                googleSubject: account.googleSubject,
                appleSubject: account.appleSubject,
                biometricEnabled: account.biometricEnabled,
                requiresPasswordSetup: account.requiresPasswordSetup,
                recoveryCodeHash: account.recoveryCodeHash,
                createdAt: existing?.createdAt,
                guest: account.isGuest,
                profile: existing?.profile ?? session.profile
            )
        )
    }

    /// `onGoogleAuthenticated` / `onAppleAuthenticated` : interroge la garde de
    /// réouverture (`shouldConfirmProviderLogin`, U13 §2) avant d'ouvrir la
    /// session fournisseur. Si l'alerte est requise, elle est présentée et
    /// « Continuer la création » laisse la session fermée
    /// (`ProviderAuthFollowUp.declined`).
    @MainActor
    private func authenticateProvider(
        provider: LoginScrProviderReuse.Provider,
        subject: String,
        email: String,
        subjectKeyPath: KeyPath<AcctStoredAccount, String?>,
        proceed: @escaping @MainActor () throws -> Void
    ) {
        let open: @MainActor () -> Void = {
            do {
                try proceed()
            } catch {
                providerError = error.localizedDescription
            }
        }
        if let alert = loginIntProviderReuseAlert(
            provider: provider,
            subject: subject,
            email: email,
            subjectKeyPath: subjectKeyPath,
            authStage: "login",
            upgradingGuest: false,
            hasActiveSession: session.isSignedIn,
            proceed: open
        ) {
            pendingReuse = alert
        }
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

    /// `pendingReuse != nil` ⇔ alerte de réouverture de compte présentée.
    private var isReusePresented: Binding<Bool> {
        Binding(
            get: { pendingReuse != nil },
            set: { presented in if !presented { pendingReuse = nil } }
        )
    }
}

// MARK: - Garde de réouverture fournisseur (U13 §2)

/// Alerte de réouverture de compte fournisseur en attente de décision
/// (`providerReuseDialogCopy`). « Ouvrir mon compte » exécute `proceed` ;
/// « Continuer la création » laisse la valeur retomber, ce qui équivaut à
/// `ProviderAuthFollowUp.declined` (l'authentification reste sans suite).
struct LoginIntProviderReuseAlert {
    let title: String
    let message: String
    let proceed: @MainActor () -> Void
}

/// Identités fournisseur déjà confirmées pendant un parcours d'inscription.
///
/// La source installe la session **dans** le rappel du bouton fournisseur : la
/// confirmation et l'ouverture ne font qu'un. Le port Swift diffère
/// l'installation à la fin du parcours (`OnboardingView.openAccount`) ; cette
/// mémoire — une seule fois par identité — évite de reposer la question à ce
/// moment-là.
@MainActor private var loginIntConfirmedProviderSubjects: Set<String> = []

/// Garde de réouverture (`shouldConfirmProviderLogin`).
///
/// Résout l'identité fournisseur contre le registre local (`AcctLocalRegistry`)
/// dans le même ordre que `resolveGoogleAccount` / `resolveAppleAccount` de la
/// source — `sub` fournisseur d'abord, puis e-mail — pour en déduire
/// `resolutionKind`, interroge la garde et, si elle l'exige, prépare l'alerte
/// `providerReuseDialogCopy(provider:summary:)`. Renvoie `nil` quand il faut
/// poursuivre : `proceed` est alors déjà appelé.
///
/// - `consumingConfirmation` : `true` au moment d'installer la session, pour
///   consommer une confirmation déjà obtenue plus tôt dans le parcours.
@MainActor
func loginIntProviderReuseAlert(
    provider: LoginScrProviderReuse.Provider,
    subject: String,
    email: String,
    subjectKeyPath: KeyPath<AcctStoredAccount, String?>,
    authStage: String,
    upgradingGuest: Bool,
    hasActiveSession: Bool,
    consumingConfirmation: Bool = false,
    proceed: @escaping @MainActor () -> Void
) -> LoginIntProviderReuseAlert? {
    if consumingConfirmation, loginIntConfirmedProviderSubjects.remove(subject) != nil {
        proceed()
        return nil
    }
    let accounts = AcctLocalRegistry.loadAccounts()
    let matched = accounts.first { $0.isUser && $0[keyPath: subjectKeyPath] == subject }
        ?? accounts.first {
            $0.isUser
                && AcctLocalRegistry.normalizeEmail($0.email)
                    == AcctLocalRegistry.normalizeEmail(email)
        }
    let context = LoginScrProviderReuse.ProviderLoginContext(
        hasActiveSession: hasActiveSession,
        authStage: authStage,
        upgradingGuest: upgradingGuest,
        resolutionKind: matched == nil ? "signup" : "login"
    )
    guard let matched, LoginScrProviderReuse.shouldConfirmProviderLogin(context) else {
        proceed()
        return nil
    }
    let copy = LoginScrProviderReuse.providerReuseDialogCopy(
        provider: provider,
        summary: LoginScrProviderReuse.providerAccountSummary(matched.profile)
    )
    return LoginIntProviderReuseAlert(title: copy.title, message: copy.message) {
        loginIntConfirmedProviderSubjects.insert(subject)
        proceed()
    }
}
