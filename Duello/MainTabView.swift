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
/// V1 (2026-09-26) — écart U08#3 : monte `ReportPublicProfilePublisher`
/// (racine connectée), comme `PublicProfilePublisher` dans `App.tsx:2589`.
///
/// V1 L5 (2026-09-26, U07 partB#2) : monte la relève des invitations de défi
/// (`ChalInvitationCoordinator`, monté à la racine par `App.tsx:2628-2632`) et
/// son popup (`ChalIncomingSheet`) en superposition plein écran — visible quel
/// que soit l'onglet ouvert. Une invitation acceptée ouvre l'onglet Défis et
/// lui remet la partie exacte (`incomingMatch`), comme `openAcceptedChallenge`
/// (App.tsx:1481-1487) ; l'onglet la consomme une seule fois.
///
/// `@MainActor` : la vue possède `ReportPublicProfilePublisher`, isolé au fil
/// principal, et l'initialise dans un initialiseur de propriété — même motif
/// que `AccountView` / `AcctIntDirectorySheet`.
@MainActor
struct MainTabView: View {
    @EnvironmentObject private var session: SessionStore
    @EnvironmentObject private var progress: ProgressStore
    /// Publieur du profil public, actif tant que l'écran connecté vit.
    @StateObject private var publisher = ReportPublicProfilePublisher()
    /// Routage d'un tap sur une bannière (`navigate` de la source) : un onglet
    /// posé par `PushNotifRootCoordinator` est consommé ici (V1 20#1).
    @ObservedObject private var pushRoot = PushNotifRootCoordinator.shared
    /// Relève racine des invitations de défi (toujours visible, App.tsx:2628).
    @StateObject private var challengeInvites = ChalInvitationCoordinator()
    /// L'onglet Défis est occupé par un défi (`challengeBusy`, App.tsx:665).
    @State private var challengeBusy = false
    /// Partie servie acceptée à la racine, remise à l'onglet Défis.
    @State private var incomingChallengeMatch: MatchView?
    /// Indice de l'onglet Défis dans le pager (`AccountView`/Entraînement/Défis).
    private static let challengesTabIndex = 2

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
                ChallengesView(
                    invites: challengeInvites,
                    incomingMatch: incomingChallengeMatch,
                    onIncomingMatchHandled: { incomingChallengeMatch = nil },
                    onBusyChange: { busy in challengeBusy = busy }
                )
                    .tag(Self.challengesTabIndex)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            DuelloBottomBar(selection: $selection, avatarInitial: profileInitial)
        }
        .overlay(invitationOverlay)
        .onAppear {
            publisher.activate(session: session)
            startChallengeInvitations()
        }
        .onDisappear { publisher.deactivate() }
        .onChange(of: challengeBusy) { _ in startChallengeInvitations() }
        .onChange(of: pushRoot.pendingTab) { tab in
            guard let tab else { return }
            selection = tab == .challenges ? Self.challengesTabIndex : 0
            pushRoot.pendingTab = nil
        }
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
            startedExerciseIds: ChalProgress.startedExerciseIds(progress: progress.items, attemptIds: []),
            onAccepted: { found in
                incomingChallengeMatch = found
                selection = Self.challengesTabIndex
            }
        )
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
