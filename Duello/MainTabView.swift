import SwiftUI

/// Barre d'onglets principale : Mon compte / Entraînement / Défis,
/// dans l'ordre de `BottomNavigation.tsx`.
struct MainTabView: View {
    /// Onglet initial : `ScreenshotTour` le fige pour la capture d'écran
    /// (`profile`/`training`/`challenges`) ; hors mode capture, 0 comme avant.
    @State private var selection: Int = ScreenshotTour.tabSelection ?? 0

    var body: some View {
        TabView(selection: $selection) {
            AccountView()
                .tag(0)
                .tabItem {
                    Label("Mon compte", systemImage: "person")
                }
            TrainingView()
                .tag(1)
                .tabItem {
                    Label("Entraînement", systemImage: "barbell")
                }
            ChallengesView()
                .tag(2)
                .tabItem {
                    Label("Défis", systemImage: "bolt")
                }
        }
        .tint(Theme.ink)
    }
}
