import SwiftUI

@main
struct DuelloApp: App {
    @StateObject private var session = SessionStore()
    /// Délégue d'application iOS : jeton APNs, badge, tap (V1 20#1). Absent
    /// hors d'iOS (`#if canImport(UIKit)`), où il n'y a ni APNs ni délégué.
    #if canImport(UIKit)
    @UIApplicationDelegateAdaptor(DuelloAppDelegate.self) private var appDelegate
    #endif
    /// Progression locale partagée : injectée à la racine car plusieurs écrans
    /// l'exigent en `@EnvironmentObject` (`DuelloProgressView`,
    /// `TrainingCatalogView`) — sans elle, l'app plante à leur ouverture.
    @StateObject private var progress = ProgressStore()
    /// Demande de réinitialisation reçue par lien profond : présentée en plein
    /// écran par le **seul** écran « Nouveau mot de passe » (`PasswordResetView`),
    /// comme `PasswordResetScreen` côté Expo (V1 L2, U04#3).
    @State private var passwordResetRequest: AcctSecResetRequest?

    /// Schéma d'URL de la variante (dev : `duello-dev`, cf. `CFBundleURLTypes`
    /// de `Info.plist` et `DUELLO_PASSWORD_RESET_APP_SCHEME` du backend) : repli
    /// `legacy-native` du contexte de lecture.
    private static let resetScheme = "duello-dev"

    /// App Link HTTPS de développement (`passwordResetAppUrl` de
    /// `config/duello-development.json`, lu par `config/appLinking.ts`) : le
    /// lien entrant y porte ses paramètres dans le fragment
    /// (`…/reset-password/app#reset-password?email=…&token=…`, V1 L2, U08#1).
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
                // Services racine (V1 L7) : hôte du paywall des outils (19#2),
                // synchronisation d'abonnement (19#3), notifications poussées
                // et fiche ouverte par un tap (20#1). Posé **avant** les
                // `.environmentObject(…)` pour que les vues greffées reçoivent
                // la session.
                .duelloRootServices()
                .environmentObject(session)
                .environmentObject(progress)
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
                            try? session.installSession(serverSession)
                        }
                    )
                }
        }
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

    /// Vrai tant que le parcours n'a pas été choisi : l'inscription vient
    /// d'aboutir et l'élève doit passer par la première configuration.
    private var needsOnboarding: Bool {
        session.profile.year.isEmpty || session.profile.track.isEmpty
    }

    var body: some View {
        Group {
            // Mode capture : la racine peut être figée sur l'accueil signé-out
            // même quand une session factice est semée (`welcome`, `login`,
            // `register` — la feuille d'authentification s'ouvre d'elle-même).
            if ScreenshotTour.welcomeDestination != nil {
                WelcomeView(onCreateAccount: { signupOpen = true })
            } else if signupOpen {
                SignupFlowView { signupOpen = false }
            } else if session.isSignedIn {
                if needsOnboarding {
                    // « Revenir à l'accueil » (première étape) : la racine ne
                    // quitte l'onboarding que si la session est fermée —
                    // sinon `RootView` le réafficherait aussitôt.
                    OnboardingView(onCancel: { Task { @MainActor in await session.signOut() } }) {}
                } else {
                    MainTabView()
                }
            } else {
                WelcomeView(onCreateAccount: { signupOpen = true })
            }
        }
        .animation(.easeInOut(duration: 0.25), value: session.isSignedIn)
    }
}
