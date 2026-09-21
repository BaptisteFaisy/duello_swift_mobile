//
//  ChalIntChallengesTab.swift
//  Duello
//
//  Lot 18 — intégration de l'onglet « Défis » : conteneur de l'écran.
//
//  Fichier source Expo porté : `src/screens/ChallengesScreen.tsx`
//  (machine à états `idle` / `searching` / `matched` / résultat, onglets
//  Défis / Événements, relève des invitations).
//
//  Assemble les composants déjà portés : surface d'accueil
//  (`ChalHome2HomeSurface` → en-tête ELO + onglets + pager), page Défis
//  (`ChalIntHomePage`), page Événements (`EventsView`), file d'attente
//  (`ChalQueueController`), popup d'invitation (`ChalIncomingSheet` via
//  `ChalInvitationCoordinator`) et déroulé d'un défi (`ChalIntDuelFlow`).
//
//  Réutilise sans les recréer : `ChalHome2Launch`, `ChalMatchmaking`,
//  `ChalProgress`, `DuelloExerciseCatalog`, `AcctIntData`, `eloLeague`,
//  `LeagueBadges`, `ChalRunFormat`, `LeaderboardModalView`.
//
//  Cible : iOS 16, aucune API iOS 17.
//
import SwiftUI

/// Onglet « Défis » assemblé : accueil (Défis / Événements), file d'attente,
/// invitations reçues et déroulé d'un défi.
///
/// `@MainActor` : la vue pilote `ChalQueueController` et
/// `ChalInvitationCoordinator`, tous deux isolés sur l'acteur principal.
@MainActor
struct ChalIntChallengesTab: View {
    @EnvironmentObject private var session: SessionStore
    @EnvironmentObject private var progress: ProgressStore

    @StateObject private var queue = ChalQueueController()
    @StateObject private var invites = ChalInvitationCoordinator()

    @State private var section: ChalHome2Section = .challenges
    @State private var duelMatch: MatchView?
    @State private var launchError: String?
    @State private var leaderboardOpen = false

    var body: some View {
        NavigationStack {
            content
                .background(Theme.background)
                .navigationTitle("Défis")
                .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $leaderboardOpen) { LeaderboardModalView() }
        .overlay(invitationOverlay)
        .onAppear { startInvitations() }
        .onChange(of: isBusy) { _ in startInvitations() }
        .onChange(of: queue.match) { found in
            if let found { duelMatch = found }
        }
    }

    // MARK: Contenu

    @ViewBuilder private var content: some View {
        if let duelMatch {
            ChalIntDuelFlow(match: duelMatch, onFinish: { finishDuel() })
        } else {
            ChalHome2HomeSurface(
                elo: eloText,
                section: $section,
                onOpenLeaderboard: { leaderboardOpen = true },
                challenges: { homePage },
                events: { eventsPage }
            )
        }
    }

    private var homePage: some View {
        ChalIntHomePage(
            queue: queue,
            badgeURL: badgeURL,
            leagueLabel: leagueLabel,
            wins: progress.challengesWon,
            losses: max(0, progress.challengesCompleted - progress.challengesWon),
            playable: playableNotice,
            launchError: launchError,
            disabled: !canLaunch || queue.status != .idle,
            onOpenExercise: { enterQueue() },
            onOpenCourse: { enterQueue() },
            onEnter: { enterQueue() }
        )
    }

    private var eventsPage: some View {
        ScrollView {
            EventsView()
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 24)
        }
    }

    // MARK: Invitations reçues

    @ViewBuilder private var invitationOverlay: some View {
        if let invitation = invites.invitation {
            ChalIncomingSheet(
                invitation: invitation,
                responding: invites.responding,
                error: invites.error,
                onAccept: { invites.respond(.accepted) },
                onDecline: { invites.respond(.declined) },
                presence: SocPresenceStore.shared
            )
        }
    }

    // MARK: Actions

    /// Entre dans la file aléatoire.
    ///
    /// La source ouvre, elle, le volet d'invitation d'un ami ; ce volet n'étant
    /// pas porté, les boutons de défi retombent sur la file aléatoire.
    private func enterQueue() {
        launchError = nil
        guard let token = session.token else {
            launchError = "Ta session a expiré, reconnecte-toi."
            return
        }
        guard ChalHome2Launch.canLaunch(profile: session.profile) else {
            launchError = "Les défis sont disponibles en ECG et MPSI pour l'instant."
            return
        }
        let pools = DuelloExerciseCatalog.queuePools(for: session.profile)
        guard !pools.isEmpty else {
            launchError = "Aucun exercice disponible pour ce parcours pour l'instant."
            return
        }
        queue.token = token
        queue.enter(ChalHome2Launch.request(
            profile: session.profile,
            chapters: pools.keys.sorted(),
            pools: pools,
            startedExerciseIds: startedExerciseIds,
            elo: eloValue
        ))
    }

    /// Referme le défi et rend la file au repos.
    private func finishDuel() {
        queue.release()
        duelMatch = nil
    }

    /// (Re)démarre la relève des invitations ; la file est « occupée » pendant
    /// un défi, ce qui interdit toute apparition de popup.
    private func startInvitations() {
        invites.start(
            profile: session.profile,
            busy: isBusy,
            token: session.token,
            subjectElo: eloValue,
            startedExerciseIds: startedExerciseIds,
            onAccepted: { found in
                queue.adoptMatch(found)
                duelMatch = found
            }
        )
    }

    // MARK: Dérivations

    private var isBusy: Bool { duelMatch != nil || queue.status != .idle }
    private var canLaunch: Bool { ChalHome2Launch.canLaunch(profile: session.profile) }
    private var eloValue: Int { AcctIntData.overallElo(progress) }
    private var eloText: String { ChalRunFormat.elo(eloValue) }
    private var league: EloLeague { eloLeague(for: eloValue, track: session.profile.track) }
    private var leagueLabel: String { league.label }
    private var badgeURL: URL? { LeagueBadges.badgeURL(forLeague: league.id) }

    private var startedExerciseIds: [String] {
        ChalProgress.startedExerciseIds(progress: progress.items, attemptIds: [])
    }

    private var playableNotice: ChalHome2PlayableNotice {
        DuelloExerciseCatalog.queuePools(for: session.profile).isEmpty ? .noPlayableExercises : .none
    }
}
