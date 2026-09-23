import SwiftUI

/// Barre d'onglets principale : Profil / Entraînement / Défis, port de
/// `src/components/BottomNavigation.tsx`.
///
/// Le contenu reste un `TabView` en pages — le balayage latéral de
/// `BottomTabPager.native.tsx` — mais la barre est désormais **dessinée** par
/// `DuelloBottomBar` : la barre native d'iOS ne rend ni la pastille de l'onglet
/// actif, ni l'avatar du profil, ni le libellé `Profil` de la source (elle
/// affichait « Mon compte » avec une icône personne).
struct MainTabView: View {
    @EnvironmentObject private var session: SessionStore

    /// Onglet initial : `ScreenshotTour` le fige pour la capture d'écran
    /// (`profile`/`training`/`challenges`) ; hors mode capture, 0 comme avant.
    @State private var selection: Int = ScreenshotTour.tabSelection ?? 0

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $selection) {
                AccountView()
                    .tag(0)
                TrainingView()
                    .tag(1)
                ChallengesView()
                    .tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            DuelloBottomBar(selection: $selection, avatarInitial: profileInitial)
        }
    }

    /// `getProfileInitial` de `BottomNavigation.tsx` : première lettre du prénom,
    /// à défaut celle du nom affiché, à défaut « P ».
    private var profileInitial: String {
        let firstName = session.profile.firstName.trimmingCharacters(in: .whitespaces)
        let displayName = session.profile.displayName.trimmingCharacters(in: .whitespaces)
        let source = firstName.isEmpty ? displayName : firstName
        guard let first = source.first else { return "P" }
        return String(first).uppercased()
    }
}
