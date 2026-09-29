import SwiftUI

//  Port de App.tsx (RN) — racine de l'application : accueil tant qu'aucune
//  session n'est ouverte, onglets principaux ensuite, et hôtes racine (paywall
//  des outils, célébration de palier, notifications poussées, invite de capture
//  photo à distance). Le parcours d'inscription est partagé par l'accueil
//  (`signupOpen`) et par la branche `signup` du fournisseur
//  (`LoginIntProviderSignupRouter.shared.pending`).
//
//  Raccords 04 (2026-09-29)
//  ------------------------
//  - Complétion de la réinitialisation (écart 04#1) : l'écran expose
//    `onSave(email:token:password:)` ; l'hôte rejoue ici
//    `AcctSecResetCompletionRuntime.completePasswordResetFlow` avec un backend
//    vivant (`liveBackend(session:)`). Transport, session **et** empreinte du
//    nouveau mot de passe (registre local) sont ainsi écrits, comme
//    `completePasswordReset` de la source (`App.tsx:2194-2223`).
//  - Entrée de l'écran (écart 04#3) : la source **remplace** l'arbre d'un coup
//    (`App.tsx:2475-2490`) ; la racine rend l'écran par **rendu conditionnel**,
//    sans `.fullScreenCover` à glissement.
//  - Alerte de résultat (écart 04 NEW-N2) : les issues non silencieuses
//    (`login-required`, `outcome-unknown`) présentent l'alerte de
//    `AcctSecResetCompletionAlert` (`App.tsx:2232-2237`).
//
//  Cible : iOS 16.

@main
struct DuelloApp: App {
#if os(iOS)
    /// Délégué d'application des notifications poussées (écart 20#1) : reçoit le
    /// jeton APNs et route le tap natif. Sans cette instanciation,
    /// `PushNotifAppDelegate` n'existait jamais et toute la voie native restait
    /// morte. Garde `os(iOS)` : `UIApplicationDelegateAdaptor` n'existe pas dans
    /// le shim Linux (la cible Xcode, elle, le compile).
    @UIApplicationDelegateAdaptor(PushNotifAppDelegate.self) private var pushDelegate
#endif

    @StateObject private var session = SessionStore()
    /// Progression locale partagée : injectée à la racine car plusieurs écrans
    /// l'exigent en `@EnvironmentObject` (`DuelloProgressView`,
    /// `TrainingCatalogView`) — sans elle, l'app plante à leur ouverture.
    @StateObject private var progress = ProgressStore()
    /// File des paliers franchis : alimentée par les écritures XP de `progress`
    /// (voir `LevelUpQueue.start(observing:)`), présentée à la racine par
    /// `LevelUpCelebrationCoordinator` — équivalent du `useLevelUpQueue` Expo.
    @StateObject private var levelUpQueue = LevelUpQueue()
    /// Demande de réinitialisation reçue par lien profond : présentée en plein
    /// écran par le **seul** écran « Nouveau mot de passe » (`PasswordResetView`),
    /// comme `PasswordResetScreen` côté Expo (R1-AUTH, U04#3).
    @State private var passwordResetRequest: AcctSecResetRequest?
    /// Alerte de résultat de la complétion (écart 04 NEW-N2) : présentée à la
    /// racine une fois la demande réglée (`AcctSecResetCompletionAlert`).
    @State private var resetAlert: AcctSecResetAlert?

    /// Schéma d'URL de la variante (dev : `duello-dev`, cf. `CFBundleURLTypes`
    /// de `Info.plist` et `DUELLO_PASSWORD_RESET_APP_SCHEME` du backend) : repli
    /// `legacy-native` du contexte de lecture.
    private static let resetScheme = "duello-dev"

    /// App Link HTTPS de développement (`passwordResetAppUrl` de
    /// `config/duello-development.json`, lu par `config/appLinking.ts`) : le
    /// lien entrant y porte ses paramètres dans le fragment
    /// (`…/reset-password/app#reset-password?email=…&token=…`, R1-AUTH, U08#1).
    private static let resetAppURL: String? =
        "https://duello-development-api-relay.duello.workers.dev/reset-password/app"

    /// Contexte de lecture du lien de réinitialisation : branche `app` (App Link
    /// HTTPS) d'abord, schéma personnalisé en repli — comme
    /// `useDuelloIncomingLinkSubscription` (`app` si `passwordResetAppUrl`, sinon
    /// `legacy-native`).
    private static var resetContext: AcctSecResetLinkContext {
        if let appURL = resetAppURL {
            return .app(baseURL: appURL, legacyScheme: resetScheme)
        }
        return .legacyNative(scheme: resetScheme)
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if let request = passwordResetRequest {
                    // Écart 04#3 : la source **remplace** l'arbre
                    // (`App.tsx:2475-2490`) au lieu de présenter une modale à
                    // glissement — l'écran prend toute la fenêtre, sans
                    // animation. Il prévient sa fermeture par `onClose`
                    // (`dismiss()` n'aurait plus d'effet ici).
                    PasswordResetView(
                        email: request.email,
                        token: request.token,
                        onSave: { email, token, password in
                            try await completePasswordReset(
                                email: email,
                                token: token,
                                password: password
                            )
                        },
                        onClose: { _ = clearPasswordResetRequestIfCurrent(token: request.token) }
                    )
                } else {
                    RootView()
                        // Hôte racine de la fenêtre de paiement des outils Premium
                        // (`PremiumToolPaywallHost` de la source, `App.tsx:2587`) : une
                        // seule fenêtre suffit pour tous les outils Premium.
                        .premToolPaywallHost(token: session.token)
                        .environmentObject(session)
                        .environmentObject(progress)
                        // Retrait du focus clavier quand l'app quitte le premier plan
                        // (`useDismissKeyboardOnAppBackground` du hook Expo) : les
                        // écrans restent montés, seul le premier répondant est retiré.
                        .dismissKeyboardOnAppBackground()
                        // Célébration présentée par-dessus toute la hiérarchie (onglets
                        // compris), comme le `Modal` transparent `overFullScreen` de la
                        // source. File vide → le coordinateur ne rend rien.
                        .overlay { LevelUpCelebrationCoordinator(queue: levelUpQueue) }
                }
            }
            // Démarre l'observation de la source XP **une fois** : la
            // première émission est le chargement initial (non célébré),
            // les écritures suivantes alimentent la file.
            .task { levelUpQueue.start(observing: progress) }
            // Retour du navigateur Google vers l'app (schéma du client
            // iOS inversé), comme le handle de lien profond Expo.
            .onOpenURL { url in
                GoogleAuthService.shared.handle(url)
                // Lien de réinitialisation servi par le backend : App Link
                // HTTPS (branche `app`) ou schéma personnalisé en repli.
                if let request = AcctSecResetLink.request(
                    from: url.absoluteString,
                    context: Self.resetContext
                ) {
                    passwordResetRequest = request
                }
            }
            // Alerte de résultat de la complétion (écart 04 NEW-N2), comme
            // `AppAlert.alert` de la source (`App.tsx:2232-2237`).
            .alert(resetAlert?.title ?? "", isPresented: isResetAlertPresented) {
                Button("OK", role: .cancel) { resetAlert = nil }
            } message: {
                Text(resetAlert?.message ?? "")
            }
        }
    }

    /// `completePasswordReset` (`App.tsx:2194-2223`) : la complétion est exécutée
    /// **dans l'hôte**, avec le mot de passe venu de l'écran (`onSave`).
    /// `completePasswordResetFlow` compose le transport, la session et l'écriture
    /// du registre local — dont l'empreinte du nouveau mot de passe (écart 04#1).
    /// La demande n'est effacée que si elle est encore courante
    /// (`settlePasswordResetRequest`, `passwordResetGeneration.ts`) ; une issue
    /// non silencieuse est montrée par une alerte (écart 04 NEW-N2).
    private func completePasswordReset(
        email: String,
        token: String,
        password: String
    ) async throws {
        let result = try await AcctSecResetCompletionRuntime.completePasswordResetFlow(
            options: resetRuntimeOptions(email: email, token: token, password: password)
        )
        guard clearPasswordResetRequestIfCurrent(token: token) else { return }
        resetAlert = AcctSecResetCompletionAlert.alert(for: result)
    }

    /// Options de la complétion (`PasswordResetRuntimeOptions` de
    /// `passwordResetCompletionRuntime.ts:26-33`) : registre local, reconstruction
    /// du compte récupéré, garde de génération, ouverture de session et
    /// révocation, adossées au backend vivant de la réinitialisation.
    private func resetRuntimeOptions(
        email: String,
        token: String,
        password: String
    ) -> AcctSecResetRuntimeOptions {
        AcctSecResetRuntimeOptions(
            email: email,
            token: token,
            password: password,
            accounts: Self.localResetAccounts(),
            recoverAccount: { recovered in
                // `accountFromServerRecovery` (`App.tsx:330-347`) : le compte
                // reconstruit n'a pas d'empreinte — `updatedPasswordResetAccount`
                // y pose celle du nouveau mot de passe.
                LoginScrAccount(
                    id: SessionStore.localAccountId(for: recovered.email),
                    email: LoginScrCredential.normalize(recovered.email),
                    displayName: recovered.displayName,
                    role: .user,
                    passwordHash: nil,
                    googleSubject: recovered.googleSubject,
                    appleSubject: recovered.appleSubject,
                    biometricEnabled: false,
                    requiresPasswordSetup: false,
                    recoveryCodeHash: nil,
                    isGuest: false
                )
            },
            isCurrent: { isCurrentResetRequest(token: token) },
            authenticate: { _, isCurrent in
                // `login(resetAccount, undefined, isCurrent)` : la session et le
                // profil ont déjà été posés par `saveServerSession`
                // (`SessionStore.installSession`) — rien d'autre à committer ici.
                _ = isCurrent
            },
            revokeApplicationAuthentication: {
                guard isCurrentResetRequest(token: token) else { return }
                Task { await session.signOut() }
            },
            sessionBackend: AcctSecResetCompletionRuntime.liveBackend(session: session)
        )
    }

    /// `accounts` : projection du registre local (`AcctLocalRegistry`) vers
    /// l'instantané lu par la complétion (`LoginScrAccount`), comme
    /// `LoginIntAssembly.localAccounts`.
    private static func localResetAccounts() -> [LoginScrAccount] {
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

    /// La demande de réinitialisation `token` est-elle encore la courante ?
    private func isCurrentResetRequest(token: String) -> Bool {
        passwordResetRequest?.token == token
    }

    /// `clearPasswordResetRequest(token)` : efface la demande **courante** ;
    /// renvoie faux si une demande plus récente l'a remplacée (une demande
    /// périmée ne doit jamais effacer la suivante).
    @discardableResult
    private func clearPasswordResetRequestIfCurrent(token: String) -> Bool {
        guard isCurrentResetRequest(token: token) else { return false }
        passwordResetRequest = nil
        return true
    }

    /// `resetAlert != nil` ⇔ alerte de résultat présentée.
    private var isResetAlertPresented: Binding<Bool> {
        Binding(
            get: { resetAlert != nil },
            set: { presented in if !presented { resetAlert = nil } }
        )
    }
}

/// Route racine : écran d'accueil tant qu'aucune session n'est ouverte,
/// onglets principaux ensuite. Reprend le parcours de l'app Expo
/// (WelcomeScreen puis BottomNavigation avec Mon compte / Entraînement / Défis).
struct RootView: View {
    @EnvironmentObject private var session: SessionStore

    /// Inscription ouverte depuis l'accueil (`authStage === 'signup'` de la
    /// source) : elle se joue **avant** toute session, et prend donc la main
    /// sur la racine tant qu'elle n'est pas terminée.
    @State private var signupOpen = false

    /// Branche `signup` du fournisseur (`App.tsx:2115-2123`, `:2155-2162`) :
    /// quand une connexion Google/Apple ne correspond à **aucun** compte du
    /// registre local, `LoginIntAssembly` retient l'identité ici
    /// (`LoginIntProviderSignupRouter.shared.pending`) au lieu d'ouvrir une
    /// session ; la racine bascule alors sur le parcours d'inscription, comme
    /// `setAuthStage('signup')`. Le préremplissage de l'identité par le
    /// parcours est « À raccorder » (lot W04).
    @ObservedObject private var providerSignup = LoginIntProviderSignupRouter.shared

    /// Vrai quand le stockage local et le lien entrant sont résolus
    /// (`hasLoadedStorage` / `hasResolvedInitialLink` d'Expo). `SessionStore`
    /// restaure la session de façon **synchrone** : l'état bascule au premier
    /// tour, la marque de chargement n'est qu'un repère de parité.
    @State private var rootReady = false

    /// Vrai tant que le **programme** n'est pas connu de l'appareil : connexion
    /// sur un appareil neuf, ou première connexion Google/Apple. Le profil d'un
    /// compte déjà inscrit est relu du registre local par `installSession`, donc
    /// une simple reconnexion ne passe pas par ici.
    private var needsOnboarding: Bool {
        session.profile.year.isEmpty || session.profile.track.isEmpty
    }

    var body: some View {
        Group {
            // Écran de chargement racine (`App.tsx:2467-2473`) : tant que le
            // stockage et le lien entrant ne sont pas résolus, la racine peint
            // la marque de chargement sur fond blanc, pas l'accueil.
            if !rootReady {
                ZStack {
                    Theme.background.ignoresSafeArea()
                    Ui2LoadingMark(delayMs: 0)
                }
            // Mode capture : la racine peut être figée sur l'accueil signé-out
            // même quand une session factice est semée (`welcome`, `login`,
            // `register` — la feuille d'authentification s'ouvre d'elle-même).
            } else if ScreenshotTour.welcomeDestination != nil {
                WelcomeView(onCreateAccount: { signupOpen = true })
            } else if signupOpen || providerSignup.pending != nil {
                // Inscription : ouverte depuis l'accueil (`signupOpen`) **ou**
                // par la branche `signup` du fournisseur (`pending`) — les deux
                // se rejoignent sur le même parcours, comme `authStage ===
                // 'signup'` de la source. À la sortie, l'identité fournisseur
                // en attente est consommée (jamais rejouée au prochain tour).
                SignupFlowView {
                    signupOpen = false
                    providerSignup.pending = nil
                }
            } else if session.isSignedIn {
                if needsOnboarding {
                    // Complète le **programme** manquant (appareil neuf,
                    // connexion Google/Apple) — mode `.guest` : étapes de
                    // programme seules, **jamais** le parcours de création de
                    // compte, qui demanderait pseudo/mot de passe/cadeau à un
                    // élève déjà inscrit. La source Expo ne connaît pas ce
                    // besoin : son onboarding n'est monté qu'avant session
                    // (`authStage === 'signup'`), et `restoreProfile` remplit
                    // `track`/`year` par défaut.
                    //
                    // « Revenir à l'accueil » (première étape) : la racine ne
                    // quitte l'onboarding que si la session est fermée —
                    // sinon `RootView` le réafficherait aussitôt.
                    OnboardingView(
                        mode: .guest,
                        onCancel: { Task { @MainActor in await session.signOut() } }
                    ) {}
                } else {
                    MainTabView()
                }
            } else {
                WelcomeView(onCreateAccount: { signupOpen = true })
            }
        }
        // `App.tsx:2495,2557` : la bascule accueil↔onglets **remplace** l'arbre
        // d'un coup, sans fondu ; l'état est résolu dès le premier tour.
        .task { rootReady = true }
        // Services racine montés dès qu'une session est ouverte (R7, U19#3 /
        // U20#1) : synchronisation d'abonnement (`SubscriptionPaymentSync`,
        // `App.tsx:2599`), inscription aux notifications poussées
        // (`PushNotificationCoordinator`, `App.tsx:2636`) et **invite de capture
        // photo à distance** (`RemotePhotoCaptureCoordinator`, `App.tsx:2603`).
        // Vues sans rendu (0 × 0) ; l'abonnement est recréé par compte (`.id`).
        .overlay {
            if session.isSignedIn {
                ZStack {
                    PremSubscriptionSyncView(
                        email: session.profile.email,
                        token: session.token
                    )
                    .id(session.profile.email)
                    PushNotifRootMount()
                    // Écart 21#1 : la source ne monte le coordinateur que pour un
                    // compte **non invité** (`!isGuestAccount(account)`), sans
                    // équivalent direct de `guest` ici → garde `isSignedIn`.
                    RemPhotoRxCaptureHost()
                }
            }
        }
    }
}
