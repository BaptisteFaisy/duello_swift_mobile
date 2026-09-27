import SwiftUI

/// Barre d'onglets principale : Profil / Entraînement / Défis, port de
/// `src/components/BottomNavigation.tsx`.
///
/// Le contenu reste un `TabView` en pages — le balayage latéral de
/// `BottomTabPager.native.tsx` — mais la barre est désormais **dessinée** par
/// `DuelloBottomBar` : la barre native d'iOS ne rend ni la pastille de l'onglet
/// actif, ni l'avatar du profil, ni le libellé `Profil` de la source (elle
/// affichait « Mon compte » avec une icône personne).
///
/// R7 (2026-09-27) — montage racine des services que `main` portait sans les
/// câbler :
///   - **publication du profil public** (`ReportPublicProfilePublisher`, comme
///     `PublicProfilePublisher` dans `App.tsx:2589`) : le publieur vit tant que
///     l'écran connecté vit, son jeton de session est fourni au montage ;
///   - **relève des invitations de défi** (`ChalInvitationCoordinator`, monté à
///     la racine par `App.tsx:2628-2632`) et son popup (`ChalIncomingSheet`) en
///     superposition plein écran — visible quel que soit l'onglet. Une
///     invitation acceptée ouvre l'onglet Défis et lui remet la partie exacte
///     (`incomingMatch`), comme `openAcceptedChallenge` (`App.tsx:1481-1487`) ;
///     l'onglet la consomme une seule fois.
///   - **routage d'un tap de notification poussée** (`PushNotifRootCoordinator`,
///     posé par `PushNotifRootMount` à la racine).
///
/// `@MainActor` : la vue possède `ReportPublicProfilePublisher`, isolé au fil
/// principal, et l'initialise dans un initialiseur de propriété — même motif
/// que `AccountView` / `AcctIntDirectorySheet`.
@MainActor
struct MainTabView: View {
    @EnvironmentObject private var session: SessionStore
    @EnvironmentObject private var progress: ProgressStore

    /// Publieur du profil public, monté tant que l'écran connecté vit.
    @StateObject private var publisher = ReportPublicProfilePublisher()
    /// Relève racine des invitations de défi (toujours visible, `App.tsx:2628`).
    @StateObject private var challengeInvites = ChalInvitationCoordinator()
    /// L'onglet Défis est occupé par un défi (`challengeBusy`, `App.tsx:665`).
    @State private var challengeBusy = false
    /// Partie servie acceptée à la racine, remise à l'onglet Défis.
    @State private var incomingChallengeMatch: MatchView?
    /// Routage d'un tap sur une bannière (`navigate` de la source) : un onglet
    /// posé par `PushNotifRootCoordinator` est consommé ici.
    @ObservedObject private var pushRoot = PushNotifRootCoordinator.shared

    /// Indice de l'onglet Défis dans le pager (`AccountView` / Entraînement /
    /// Défis).
    private static let challengesTabIndex = 2

    /// Onglet initial : `ScreenshotTour` le fige pour la capture d'écran
    /// (`profile`/`training`/`challenges`) ; hors mode capture, 0 comme avant.
    @State private var selection: Int = ScreenshotTour.tabSelection ?? 0

    var body: some View {
        VStack(spacing: 0) {
            tabs
            DuelloBottomBar(selection: $selection, avatarInitial: profileInitial)
        }
        .overlay(invitationOverlay)
        .onAppear(perform: startRootServices)
        .onDisappear { publisher.stop() }
        .onChange(of: challengeBusy) { _ in startChallengeInvitations() }
        .onChange(of: pushRoot.pendingTab, perform: consumePendingTab)
        .onChange(of: pushRoot.pendingMember, perform: consumePendingMember)
        .task { await warmRankings() }
    }

    /// Les trois onglets, en pages (`BottomTabPager.native.tsx`).
    private var tabs: some View {
        TabView(selection: $selection) {
            AccountView()
                .tag(0)
            TrainingView()
                .tag(1)
            ChallengesView(
                invites: challengeInvites,
                incomingMatch: incomingChallengeMatch,
                onIncomingMatchHandled: { incomingChallengeMatch = nil },
                onBusyChange: { busy in challengeBusy = busy }
            )
                .tag(Self.challengesTabIndex)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
    }

    // MARK: Services racine

    /// Monte le publieur de profil et la relève des invitations (une fois).
    private func startRootServices() {
        let sessionStore = session
        publisher.setTokenProvider { sessionStore.token }
        publisher.start(
            accountId: AcctNotifications.accountId(email: session.profile.email),
            profile: session.profile,
            registeredAt: registeredAt
        )
        startChallengeInvitations()
    }

    /// Onglet posé par un tap de notification (`navigate` de la source).
    private func consumePendingTab(_ tab: PushNotifTab?) {
        guard let tab else { return }
        selection = tab == .challenges ? Self.challengesTabIndex : 0
        pushRoot.pendingTab = nil
    }

    /// Membre à ouvrir (`openMemberProfile`) : l'onglet « Mon compte » porte
    /// l'annuaire ; la fiche elle-même est ouverte par son modèle de recherche
    /// (couture documentée, cf. `PushNotifRootMount.swift`).
    private func consumePendingMember(_ member: PushNotifPendingMember?) {
        guard member != nil else { return }
        selection = 0
        pushRoot.pendingMember = nil
    }

    /// Préchauffage des classements (~1,5 s puis ~4,5 s, `App.tsx`).
    private func warmRankings() async {
        let profile = RankingWarmupProfile(
            track: session.profile.track,
            year: session.profile.year,
            specialty: session.profile.specialty
        )
        let service = DuelloAPIRankingsWarmupService(token: session.token)
        try? await Task.sleep(nanoseconds: 1_500_000_000)
        await prefetchRankingsDataForProfile(profile, service: service)
        try? await Task.sleep(nanoseconds: 4_500_000_000)
        await prefetchRankingsForProfile(profile, service: service)
    }

    // MARK: Invitations reçues (racine)

    /// Popup d'invitation reçue, monté au-dessus de tous les onglets.
    @ViewBuilder private var invitationOverlay: some View {
        if let invitation = challengeInvites.invitation {
            ChalIncomingSheet(
                invitation: invitation,
                responding: challengeInvites.responding,
                error: challengeInvites.error,
                onAccept: { challengeInvites.respond(.accepted) },
                onDecline: { challengeInvites.respond(.declined) },
                presence: SocPresenceStore.shared
            )
        }
    }

    /// (Re)démarre la relève racine ; `busy` interdit toute apparition de
    /// popup, comme la prop `busy` de la source.
    private func startChallengeInvitations() {
        challengeInvites.start(
            profile: session.profile,
            busy: challengeBusy,
            token: session.token,
            subjectElo: AcctIntData.overallElo(progress),
            startedExerciseIds: ChalProgress.startedExerciseIds(
                progress: progress.items,
                attemptIds: []
            ),
            onAccepted: { found in
                incomingChallengeMatch = found
                selection = Self.challengesTabIndex
            }
        )
    }

    /// Horodatage d'inscription du compte (`account.createdAt` de la source,
    /// `App.tsx:2591`), lu du registre local — `0` si le compte n'y figure pas.
    private var registeredAt: Double {
        AcctLocalRegistry.findAccountByEmail(
            AcctLocalRegistry.loadAccounts(),
            email: session.profile.email
        )?.createdAt ?? 0
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
