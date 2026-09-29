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
//  (`ForgotPasswordView`, R1-AUTH U03#1 : `openPasswordResetRequest` de
//  `App.tsx:2226-2228` → `ForgotPasswordScreen`). C'est ce type que branche
//  `LoginView`.
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
//  Port de `src/screens/LoginScreen.tsx` (+ `App.tsx`).
//
//  Parité RN↔Swift (vague 2, 2026-09-29) :
//    - `onLogin` sans mot de passe (P0) : compte administrateur → ouverture
//      locale **sans** session serveur (`App.tsx:1982-1985`) ; compte
//      biométrique → restauration de la session par la preuve d'appareil
//      (`restoreServerSessionFromDevice`, `App.tsx:1959-1980`).
//    - arbitrage fournisseur (P1) : une identité inconnue
//      (`resolutionKind == "signup"`) n'ouvre plus de session ; elle est
//      retenue (`LoginIntProviderSignupRouter`) au lieu d'appeler `proceed()`
//      (`App.tsx:2115-2123`, `:2155-2162`).
//    - présentation (P2) : la demande de lien de réinitialisation est présentée
//      en **plein écran**, comme la page `ForgotPasswordScreen` de la source
//      (`App.tsx:2540-2547`), et non en feuille modale.
//
//  Écarts assumés :
//    - le routage de `RootView` vers l'inscription (`setAuthStage('signup')`) et
//      l'ouverture de la surface d'administration après une ouverture locale
//      restent hors de ce fichier : `RootView`/`DuelloApp` ne sont pas
//      propriété de cette unité (voir rapport, « À raccorder »).
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
    /// Réouverture de compte fournisseur en attente de décision (U13 §2).
    @State private var pendingReuse: LoginIntProviderReuseAlert?

    var body: some View {
        LoginScrScreen(props: props)
            .fullScreenCover(isPresented: isResetPresented) {
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
            account: preferredAccount,
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

    /// `account` : compte rouvert de la source (`App.tsx:2514`). La source
    /// retient `preferredUserLoginAccount(availableAccounts)` (`App.tsx:992`),
    /// soit le **premier élève non invité** du registre (`loginAccountSelection.ts`),
    /// porté par `AcctSecAccountSelection` — sur l'écran de connexion, aucune
    /// session active ne prime. Il pré-remplit l'adresse (`LoginScreen.tsx:79`).
    private var preferredAccount: LoginScrAccount? {
        let preferredId = AcctSecAccountSelection.preferredLoginAccount(
            from: localAccounts.map {
                AcctSecAccountSelection.StoredAccount(
                    id: $0.id,
                    email: $0.email,
                    role: $0.role == .admin ? .admin : .user,
                    isGuest: $0.isGuest
                )
            }
        )?.id
        return localAccounts.first { $0.id == preferredId }
    }

    /// `onLogin` : compte déjà résolu par le registre local. Avec un mot de
    /// passe, le serveur ouvre la session ; sans (biométrie, ouverture après un
    /// code de secours administrateur), `openWithoutPassword` tranche selon le
    /// rôle (`login(loggedAccount, password?)`, `App.tsx:1926-2025`).
    private func signInKnownAccount(_ account: LoginScrAccount, password: String?) async throws {
        guard let password else {
            try await openWithoutPassword(account)
            return
        }
        try await session.signIn(email: account.email, password: password)
    }

    /// `onLogin` sans mot de passe (`App.tsx:1926-2025`).
    ///
    /// - compte **administrateur** : la source l'ouvre en local, sans session
    ///   serveur (`setHasActiveSession(true)`, `App.tsx:1982-1985`) ;
    /// - compte **utilisateur biométrique** : la preuve d'appareil rejoue la
    ///   session serveur (`restoreServerSessionFromDevice`, `App.tsx:1959-1980`).
    private func openWithoutPassword(_ account: LoginScrAccount) async throws {
        if account.role == .admin {
            session.profile = UserProfile()
            session.isSignedIn = true
            return
        }
        guard account.biometricEnabled else {
            throw DirectoryError(message: "Connexion biométrique indisponible sans registre local.")
        }
        try await restoreDeviceSession(account)
    }

    /// `restoreServerSessionFromDevice` (`serverSession.ts:470`, appelé par
    /// `App.tsx:1967`) : rejoue la session serveur du compte à partir de la
    /// preuve locale de l'appareil (`deviceRecoveryProof`), puis vérifie que le
    /// serveur a bien rendu le compte attendu avant de l'installer.
    private func restoreDeviceSession(_ account: LoginScrAccount) async throws {
        let proof = DevRegRecovery.proof(
            createSecret: false,
            accountId: account.id,
            accountEmail: account.email
        )
        let recovered = try await DevRegRecovery.restore(
            deviceId: proof.deviceId,
            recoverySecret: proof.recoverySecret,
            email: account.email
        )
        guard DevRegRecovery.normalizeEmail(recovered.account.email)
            == DevRegRecovery.normalizeEmail(account.email) else {
            throw DirectoryError(message: "La reconnexion biométrique n’est pas encore préparée pour ce compte. Reconnecte-toi une fois avec ton mot de passe, Google ou Apple, puis réactive la biométrie.")
        }
        try session.installSession(recovered.session)
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
        subjectKeyPath: WritableKeyPath<AcctStoredAccount, String?>,
        proceed: @escaping @MainActor () throws -> Void
    ) {
        // `resolution.kind === 'signup'` : la source n'ouvre **aucune** session
        // pour une identité fournisseur inconnue — elle retient l'identité et
        // route vers l'inscription (`App.tsx:2115-2123`, `:2155-2162`).
        if loginIntResolveProviderAccount(
            subject: subject,
            email: email,
            subjectKeyPath: subjectKeyPath
        ) == nil {
            LoginIntProviderSignupRouter.shared.pending = LoginIntPendingProviderSignup(
                provider: provider,
                subject: subject,
                email: email
            )
            return
        }
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

// MARK: - Identité fournisseur en attente d'inscription

/// `pendingGoogleIdentity` / `pendingAppleIdentity` de la source : identité
/// fournisseur certifiée pour un compte encore inconnu du registre local, que
/// l'inscription préremplira (`App.tsx:2115-2123`, `:2155-2162`).
struct LoginIntPendingProviderSignup: Equatable {
    var provider: LoginScrProviderReuse.Provider
    var subject: String
    var email: String
}

/// Identité fournisseur retenue pour l'inscription (`setPendingGoogleIdentity` /
/// `setPendingAppleIdentity` + `setAuthStage('signup')`).
///
/// La source bascule alors l'`authStage` de l'application ; `RootView` (hors de
/// cette unité) doit observer `pending` et présenter `SignupFlowView` avec
/// l'identité préremplie (voir rapport, « À raccorder »).
@MainActor
final class LoginIntProviderSignupRouter: ObservableObject {
    static let shared = LoginIntProviderSignupRouter()
    /// Identité en attente d'inscription (`nil` = aucune).
    @Published var pending: LoginIntPendingProviderSignup?
    private init() {}
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
/// Une résolution `login` lie en outre le `sub` fournisseur au compte du
/// registre (`saveAccount(resolution.account)` de la source, `App.tsx:2088` /
/// `:2128`), avant l'ouverture de la session.
///
/// - `consumingConfirmation` : `true` au moment d'installer la session, pour
///   consommer une confirmation déjà obtenue plus tôt dans le parcours.
@MainActor
func loginIntProviderReuseAlert(
    provider: LoginScrProviderReuse.Provider,
    subject: String,
    email: String,
    subjectKeyPath: WritableKeyPath<AcctStoredAccount, String?>,
    authStage: String,
    upgradingGuest: Bool,
    hasActiveSession: Bool,
    consumingConfirmation: Bool = false,
    proceed: @escaping @MainActor () -> Void
) -> LoginIntProviderReuseAlert? {
    if consumingConfirmation, loginIntConfirmedProviderSubjects.remove(subject) != nil {
        loginIntLinkProviderSubject(subject, keyPath: subjectKeyPath, email: email)
        proceed()
        return nil
    }
    let matched = loginIntResolveProviderAccount(
        subject: subject,
        email: email,
        subjectKeyPath: subjectKeyPath
    )
    let context = LoginScrProviderReuse.ProviderLoginContext(
        hasActiveSession: hasActiveSession,
        authStage: authStage,
        upgradingGuest: upgradingGuest,
        resolutionKind: matched == nil ? "signup" : "login"
    )
    guard let matched, LoginScrProviderReuse.shouldConfirmProviderLogin(context) else {
        // `resolution.kind === 'login'` : la source enregistre le compte rouvert
        // (`saveAccount(resolution.account)`, `App.tsx:2088` / `:2128`), ce qui
        // lie le `sub` fournisseur au compte du registre local.
        if matched != nil {
            loginIntLinkProviderSubject(subject, keyPath: subjectKeyPath, email: email)
        }
        proceed()
        return nil
    }
    let copy = LoginScrProviderReuse.providerReuseDialogCopy(
        provider: provider,
        summary: LoginScrProviderReuse.providerAccountSummary(matched.profile)
    )
    return LoginIntProviderReuseAlert(title: copy.title, message: copy.message) {
        loginIntConfirmedProviderSubjects.insert(subject)
        loginIntLinkProviderSubject(subject, keyPath: subjectKeyPath, email: email)
        proceed()
    }
}

/// `resolveGoogleAccount` / `resolveAppleAccount` de la source : retrouve le
/// compte du registre local par `sub` fournisseur d'abord, puis par e-mail
/// normalisé. `nil` correspond à `resolution.kind === 'signup'`.
@MainActor
private func loginIntResolveProviderAccount(
    subject: String,
    email: String,
    subjectKeyPath: KeyPath<AcctStoredAccount, String?>
) -> AcctStoredAccount? {
    let accounts = AcctLocalRegistry.loadAccounts()
    return accounts.first { $0.isUser && $0[keyPath: subjectKeyPath] == subject }
        ?? accounts.first {
            $0.isUser
                && AcctLocalRegistry.normalizeEmail($0.email)
                    == AcctLocalRegistry.normalizeEmail(email)
        }
}

/// `saveAccount(resolution.account)` (`App.tsx:2088`, `:2128`) : une connexion
/// fournisseur qui rouvre un compte du registre local y **lie le `sub`** de
/// l'identité (Google ou Apple). Sans cette écriture, `googleSubject` /
/// `appleSubject` reste vide : la reconnaissance ultérieure retombe sur
/// l'e-mail, alors que la source retrouve le compte par `sub` en premier.
@MainActor
private func loginIntLinkProviderSubject(
    _ subject: String,
    keyPath: WritableKeyPath<AcctStoredAccount, String?>,
    email: String
) {
    guard let matched = loginIntResolveProviderAccount(
        subject: subject,
        email: email,
        subjectKeyPath: keyPath
    ), matched[keyPath: keyPath] != subject else { return }
    var linked = matched
    linked[keyPath: keyPath] = subject
    AcctLocalRegistry.saveAccount(linked)
}
