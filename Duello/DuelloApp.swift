import SwiftUI

@main
struct DuelloApp: App {
    @StateObject private var session = SessionStore()
    /// Progression locale partagée : injectée à la racine car plusieurs écrans
    /// l'exigent en `@EnvironmentObject` (`DuelloProgressView`,
    /// `TrainingCatalogView`) — sans elle, l'app plante à leur ouverture.
    @StateObject private var progress = ProgressStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(session)
                .environmentObject(progress)
                // Retour du navigateur Google vers l'app (schéma du client
                // iOS inversé), comme le handle de lien profond Expo.
                .onOpenURL { url in
                    GoogleAuthService.shared.handle(url)
                }
        }
    }
}

/// Route racine : écran d'accueil tant qu'aucune session n'est ouverte,
/// onglets principaux ensuite. Reprend le parcours de l'app Expo
/// (WelcomeScreen puis BottomNavigation avec Mon compte / Entraînement / Défis).
struct RootView: View {
    @EnvironmentObject private var session: SessionStore

    /// Vrai tant que le parcours n'a pas été choisi : l'inscription vient
    /// d'aboutir et l'élève doit passer par la première configuration.
    private var needsOnboarding: Bool {
        session.profile.year.isEmpty || session.profile.track.isEmpty
    }

    var body: some View {
        Group {
            if session.isSignedIn {
                if needsOnboarding {
                    OnboardingView {}
                } else {
                    MainTabView()
                }
            } else {
                WelcomeView()
            }
        }
        .animation(.easeInOut(duration: 0.25), value: session.isSignedIn)
    }
}
