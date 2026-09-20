import SwiftUI

/// Barre d'onglets principale : Mon compte / Entraînement / Défis,
/// dans l'ordre de `BottomNavigation.tsx`.
struct MainTabView: View {
    var body: some View {
        TabView {
            AccountView()
                .tabItem {
                    Label("Mon compte", systemImage: "person")
                }
            TrainingView()
                .tabItem {
                    Label("Entraînement", systemImage: "barbell")
                }
            ChallengesView()
                .tabItem {
                    Label("Défis", systemImage: "bolt")
                }
        }
        .tint(Theme.ink)
    }
}
