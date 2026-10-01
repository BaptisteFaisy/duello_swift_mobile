import SwiftUI

/// Barre d'onglets principale : Profil / Entraînement / Défis, port de
/// `src/components/BottomNavigation.tsx` et de
/// `src/components/BottomTabPager.native.tsx`.
///
/// Le contenu est un **ruban maison** (`DuelloBottomTabPager`) — le balayage
/// latéral de la source, avec sa résistance de bord `0.16`, son ressort
/// `SPRING_CONFIG` et sa progression continue — et la barre est **dessinée**
/// par `DuelloBottomBar` : la barre native d'iOS ne rend ni la pastille de
/// l'onglet actif, ni l'avatar du profil, ni le libellé `Profil` de la source
/// (elle affichait « Mon compte » avec une icône personne).
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
///   - **moniteur de correction d'annale** (`AnnCorrectionMonitor`, monté à la
///     racine par `App.tsx:2650`) : il survit à la sortie de l'onglet et publie
///     les corrections prêtes dans le magasin de notifications (écart 06#9).
///   - **publieur de profil partagé** : l'onglet « Mon compte » reçoit le
///     `publisher` racine (`AccountView(publisher:)`, écart IMPL-16) pour lire
///     l'état de publication de l'annuaire.
///
/// `@MainActor` : la vue possède `ReportPublicProfilePublisher`, isolé au fil
/// principal, et l'initialise dans un initialiseur de propriété — même motif
/// que `AccountView` / `AcctIntDirectorySheet`.
///
/// R01 (2026-09-29, raccords d'hôtes) : la racine alimente `attemptIds` des
/// défis (`ChalProgress.attemptIds`, écart 07#3/D6) et relaie la reprise d'un
/// exercice de défi vers l'onglet Entraînement (`onContinueTraining`).
///
/// S01 (2026-09-30, producteurs de chrome) : la racine relève **à nouveau** les
/// invitations de défi au retour au premier plan (`AppState` de
/// `ChallengeInvitationCoordinator.tsx:104-107`, écart 07#11) au lieu d'attendre
/// le prochain tour de sonde (10 s).
@MainActor
struct MainTabView: View {
    @EnvironmentObject private var session: SessionStore
    @EnvironmentObject private var progress: ProgressStore
    /// Phase de scène (`scenePhase`) : porte l'équivalent Swift de l'écouteur
    /// `AppState` de `ChallengeInvitationCoordinator.tsx:104-107` (07#11).
    @Environment(\.scenePhase) private var scenePhase

    /// Publieur du profil public, monté tant que l'écran connecté vit.
    @StateObject private var publisher = ReportPublicProfilePublisher()
    /// Moniteur de correction d'annale monté **à la racine** (`App.tsx:2650`,
    /// `<AnnaleCorrectionMonitor />`) : il sonde les corrections actives (15 s)
    /// même une fois l'onglet Entraînement quitté, et publie les fiches prêtes
    /// dans le magasin de notifications partagé (`AnnCorrectionMonitor.upsert`,
    /// écart 06#9). S01 — la racine et le lecteur d'annale
    /// (`TrainingCatalogView+Entry`) lisent la **même** sonde de fond
    /// (`AnnCorrectionMonitor.shared`) au lieu d'en créer une par vue : une
    /// seule boucle pour toute l'app.
    @ObservedObject private var correctionMonitor = AnnCorrectionMonitor.shared
    /// Relève racine des invitations de défi (toujours visible, `App.tsx:2628`).
    @StateObject private var challengeInvites = ChalInvitationCoordinator()
    /// L'onglet Défis est occupé par un défi (`challengeBusy`, `App.tsx:665`).
    @State private var challengeBusy = false
    /// Partie servie acceptée à la racine, remise à l'onglet Défis.
    @State private var incomingChallengeMatch: MatchView?
    /// Reprise d'un exercice de défi remise à l'onglet Entraînement
    /// (`trainingContinuation`, `App.tsx:683,1505`). L'application dans le
    /// catalogue (ouverture du lecteur) est à raccorder (vague 6).
    @State private var trainingContinuation: ChalRunTrainingTarget?
    /// Routage d'un tap sur une bannière (`navigate` de la source) : un onglet
    /// posé par `PushNotifRootCoordinator` est consommé ici.
    @ObservedObject private var pushRoot = PushNotifRootCoordinator.shared

    /// Indice de l'onglet Défis dans le pager (`AccountView` / Entraînement /
    /// Défis).
    private static let challengesTabIndex = 2

    /// Indice de l'onglet Entraînement : seul onglet dont le clavier de maths
    /// réserve le geste horizontal (`mathKeyboardClaimsSwipe`, `App.tsx:1572`).
    static let trainingTabIndex = 1

    /// Nombre de non-lues, source de la pastille de la barre
    /// (`NotificationBadgeSync` → `unreadNotificationCount > 0`, `App.tsx:2602`).
    @ObservedObject private var notifications = AcctNotificationsStore.shared

    /// Progression continue du ruban, lue par la barre pour interpoler l'onglet
    /// actif (`navigationPage`, `App.tsx:689`).
    @StateObject private var tabPager = DuelloTabPagerModel(
        progress: CGFloat(ScreenshotTour.tabSelection ?? 1)
    )

    /// Onglet initial : `ScreenshotTour` le fige pour la capture d'écran
    /// (`profile`/`training`/`challenges`) ; hors mode capture, `training`
    /// (`DEFAULT_SCREEN`, `App.tsx:374`).
    @State private var selection: Int = ScreenshotTour.tabSelection ?? 1

    /// Chrome racine des onglets : verrou de geste (`tabSwipeLocked`,
    /// `App.tsx:1655`) et masquage de la barre basse (`bottomNavigationHidden`,
    /// `App.tsx:647`). Chaque écran déclare son état par `@EnvironmentObject`
    /// (`setTabSwipeLock`, `setBottomNavigationHidden`) ; la racine en déduit ce
    /// qu'elle applique (`tabPagerScrollEnabled`, `bottomNavigationAvailable`,
    /// `App.tsx:1654-1659,1579`).
    @StateObject private var chrome = RootChromeModel()

    /// Inset bas de la fenêtre, pour `max(insets.bottom, 5)` (`:69`).
    @State private var bottomSafeAreaInset: CGFloat = 0

    var body: some View {
        VStack(spacing: 0) {
            tabs
            DuelloAnimatedBottomBar(visible: !chrome.bottomBarHidden(activeTab: selection)) {
                DuelloBottomBar(
                    selection: $selection,
                    pager: tabPager,
                    avatarInitial: profileInitial,
                    photoUri: session.profile.photoUri,
                    hasUnreadNotifications: notifications.unreadCount > 0,
                    bottomSafeAreaInset: bottomSafeAreaInset
                )
            }
        }
        .ignoresSafeArea(.container, edges: .bottom)
        .environmentObject(chrome)
        .environment(\.rootChromeModel, chrome)
        .overlay(invitationOverlay)
        .onAppear(perform: startRootServices)
        .onDisappear {
            publisher.stop()
            correctionMonitor.stop()
        }
        .onChange(of: challengeBusy) { _ in startChallengeInvitations() }
        .onChange(of: scenePhase) { phase in
            // 07#11 — `AppState.addEventListener('change', …)` de
            // `ChallengeInvitationCoordinator.tsx:104-107` : au retour au premier
            // plan, la relève est rejouée tout de suite (le popup d'invitation
            // apparaît sans attendre le prochain tour de sonde de 10 s). Le
            // `Task` de sonde reste vivant : iOS le suspend en arrière-plan et le
            // reprend au retour, la relève périodique n'est donc pas à relancer.
            guard phase == .active else { return }
            Task { await challengeInvites.refresh() }
        }
        .onChange(of: pushRoot.pendingTab, perform: consumePendingTab)
        .onChange(of: pushRoot.pendingMember, perform: consumePendingMember)
        .task { await warmRankings() }
    }

    /// Les trois onglets, en pages (`BottomTabPager.native.tsx`) : ruban maison
    /// (résistance de bord, ressort de relâchement, verrou de geste) au lieu du
    /// `TabView(.page)` natif, qui ne rend pas la progression continue.
    private var tabs: some View {
        DuelloBottomTabPager(
            model: tabPager,
            page: $selection,
            initialPage: selection,
            scrollEnabled: chrome.tabPagerScrollEnabled(activeTab: selection),
            onPageSelected: { selection = $0 },
            page0: {
                AccountView(
                    publisher: publisher,
                    onOpenTraining: { target in
                        trainingContinuation = target
                        selection = Self.trainingTabIndex
                    }
                )
            },
            page1: { TrainingView(continuation: trainingContinuation) },
            page2: {
                ChallengesView(
                    invites: challengeInvites,
                    incomingMatch: incomingChallengeMatch,
                    onIncomingMatchHandled: { incomingChallengeMatch = nil },
                    onBusyChange: { busy in challengeBusy = busy },
                    onBackToTraining: { selection = Self.trainingTabIndex },
                    tabIndex: Self.challengesTabIndex,
                    onContinueTraining: { target in
                        trainingContinuation = target
                        selection = Self.trainingTabIndex
                    }
                )
            }
        )
    }

    // MARK: Services racine

    /// Monte le publieur de profil et la relève des invitations (une fois).
    private func startRootServices() {
        bottomSafeAreaInset = DuelloWindowInsets.bottomSafeArea
        let sessionStore = session
        publisher.setTokenProvider { sessionStore.token }
        publisher.start(
            accountId: AcctNotifications.accountId(email: session.profile.email),
            profile: session.profile,
            registeredAt: registeredAt
        )
        startChallengeInvitations()
        correctionMonitor.configure(token: session.token)
        correctionMonitor.load()
        correctionMonitor.start()
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
        // `App.tsx:1216-1221` : la cohorte Elo suit la filière **suivie**
        // (`academicPath.currentTrack`) et l'option courante prime sur la
        // spécialité historique (`academicPath.currentOption || specialty`).
        let option = session.profile.academicPath?.currentOption ?? ""
        let profile = RankingWarmupProfile(
            track: session.profile.track,
            year: session.profile.year,
            specialty: option.isEmpty ? session.profile.specialty : option,
            currentTrack: session.profile.academicPath?.currentTrack
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
            // Cote **par matière** du défi, résolue à la construction de la cible
            // (`getSubjectElo(subjectElos, subject)`, `subjectElo.ts:198`), au
            // lieu de la moyenne globale (`AcctIntData.overallElo`).
            subjectEloFor: { progress.subjectElo(for: $0) },
            startedExerciseIds: ChalProgress.startedExerciseIds(
                progress: progress.items,
                attemptIds: ChalProgress.attemptIds(
                    accountId: DuelloAPI.publicProfileId(email: session.profile.email)
                )
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

/// Chrome racine des onglets : verrou de geste et masquage de la barre basse.
///
/// Port de `tabSwipeLocks` / `mathKeyboardOpen` / `bottomNavigationHiddenByScreen`
/// de `App.tsx` (`:675-756,1572`) : chaque écran déclare son verrou de geste et
/// sa visibilité de barre (`onTabSwipeLockChange`,
/// `onBottomNavigationVisibilityChange`, `onMathKeyboardVisibilityChange`) ; la
/// racine en déduit ce qu'elle applique (`tabPagerScrollEnabled`,
/// `bottomNavigationAvailable`, `App.tsx:1654-1659,1579`).
@MainActor
final class RootChromeModel: ObservableObject {
    /// Verrou de geste demandé par un écran (`tabSwipeLocks`, `App.tsx:675`).
    @Published private var tabSwipeLocks: [Int: Bool] = [:]
    /// Un clavier de maths visible réserve le geste horizontal
    /// (`mathKeyboardClaimsSwipe`, `App.tsx:1572`).
    @Published var mathKeyboardOpen = false
    /// Barre basse masquée par onglet (`bottomNavigationHiddenByScreen`, `:707`).
    @Published private var bottomNavigationHiddenByScreen: [Int: Bool] = [:]

    /// `setScreenTabSwipeLock` : un écran (dé)verrouille le geste d'onglet.
    func setTabSwipeLock(_ locked: Bool, forTab tab: Int) {
        if tabSwipeLocks[tab] == locked { return }
        tabSwipeLocks[tab] = locked
    }

    /// `setBottomNavigationHiddenForScreen` : le défilement d'un écran masque ou
    /// révèle la barre basse.
    func setBottomNavigationHidden(_ hidden: Bool, forTab tab: Int) {
        if bottomNavigationHiddenByScreen[tab] == hidden { return }
        bottomNavigationHiddenByScreen[tab] = hidden
    }

    /// `onMathKeyboardVisibilityChange` (`App.tsx:1572,2831,2885`) : un clavier
    /// maths visible réserve le geste horizontal de l'onglet Entraînement. Le
    /// producteur est le clavier lui-même (`MathKeyboardView`, via
    /// `rootChromeModel`), faute de pouvoir câbler chaque hôte.
    func setMathKeyboardOpen(_ open: Bool) {
        if mathKeyboardOpen == open { return }
        mathKeyboardOpen = open
    }

    /// `tabPagerScrollEnabled` : le ruban balaye si l'onglet affiché n'a pas
    /// verrouillé le geste et qu'aucun clavier de maths ne le réserve.
    func tabPagerScrollEnabled(activeTab tab: Int) -> Bool {
        let locked = tabSwipeLocks[tab] ?? false
        let keyboard = tab == MainTabView.trainingTabIndex && mathKeyboardOpen
        return !locked && !keyboard
    }

    /// `bottomNavigationAvailable` : la barre est masquée si l'onglet affiché
    /// l'a demandé au défilement.
    func bottomBarHidden(activeTab tab: Int) -> Bool {
        bottomNavigationHiddenByScreen[tab] ?? false
    }
}

// MARK: - Accès optionnel au chrome racine

/// Accès **optionnel** au chrome racine depuis un sous-écran profond.
///
/// Le clavier maths (`MathKeyboardView`) vit dans des vues qui n'ont pas
/// toujours `RootChromeModel` dans leur environnement (lecteur d'annale,
/// outils de défi, revue de flashcards). Contrairement à
/// `@EnvironmentObject` — qui lève si l'objet est absent — cette clé renvoie
/// `nil` hors de la hiérarchie de la racine, si bien que le clavier peut
/// déclarer son ouverture sans risque (`MathKeyboardView`).
struct RootChromeModelKey: EnvironmentKey {
    static let defaultValue: RootChromeModel? = nil
}

extension EnvironmentValues {
    /// Chrome racine des onglets, `nil` hors de `MainTabView`.
    var rootChromeModel: RootChromeModel? {
        get { self[RootChromeModelKey.self] }
        set { self[RootChromeModelKey.self] = newValue }
    }
}
