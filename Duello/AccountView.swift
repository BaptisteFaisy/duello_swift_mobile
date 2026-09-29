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
///
/// R01 (2026-09-29, raccords d'hôtes) : l'onglet déclare son chrome au
/// `RootChromeModel` (verrou de geste quand une feuille est ouverte,
/// `AccountScreen.tsx:717-719`) et **possède** le producteur de masquage de la
/// barre basse (`DuelloBottomBarChrome`, `AccountScreen.tsx:681-693`), alimenté
/// par l'offset de son défilement.
@MainActor
struct AccountView: View {
    @EnvironmentObject private var session: SessionStore
    /// Chrome racine des onglets (verrou de geste, barre basse).
    @EnvironmentObject private var root: RootChromeModel

    /// Publieur du profil public : porte l'état de publication de l'annuaire
    /// (`publication` d'`AccountScreen.tsx:246`, alimenté par
    /// `PublicProfilePublisher.onPublication` → `App.tsx:2607`). Le bandeau
    /// d'état de la recherche lit `lastPublication`.
    ///
    /// L'onglet doit recevoir le publieur de `MainTabView` (`@StateObject
    /// publisher`) : `AccountView(publisher: publisher)`. Le repli par défaut
    /// (publieur détaché, jamais démarré) laisse le bandeau masqué, soit le
    /// comportement d'avant ce câblage — jamais un plantage.
    @ObservedObject var publisher = ReportPublicProfilePublisher()

    /// Réglages ouverts. En mode capture, `ScreenshotTour` les fige d'emblée
    /// pour photographier un écran de réglages sans tap.
    @State private var settingsOpen = ScreenshotTour.opensAccountSettings
    @State private var notificationsOpen = ScreenshotTour.screen == "notifications"
    /// Annuaire de recherche de la page : la ligne de recherche vit en tête du
    /// profil, comme `searchQuery` / `directoryProfiles` de la source.
    @StateObject private var search = AcctSearchModel()

    /// Producteur de masquage de la barre basse (`useScrollChromeVisibility`) :
    /// l'offset du profil le fait basculer (`AccountScreen.tsx:681-693`).
    @StateObject private var bottomBarChrome = DuelloBottomBarChrome()

    /// Espace de coordonnées du défilement du profil, pour mesurer l'offset.
    private static let scrollSpace = "account-profile-scroll"

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    AcctIntSearchRow(
                        model: search,
                        publication: publisher.lastPublication,
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
                .padding(.horizontal, 24)
                .padding(.top, 4)
                .padding(.bottom, 36)
                .background(offsetProbe)
            }
            .coordinateSpace(name: Self.scrollSpace)
            .onPreferenceChange(DuelloBottomBarOffsetKey.self) { offset in
                bottomBarChrome.scroll(offset: Double(offset))
            }
            .background(Theme.background)
            // La source n'a pas d'en-tête de navigation : la page commence par
            // la ligne de recherche, sans titre centré.
            .sheet(isPresented: $notificationsOpen) {
                // Le tap sur une notification ouvre la fiche du membre
                // (`openMember` de `AccountScreen.tsx:2271`) puis referme la
                // feuille (`leaveNotifications`) : la fiche se pose alors sur
                // le profil de l'onglet « Mon compte ».
                //
                // Les listes Amis (écart #13) sont peuplées depuis le modèle de
                // recherche du profil — mêmes données d'annuaire que la
                // recherche (`knownProfiles` + `followerIds`/`followedIds`,
                // `AccountScreen.tsx:1680-1686`). Repli documenté : tant que le
                // lot « Social » n'alimente pas `followerIds`/`followedIds`, les
                // listes restent vides et affichent leur message d'état vide.
                AcctIntNotificationsSheet(
                    onOpenMember: { memberId in
                        search.openMember(memberId)
                        notificationsOpen = false
                    },
                    knownProfiles: search.knownProfiles,
                    followerIds: search.followerIds,
                    followedIds: search.followedIds,
                    onToggleFollow: { search.toggleFollow($0) }
                )
            }
            .sheet(isPresented: $settingsOpen) {
                AcctIntSettingsSheet(email: session.profile.email, token: session.token)
            }
        }
        .duelloBottomBarChrome(bottomBarChrome, forTab: 0)
        .onAppear { declareTabSwipeLock() }
        .onChange(of: settingsOpen) { _ in declareTabSwipeLock() }
        .onChange(of: notificationsOpen) { _ in declareTabSwipeLock() }
        .onDisappear { root.setTabSwipeLock(false, forTab: 0) }
    }

    /// Sonde d'offset du défilement du profil (fond transparent en tête de
    /// contenu) : alimente le producteur de masquage de la barre basse.
    private var offsetProbe: some View {
        GeometryReader { geometry in
            Color.clear.preference(
                key: DuelloBottomBarOffsetKey.self,
                value: -geometry.frame(in: .named(Self.scrollSpace)).minY
            )
        }
    }

    /// Déclare le verrou de geste d'onglet au chrome racine
    /// (`onTabSwipeLockChange`, `AccountScreen.tsx:717-719`) : une feuille
    /// ouverte (réglages, notifications) fige le balayage, et la barre basse
    /// revient au sommet de liste (`resetProfileChromeVisibility`).
    private func declareTabSwipeLock() {
        let locked = settingsOpen || notificationsOpen
        root.setTabSwipeLock(locked, forTab: 0)
        if locked { bottomBarChrome.reset() }
    }
}

/// Clé de préférence publiant l'offset de défilement d'un écran d'onglet, pour
/// le producteur de masquage de la barre basse (`DuelloBottomBarChrome`).
struct DuelloBottomBarOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
