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
//  V1 L5 (2026-09-26, U07 partA#1 + partB#1) : les boutons Défi-Exercice /
//  Défi-Cours ouvrent le volet d'invitation d'un ami
//  (`SocialChallengeInviteModal`, présenté par `.fullScreenCover`), comme
//  `onOpenExercise` / `onOpenCourse` de la source
//  (`ChallengesScreen.tsx:2858-2878`) ; l'envoi passe par `inviteMembers`,
//  équivalent de `inviteMember` (tsx:1808-1859) : contrôle du quota puis
//  `queue.invite(...)` avec les cibles choisies. Le quota Swift ne porte que
//  `allowed` (U07 partD#2, P1 des lots V2) : tout refus pose le message de la
//  source sans ouvrir le paywall.
//
//  V1 L5 (2026-09-26, U07 partB#2) : la relève des invitations reçues est
//  remontée à la racine (montée par `MainTabView`, popup visible quel que soit
//  l'onglet, comme `App.tsx:2628-2632`) ; cet écran reçoit le coordinateur en
//  `@ObservedObject` et n'en garde que le câblage d'acceptation (`onAccepted`
//  → partie servie). La partie acceptée ailleurs est remise par `MainTabView`
//  (`incomingMatch`, consommée une seule fois), comme
//  `openAcceptedChallenge` (App.tsx:1481-1487) + `incomingMatch`
//  (ChallengesScreen.tsx:1038-1047).
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
    /// Relève racine des invitations, montée par `MainTabView` (V1 L5, partB#2).
    @ObservedObject var invites: ChalInvitationCoordinator
    /// Partie acceptée depuis un autre onglet, remise par `MainTabView`.
    var incomingMatch: MatchView? = nil
    /// Remise consommée : invalide la copie parente (`onIncomingMatchHandled`).
    var onIncomingMatchHandled: (() -> Void)? = nil
    /// Signale à la racine que l'écran est occupé (`onBusyChange`).
    var onBusyChange: ((Bool) -> Void)? = nil

    @StateObject private var queue = ChalQueueController()

    @State private var section: ChalHome2Section = .challenges
    @State private var duelMatch: MatchView?
    @State private var launchError: String?
    @State private var leaderboardOpen = false
    /// Volet d'invitation d'un ami ouvert (`inviteModalOpen` + kind, tsx:636).
    @State private var inviteKind: SocChallengeKind?
    /// Partie racine déjà consommée (`handledIncomingMatch`, tsx:656).
    @State private var handledIncomingMatchId: String?

    var body: some View {
        NavigationStack {
            content
                .background(Theme.background)
                // La source n'a pas d'en-tête de navigation : l'accueil porte
                // sa propre barre ELO + onglets Défis/Événements
                // (`ChallengesScreen.tsx`, `ChallengeHomeOverview`). Un titre
                // « Défis » centré serait un ajout.
        }
        .sheet(isPresented: $leaderboardOpen) { LeaderboardModalView() }
        .fullScreenCover(isPresented: inviteOpen) {
            SocialChallengeInviteModal(
                selfId: DuelloAPI.publicProfileId(email: session.profile.email),
                track: session.profile.track,
                year: session.profile.year,
                specialty: session.profile.specialty,
                subject: ChalHome2Launch.challengeSubjectName,
                durationMinutes: ChalMatchmaking.challengeDurationMinutes,
                chapters: inviteChapters,
                canInvite: canInvite,
                invitedIds: [],
                challengeKind: inviteKind ?? .exercise,
                onInvite: { members, keys in await inviteMembers(members, keys: keys) },
                // Comme la source (`onInviteNewUser`, tsx:2974), le carré noir
                // du volet ouvre le menu des canaux de partage dans le volet :
                // l'appelant fournit un relais inerte, le volet n'ouvrant
                // aucun second écran.
                onInviteNewUser: {},
                onClose: { inviteKind = nil }
            )
        }
        .onAppear {
            onBusyChange?(isBusy)
            consumeIncomingMatch()
        }
        .onChange(of: isBusy) { busy in onBusyChange?(busy) }
        .onChange(of: incomingMatch) { _ in consumeIncomingMatch() }
        .onChange(of: queue.match) { found in
            if let found { duelMatch = found }
        }
    }

    // MARK: Contenu

    @ViewBuilder private var content: some View {
        if queue.status == .searching {
            searchingScreen
        } else if let duelMatch {
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

    /// Pendant la recherche d'adversaire, la source remplace **tout** l'écran
    /// par la seule carte : ni barre ELO, ni onglets Défis / Événements.
    private var searchingScreen: some View {
        ScrollView {
            ChalHome2QueuePanel(
                queue: queue,
                subject: ChalHome2Launch.challengeSubjectName,
                durationMinutes: ChalMatchmaking.challengeDurationMinutes,
                disabled: true,
                onEnter: {}
            )
            .padding(.horizontal, 16)
            .padding(.top, 16)
        }
        .background(Theme.background)
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
            onOpenExercise: { inviteKind = .exercise },
            onOpenCourse: { inviteKind = .course },
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

    // MARK: Volet d'invitation d'un ami

    /// Ouverture du volet, dérivée du type de défi préparé.
    private var inviteOpen: Binding<Bool> {
        Binding(
            get: { inviteKind != nil },
            set: { open in if !open { inviteKind = nil } }
        )
    }

    /// Chapitres du volet : avec flashcards en Défi-Cours, programme entier
    /// en Défi-Exercice (tsx:2957-2969).
    private var inviteChapters: [SocChallengeChapter] {
        let args = (
            track: session.profile.track,
            specialty: session.profile.specialty,
            year: session.profile.year
        )
        if inviteKind == .course {
            return SocChallengeChapters.course(track: args.track, specialty: args.specialty, year: args.year)
        }
        return SocChallengeChapters.eligible(track: args.track, specialty: args.specialty, year: args.year)
    }

    /// Vrai quand un défi peut être lancé : filière servie et banque non vide
    /// (`canLaunchChallenge`, tsx:616-620 — sans les chargements, synchrones
    /// ici).
    private var canInvite: Bool {
        guard ChalHome2Launch.canLaunch(profile: session.profile) else { return false }
        return !DuelloExerciseCatalog.queuePools(for: session.profile).isEmpty
    }

    /// Envoie les invitations directes pour les amis choisis (`inviteMember`,
    /// tsx:1808-1859) : contrôle du quota, puis `queue.invite(...)`.
    private func inviteMembers(_ members: [SocSocialProfile], keys: [String]) async {
        guard canInvite, !members.isEmpty else { return }
        let userId = DuelloAPI.publicProfileId(email: session.profile.email)
        do {
            let allowed = try await ChalAPI.correctionQuotaAllows(
                userId: userId,
                token: session.token
            )
            guard allowed else {
                inviteKind = nil
                launchError = "Ton quota de défis est épuisé. Ouvre l’onglet Défis pour voir la prochaine recharge ou l’offre Premium."
                return
            }
        } catch {
            inviteKind = nil
            launchError = error.localizedDescription
            return
        }
        launchError = nil
        let pools = DuelloExerciseCatalog.queuePools(for: session.profile)
        let invitedExercisePools = Dictionary(
            uniqueKeysWithValues: keys.compactMap { key -> (String, [String])? in
                let ids = pools[key] ?? []
                return ids.isEmpty ? nil : (key, ids)
            }
        )
        queue.token = session.token
        queue.invite(
            ChalHome2Launch.request(
                profile: session.profile,
                chapters: keys,
                pools: invitedExercisePools,
                startedExerciseIds: startedExerciseIds,
                elo: eloValue
            ),
            targets: ChalHome2Launch.targets(
                members: members,
                chapters: inviteChapters,
                chapterKeys: keys
            )
        )
        inviteKind = nil
    }

    // MARK: Partie acceptée depuis un autre onglet

    /// Remet à l'écran la partie servie acceptée à la racine ; chaque
    /// identifiant n'est consommé qu'une fois (tsx:1038-1047).
    private func consumeIncomingMatch() {
        guard let incoming = incomingMatch,
              queue.status == .idle,
              duelMatch == nil,
              handledIncomingMatchId != incoming.id
        else { return }
        handledIncomingMatchId = incoming.id
        queue.adoptMatch(incoming)
        duelMatch = incoming
        onIncomingMatchHandled?()
    }

    // MARK: Actions

    /// Entre dans la file aléatoire (bouton d'entrée du panneau de file).
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
