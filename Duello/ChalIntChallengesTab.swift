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
//  (`SocialChallengeInviteModal`, présenté par `.sheet`), comme
//  `onOpenExercise` / `onOpenCourse` de la source
//  (`ChallengesScreen.tsx:2858-2878`) ; l'envoi passe par `inviteMembers`,
//  équivalent de `inviteMember` (tsx:1808-1859) : contrôle du quota puis
//  `queue.invite(...)` avec les cibles choisies.
//
//  R7 (2026-09-27, U07 partB#2) : la relève des invitations reçues est
//  remontée à la racine (montée par `MainTabView`, popup visible quel que soit
//  l'onglet, comme `App.tsx:2628-2632`) ; cet écran reçoit le coordinateur en
//  `@ObservedObject` et n'en garde que le câblage d'acceptation (`onAccepted`
//  → partie servie). La partie acceptée ailleurs est remise par `MainTabView`
//  (`incomingMatch`, consommée une seule fois), comme
//  `openAcceptedChallenge` (`App.tsx:1481-1487`) + `incomingMatch`
//  (`ChallengesScreen.tsx:1038-1047`). L'écran signale son occupation à la
//  racine (`onBusyChange`), qui l'interdit alors à toute nouvelle invitation.
//
//  V2 (2026-09-29, écart 10#1) : la feuille de classement Elo reçoit un
//  `onOpenProfile` qui ouvre la fiche publique du joueur (`ChallengesScreen.tsx`
//  l. 3023-3025), au lieu de laisser les lignes inertes.
//
//  V3 (2026-09-29, écart 07#3/D6) : `startedExerciseIds` alimente `attemptIds`
//  depuis `ChalProgress.attemptIds` (brouillons d'essai persistés) ; le
//  `onContinueTraining` des bilans est transmis depuis la racine.
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
    /// Relève racine des invitations, montée par `MainTabView`.
    @ObservedObject var invites: ChalInvitationCoordinator
    /// Partie acceptée depuis un autre onglet, remise par `MainTabView`.
    var incomingMatch: MatchView? = nil
    /// Remise consommée : invalide la copie parente (`onIncomingMatchHandled`).
    var onIncomingMatchHandled: (() -> Void)? = nil
    /// Signale à la racine que l'écran est occupé (`onBusyChange`).
    var onBusyChange: ((Bool) -> Void)? = nil
    /// Retour par balayage vers l'onglet Entraînement (`onBackToTraining` de la
    /// source, `OrderedTabPager.yieldBackSwipeToTabPager`) : à fournir par la
    /// racine (`MainTabView`), qui seule pilote le pager d'onglets.
    var onBackToTraining: (() -> Void)? = nil
    /// Reprise de l'exercice dans l'onglet Entraînement après un défi
    /// (`onContinueTraining`, `ChallengesScreen.tsx:2426-2437,2703`) : fourni
    /// par la racine, qui seule pilote le pager d'onglets. Absent ⇒ les boutons
    /// « Reprendre / Continuer l'exercice » restent masqués.
    var onContinueTraining: ((ChalRunTrainingTarget) -> Void)? = nil

    @StateObject private var queue = ChalQueueController()
    /// Événements déjà vus du compte : allume la pastille « nouveau » de l'onglet
    /// Événements et de chaque carte ajoutée depuis la dernière consultation.
    /// Amorcé à vide (`@StateObject` ne lit pas `@EnvironmentObject` à l'init),
    /// puis réaligné par `syncSeenEvents`.
    @StateObject private var seenEvents = EvSeenEventsModel(email: "", active: false, visibleIds: [])

    @State private var section: ChalHome2Section = .challenges
    @State private var duelMatch: MatchView?
    @State private var launchError: String?
    @State private var leaderboardOpen = false
    /// Nature du défi préparé par le volet d'invitation d'un ami, `nil` quand
    /// il est fermé (`inviteChallengeKind` + `inviteModalOpen`, tsx:636/649).
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
        .sheet(isPresented: $leaderboardOpen) {
            // `onOpenProfile` (`ChallengesScreen.tsx:3023-3025`) : le tap d'une
            // ligne de classement ouvre la fiche publique du membre via le
            // coordinateur racine — même couture que le tap de notification.
            LeaderboardModalView(eloOnly: true, onOpenProfile: { memberId in
                Task { @MainActor in
                    PushNotifRootCoordinator.shared.pendingMember =
                        PushNotifPendingMember(id: memberId)
                }
            })
        }
        .sheet(isPresented: inviteOpen) { inviteSheet }
        .onAppear {
            syncSeenEvents(active: true)
            onBusyChange?(isBusy)
            consumeIncomingMatch()
        }
        .onChange(of: section) { _ in syncSeenEvents(active: true) }
        .onChange(of: session.profile) { _ in syncSeenEvents(active: true) }
        .onDisappear { syncSeenEvents(active: false) }
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
            ChalIntDuelFlow(
                match: duelMatch,
                onFinish: { finishDuel() },
                onContinueTraining: onContinueTraining
            )
        } else {
            ChalHome2HomeSurface(
                elo: eloText,
                section: $section,
                hasUnseenEvents: seenEvents.hasUnseenEvents,
                onOpenLeaderboard: { leaderboardOpen = true },
                onBack: onBackToTraining,
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
            disabled: !canInvite || queue.status != .idle,
            onOpenExercise: { inviteKind = .exercise },
            onOpenCourse: { inviteKind = .course },
            onEnter: { Task { await enterQueue() } }
        )
    }

    private var eventsPage: some View {
        ScrollView {
            EventsView(
                onOpenEvent: { seenEvents.markEventSeen($0.id) },
                seenEventIds: seenEvents.seenIds
            )
            // `eventsContent` : 20 / 2 / 48, sans centrage vertical dans la page.
            .padding(.horizontal, 20)
            .padding(.top, 2)
            .padding(.bottom, 48)
        }
    }

    // MARK: Volet d'invitation d'un ami

    /// Ouverture du volet, dérivée du type de défi préparé
    /// (`inviteModalOpen`, tsx:2952).
    private var inviteOpen: Binding<Bool> {
        Binding(
            get: { inviteKind != nil },
            set: { open in if !open { inviteKind = nil } }
        )
    }

    /// Contenu du volet d'invitation d'un ami, mêmes props que la source
    /// (`ChallengeInviteModal`, tsx:2952-2980).
    @ViewBuilder private var inviteSheet: some View {
        if let kind = inviteKind {
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
                challengeKind: kind,
                onInvite: { members, keys in await inviteMembers(members, keys: keys) },
                // Comme la source (`onInviteNewUser`, tsx:2974), le carré noir
                // ouvre le menu des canaux de partage dans le volet : l'appelant
                // fournit un relais inerte, le volet n'ouvrant aucun 2e écran.
                onInviteNewUser: {},
                onClose: { inviteKind = nil }
            )
        }
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
            return SocChallengeChapters.course(
                track: args.track,
                specialty: args.specialty,
                year: args.year
            )
        }
        return SocChallengeChapters.eligible(
            track: args.track,
            specialty: args.specialty,
            year: args.year
        )
    }

    /// Vrai quand un défi peut être lancé : filière servie et banque non vide
    /// (`canLaunchChallenge`, tsx:616-620 — sans les chargements, synchrones ici).
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
                elo: subjectElo
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
    ///
    /// Les boutons Défi-Exercice / Défi-Cours, eux, ouvrent le volet
    /// d'invitation d'un ami (`inviteKind`, cf. `inviteSheet`) : `enterQueue`
    /// ne sert plus qu'au panneau de file (`ChalHome2QueuePanel`).
    private func enterQueue() async {
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
        // Quota vérifié **avant** d'ouvrir un défi, comme le volet d'invitation
        // (`correctionQuotaAllows`).
        let userId = DuelloAPI.publicProfileId(email: session.profile.email)
        do {
            let allowed = try await ChalAPI.correctionQuotaAllows(userId: userId, token: token)
            guard allowed else {
                launchError = "Ton quota de défis est épuisé. Ouvre l’onglet Défis pour voir la prochaine recharge ou l’offre Premium."
                return
            }
        } catch {
            launchError = error.localizedDescription
            return
        }
        queue.token = token
        queue.enter(ChalHome2Launch.request(
            profile: session.profile,
            chapters: pools.keys.sorted(),
            pools: pools,
            startedExerciseIds: startedExerciseIds,
            elo: subjectElo
        ))
    }

    /// Referme le défi et rend la file au repos.
    private func finishDuel() {
        queue.release()
        duelMatch = nil
    }

    // MARK: Dérivations

    /// Réaligne les événements vus sur la section et le compte courants : les
    /// identifiants visibles suivent le même filtre que la liste affichée
    /// (`visibleEventIds` de `ChallengesScreen.tsx`). `active` à faux conserve
    /// l'état sans recharger.
    private func syncSeenEvents(active: Bool) {
        let ids = EvEventAudienceFilter
            .visibleEvents(EvEventCatalog.upcoming, profile: session.profile)
            .map(\.id)
        seenEvents.update(
            accountId: DuelloAPI.publicProfileId(email: session.profile.email),
            active: active,
            visibleIds: ids
        )
    }

    private var isBusy: Bool { duelMatch != nil || queue.status != .idle }
    private var canLaunch: Bool { ChalHome2Launch.canLaunch(profile: session.profile) }
    /// Cote globale affichée en tête (`overallElo`, moyenne des matières).
    private var overallElo: Int { AcctIntData.overallElo(progress) }
    /// Cote de la matière du défi, annoncée au serveur
    /// (`getSubjectElo(subjectElos, subject)`, `ChallengesScreen.tsx:1847`).
    private var subjectElo: Int {
        EvEventRewards.getSubjectElo(
            progress.subjectElos,
            subject: ChalHome2Launch.challengeSubjectName
        )
    }
    private var eloText: String { ChalRunFormat.elo(overallElo) }
    /// Ligue et blason sur la filière **normalisée** (`eloLeagueTrack` =
    /// `currentTrackForProfile`), jamais la filière brute.
    private var league: EloLeague { eloLeague(for: overallElo, track: session.profile.followedTrack) }
    private var leagueLabel: String { league.label }
    private var badgeURL: URL? { LeagueBadges.badgeURL(forLeague: league.id) }

    private var startedExerciseIds: [String] {
        ChalProgress.startedExerciseIds(
            progress: progress.items,
            attemptIds: ChalProgress.attemptIds(
                accountId: DuelloAPI.publicProfileId(email: session.profile.email)
            )
        )
    }

    private var playableNotice: ChalHome2PlayableNotice {
        let pools = DuelloExerciseCatalog.queuePools(for: session.profile)
        guard !pools.isEmpty else { return .noPlayableExercises }
        let started = Set(startedExerciseIds)
        let remaining = pools.values.contains { ids in
            ids.contains { !started.contains($0) }
        }
        return remaining ? .none : .allStarted
    }
}
