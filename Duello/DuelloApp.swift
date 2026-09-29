import SwiftUI

//  Port de App.tsx (RN) — racine de l'application : accueil tant qu'aucune
//  session n'est ouverte, onglets principaux ensuite, et hôtes racine (paywall
//  des outils, célébration de palier, notifications poussées).
//
//  Écarts assumés (2026-09-29)
//  ---------------------------
//  - Complétion de la réinitialisation de mot de passe (écart 04#1) : la source
//    exécute `completePasswordResetFlow` **dans l'hôte** (transport +
//    `savePasswordResetSession`), le mot de passe venant du formulaire
//    (`onSave(password)`, `App.tsx:2194-2223`). Le port Swift fait le transport
//    dans l'écran (`PasswordResetView.submit`, `AccountPasswordResetView.swift`)
//    et ne rend que la session : l'hôte ne peut donc pas rejouer le runtime
//    (qui referait le transport, double appel serveur). La session est confiée
//    au **backend vivant** de la réinitialisation (`AcctSecResetSessionBackend`)
//    ; l'empreinte du compte local, qui a besoin du mot de passe en clair,
//    reste à l'écran — voir « À raccorder » du rapport.
//  - Entrée de l'écran de réinitialisation (écart 04#3) : la source remplace
//    l'arbre **instantanément** (`App.tsx:2476`) ; `.fullScreenCover` glisse.
//    Passer au rendu conditionnel racine exige que l'écran prévienne sa
//    fermeture (`onClose`) — son bouton retour appelle `dismiss()`, sans effet
//    hors présentation — ce qui touche `AccountPasswordResetView.swift`.
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
                // Démarre l'observation de la source XP **une fois** : la
                // première émission est le chargement initial (non célébré),
                // les écritures suivantes alimentent la file.
                .task { levelUpQueue.start(observing: progress) }
                // Célébration présentée par-dessus toute la hiérarchie (onglets
                // compris), comme le `Modal` transparent `overFullScreen` de la
                // source. File vide → le coordinateur ne rend rien.
                .overlay { LevelUpCelebrationCoordinator(queue: levelUpQueue) }
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
                .fullScreenCover(item: $passwordResetRequest) { request in
                    PasswordResetView(
                        email: request.email,
                        token: request.token,
                        onAuthenticated: { serverSession in
                            completePasswordReset(serverSession: serverSession)
                        }
                    )
                }
        }
    }

    /// `completePasswordReset` (`App.tsx:2194-2223`) : la session rendue par
    /// l'écran de réinitialisation est confiée au **backend vivant** de la
    /// réinitialisation (`AcctSecResetSessionBackend`) — la couture de session
    /// que `AcctSecResetCompletionRuntime.completePasswordResetFlow` attend.
    ///
    /// Écart assumé : le mot de passe en clair n'existe que dans l'écran ; le
    /// runtime, qui referait le transport, ne peut donc pas être rappelé ici
    /// (voir l'en-tête).
    private func completePasswordReset(serverSession: ServerSession) {
        Task {
            try? await AcctSecResetSession.savePasswordResetSession(
                session: serverSession,
                account: resetLocalAccount(email: serverSession.email),
                backend: resetSessionBackend
            )
        }
    }

    /// Fiche locale du compte réinitialisé, lue du registre
    /// (`AcctLocalRegistry`) — même identité que `SessionStore.installSession`.
    private func resetLocalAccount(email: String) -> LoginScrAccount {
        let stored = AcctLocalRegistry.findAccountByEmail(
            AcctLocalRegistry.loadAccounts(),
            email: email
        )
        return LoginScrAccount(
            id: stored?.id ?? SessionStore.localAccountId(for: email),
            email: email,
            displayName: stored?.displayName ?? email,
            role: stored?.role ?? .user,
            passwordHash: stored?.passwordHash
        )
    }

    /// Backend vivant de la réinitialisation (`AcctSecResetSessionBackend`) : la
    /// session est persistée par `SessionStore`, le compte local est déjà
    /// réécrit par `installSession`/`persistProfile` (registre
    /// `AcctLocalRegistry`) — d'où le `saveAccount` sans effet.
    private var resetSessionBackend: AcctSecResetSessionBackend {
        AcctSecResetSessionBackend(
            saveServerSession: { serverSession, _ in try session.installSession(serverSession) },
            saveAccount: { _ in },
            clearServerSession: { await session.signOut() },
            clearPersistedAuthSession: { try? AcctAuthSession.clearPersistedAuthSession() },
            currentServerSession: { session.session },
            invalidateCheckedServerSession: { _ in false },
            revokeServerSessionToken: { token in await DuelloAPI.logout(token: token) }
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
            } else if signupOpen {
                SignupFlowView { signupOpen = false }
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
        // `App.tsx:2599`) et inscription aux notifications poussées
        // (`PushNotificationCoordinator`, `App.tsx:2636`). Vues sans rendu
        // (0 × 0) ; l'abonnement est recréé par compte (`.id`).
        .overlay {
            if session.isSignedIn {
                ZStack {
                    PremSubscriptionSyncView(
                        email: session.profile.email,
                        token: session.token
                    )
                    .id(session.profile.email)
                    PushNotifRootMount()
                }
            }
        }
    }
}
