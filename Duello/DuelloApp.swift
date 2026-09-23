import SwiftUI

@main
struct DuelloApp: App {
    @StateObject private var session = SessionStore()
    /// Progression locale partagée : injectée à la racine car plusieurs écrans
    /// l'exigent en `@EnvironmentObject` (`DuelloProgressView`,
    /// `TrainingCatalogView`) — sans elle, l'app plante à leur ouverture.
    @StateObject private var progress = ProgressStore()
    /// Demande de réinitialisation reçue par lien profond
    /// (`duello-dev://reset-password?email=…&token=…`) : présentée en plein
    /// écran, comme `PasswordResetScreen` côté Expo.
    @State private var passwordResetRequest: AcctSecResetRequest?

    /// Schéma d'URL de la variante (dev : `duello-dev`, cf. `CFBundleURLTypes`
    /// de `Info.plist` et `DUELLO_PASSWORD_RESET_APP_SCHEME` du backend).
    private static let resetScheme = "duello-dev"

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(session)
                .environmentObject(progress)
                // Retour du navigateur Google vers l'app (schéma du client
                // iOS inversé), comme le handle de lien profond Expo.
                .onOpenURL { url in
                    GoogleAuthService.shared.handle(url)
                    // Lien de réinitialisation servi par le backend
                    // (`passwordResetLink.ts`, branche `legacy-native`).
                    if let request = AcctSecResetLink.request(
                        from: url.absoluteString,
                        scheme: Self.resetScheme
                    ) {
                        passwordResetRequest = request
                    }
                }
                .fullScreenCover(item: $passwordResetRequest) { request in
                    NavigationStack {
                        AcctSecPasswordResetForm(
                            email: request.email,
                            token: request.token,
                            onAuthenticated: { serverSession in
                                try? session.installSession(serverSession)
                                passwordResetRequest = nil
                            }
                        )
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Fermer") { passwordResetRequest = nil }
                            }
                        }
                    }
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
            if signupOpen {
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
