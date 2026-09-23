import SwiftUI

/// Onglet « Mon compte » : ligne de recherche puis vitrine du profil.
///
/// Portage de `src/screens/AccountScreen.tsx`, page `'profile'` : le corps de
/// la page, c'est la recherche (cloche des notifications + roue des réglages)
/// et la vitrine du profil. Les réglages eux-mêmes vivent dans
/// `AcctInfoSettingsView`, ouverts par la roue — la source les rend sur la page
/// `'settings'`, pas sur le profil.
///
/// ⚠️ Ce fichier portait auparavant un « hub » de douze lignes (Progression,
/// Annales, Planning, Messages, Mon parcours, …) et deux cartes de saisie
/// (« Mon parcours », « Mon objectif »). **Rien de tout cela n'existe dans la
/// source** : `AccountScreen.tsx` ne contient ni ces libellés ni ces écrans, et
/// `EnhancedProgressScreen` / `EnhancedPlanScreen` / `MessagesScreen` /
/// `AccountTrackScreen` n'y sont importés par aucun fichier. Retirés pour que
/// le profil cesse de montrer des écrans que le RN n'a pas.
///
/// `@MainActor` : la vue possède `AcctSearchModel`, isolé au fil principal, et
/// l'initialise dans un initialiseur de propriété (non isolé par défaut) —
/// même motif que `AcctIntDirectorySheet`.
@MainActor
struct AccountView: View {
    @EnvironmentObject private var session: SessionStore

    /// Réglages ouverts. En mode capture, `ScreenshotTour` les fige d'emblée
    /// pour photographier un écran de réglages sans tap.
    @State private var settingsOpen = ScreenshotTour.opensAccountSettings
    @State private var notificationsOpen = ScreenshotTour.screen == "notifications"
    /// Annuaire de recherche de la page : la ligne de recherche vit en tête du
    /// profil, comme `searchQuery` / `directoryProfiles` de la source.
    @StateObject private var search = AcctSearchModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    AcctIntSearchRow(
                        model: search,
                        onOpenNotifications: { notificationsOpen = true },
                        onOpenSettings: { settingsOpen = true }
                    )
                    // Une fiche de membre ouverte remplace le profil affiché,
                    // comme `resolveViewedProfile(profile, selectedMember)` de
                    // la source : le bloc de recherche reste, le corps change.
                    if search.selectedMemberId == nil {
                        AcctIntShowcase()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .background(Theme.background)
            // La source n'a pas d'en-tête de navigation : la page commence par
            // la ligne de recherche, sans titre centré.
            .sheet(isPresented: $notificationsOpen) {
                AcctIntNotificationsSheet()
            }
            .sheet(isPresented: $settingsOpen) {
                AcctIntSettingsSheet(email: session.profile.email, token: session.token)
            }
        }
    }
}
