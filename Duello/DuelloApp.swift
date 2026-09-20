import SwiftUI

@main
struct DuelloApp: App {
    @StateObject private var session = SessionStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(session)
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

    var body: some View {
        Group {
            if session.isSignedIn {
                MainTabView()
            } else {
                WelcomeView()
            }
        }
        .animation(.easeInOut(duration: 0.25), value: session.isSignedIn)
    }
}
