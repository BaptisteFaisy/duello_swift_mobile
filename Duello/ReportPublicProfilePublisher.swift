//
//  ReportPublicProfilePublisher.swift
//  Duello
//
//  Port de src/components/PublicProfilePublisher.tsx (RN) — coordinateur de
//  publication du profil public, plus src/utils/serverSession.ts
//  (`ensureGuestServerSession`).
//
//  Fichiers source Expo portés (libellés repris mot pour mot) :
//    - src/components/PublicProfilePublisher.tsx — `PublicProfilePublisher`,
//      l'abonnement au stockage (`subscribeToAccountStorage` +
//      `isPublicProfileStorageKey`), le regroupement des écritures rapprochées
//      (750 ms au premier envoi, 120 ms ensuite) et le recalcul à minuit local
//      (`scheduleNextDay`).
//    - src/utils/serverSession.ts — `ensureGuestServerSession` (guards
//      d'identité invitée, réutilisation de la session existante,
//      `POST /auth/guest`, enregistrement).
//
//  Le composant React ne rend rien : c'est un coordinateur monté à la racine.
//  Il devient ici un `ObservableObject` injectable, sans vue.
//
//  Coutures (« seam honnête », SPEC §5 ; voir ReportPublicProfileSeams.swift) :
//  le bus de changement de stockage, la lecture de l'instantané public complet
//  et le registre multi-comptes de sessions serveur sont fournis par protocole.
//  Les implémentations par défaut refusent clairement, jamais un stub muet.
//
//  Notes datées :
//    - 2026-09-24 — création (vague 2, unité U9).
//    - 2026-09-24 — limite assumée : la relecture des séries de l'annuaire après
//      publication (`saveSubjectElos` sur `publication.profile.details.elo`) et
//      `xpAwards` ne sont pas portées : `ReportSocialProfile` ne décode pas
//      `details.elo`. `ReportPublicProfile.payload` publie donc l'identité et la
//      performance, pas les séries (cf. ReportAPI.swift:47-57).
//
//  Découpage (24/09/2026) : ce fichier porte le coordinateur et sa
//  programmation. La session invitée vit dans
//  `ReportPublicProfilePublisher+GuestSession.swift` ; les utilitaires statiques
//  dans `ReportPublicProfilePublisher+Helpers.swift`.
//
//  Cible : iOS 16, aucune API iOS 17.
//
import Foundation
import Combine

// MARK: - Coordinateur

/// `PublicProfilePublisher` : maintient le profil distant complet sans dépendre
/// de l'onglet affiché.
@MainActor
final class ReportPublicProfilePublisher: ObservableObject {

    /// Regroupement du premier envoi (750 ms) puis des écritures rapprochées
    /// (120 ms), repris de la source.
    static let firstDelayNanoseconds: UInt64 = 750_000_000
    static let changeDelayNanoseconds: UInt64 = 120_000_000

    /// Dernier résultat de publication, pour l'observation par les vues.
    @Published private(set) var lastPublication: ReportDirectoryPublication?
    /// Un envoi est en cours (lecture de l'instantané puis `PUT /profiles`).
    @Published private(set) var publishing = false

    private let storage: ReportPublicProfileStorageBus
    private let snapshots: ReportPublicProfileSnapshotProviding
    private let guestSessions: ReportGuestSessionEnsuring
    private let publisher: ReportPublicProfilePublishing
    private let tokenProvider: () -> String?

    private var accountId = ""
    private var profile = UserProfile()
    private var registeredAt: Double = 0
    private var subscription: ReportSubscription?
    private var midnightTask: Task<Void, Never>?
    private var publishTask: Task<Void, Never>?
    private var revision = 0
    private var generation = 0
    private var onPublication: ((ReportDirectoryPublication) -> Void)?
    private var onAuthenticationRequired: (() -> Void)?

    /// Dépendances injectées ; les valeurs par défaut sont les implémentations
    /// honnêtes de `ReportPublicProfileSeams.swift`. `tokenProvider` fournit le
    /// jeton de session serveur (par défaut aucune session).
    init(
        storage: ReportPublicProfileStorageBus = ReportNotificationStorageBus(),
        snapshots: ReportPublicProfileSnapshotProviding = ReportUnwiredSnapshotProvider(),
        guestSessions: ReportGuestSessionEnsuring = ReportUnwiredGuestSessions(),
        publisher: ReportPublicProfilePublishing = ReportLiveProfilePublisher(),
        tokenProvider: @escaping () -> String? = { nil }
    ) {
        self.storage = storage
        self.snapshots = snapshots
        self.guestSessions = guestSessions
        self.publisher = publisher
        self.tokenProvider = tokenProvider
    }

    /// Monte le coordinateur : abonnement au stockage du compte et recalcul au
    /// début de chaque journée locale. Remplace tout montage précédent.
    func start(
        accountId: String,
        profile: UserProfile,
        registeredAt: Double,
        onPublication: ((ReportDirectoryPublication) -> Void)? = nil,
        onAuthenticationRequired: (() -> Void)? = nil
    ) {
        stop()
        self.accountId = accountId
        self.profile = profile
        self.registeredAt = registeredAt
        self.onPublication = onPublication
        self.onAuthenticationRequired = onAuthenticationRequired
        revision = 0
        subscription = storage.subscribe(accountId: accountId) { [weak self] keys in
            guard keys.contains(where: ReportPublicProfileStorage.isPublicProfileStorageKey) else {
                return
            }
            Task { @MainActor [weak self] in self?.bumpRevision() }
        }
        scheduleNextDay()
        schedulePublish()
    }

    /// Démonte le coordinateur (compte changé, écran quitté). Les envois en vol
    /// sont invalidés par la génération.
    func stop() {
        generation += 1
        subscription?.cancel()
        subscription = nil
        midnightTask?.cancel()
        midnightTask = nil
        publishTask?.cancel()
        publishTask = nil
    }

    /// Déclenchement manuel, pour une couche de stockage qui n'est pas branchée
    /// sur `ReportNotificationStorageBus` (voir wiring/U9.md). Même filtre que
    /// l'abonnement : seules les clés du profil public reprogramment l'envoi.
    func noteProfileWrite(_ logicalKeys: [String]) {
        guard logicalKeys.contains(where: ReportPublicProfileStorage.isPublicProfileStorageKey) else {
            return
        }
        bumpRevision()
    }
}

// MARK: - Interne

extension ReportPublicProfilePublisher {

    /// Une écriture visible sur le profil public a eu lieu : reprogramme l'envoi.
    fileprivate func bumpRevision() {
        revision += 1
        schedulePublish()
    }

    /// Regroupe les écritures rapprochées : le minuteur est relancé à chaque
    /// changement, seul le dernier instantané part.
    private func schedulePublish() {
        publishTask?.cancel()
        let delay = revision == 0 ? Self.firstDelayNanoseconds : Self.changeDelayNanoseconds
        let gen = generation
        let rev = revision
        publishTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: delay)
            guard !Task.isCancelled, let self else { return }
            await self.publish(revision: rev, generation: gen)
        }
    }

    /// Recalcule l'instantané puis le publie. `generation` et `revision`
    /// abandonnent un instantané devenu obsolète avant son envoi, comme le
    /// drapeau `cancelled` de la source.
    private func publish(revision rev: Int, generation gen: Int) async {
        guard gen == generation else { return }
        // Un compte de démonstration reste local : rien ne part vers l'annuaire.
        guard !RewStorageScope.isLocalOnlyDemoAccountId(accountId) else { return }
        publishing = true
        defer { publishing = false }
        do {
            if RewStorageScope.isGuestEmail(profile.email) {
                _ = try await guestSessions.ensure(accountId: accountId, email: profile.email)
            }
            let snapshot = try await snapshots.load(
                accountId: accountId,
                profile: profile,
                registeredAt: registeredAt
            )
            guard gen == generation, rev == revision else { return }
            let payload = ReportPublicProfile.payload(
                profile: profile,
                performance: snapshot.performance,
                premium: snapshot.premium
            )
            let result = await publisher.publish(payload, token: tokenProvider())
            guard gen == generation, rev == revision else { return }
            apply(result)
        } catch {
            guard gen == generation, rev == revision else { return }
            apply(.unreachable(message: Self.message(for: error)))
        }
    }

    /// Applique le résultat, comme le `.then`/`.catch` de la source : signal
    /// d'authentification requise, puis rappel de publication.
    private func apply(_ publication: ReportDirectoryPublication) {
        lastPublication = publication
        if case .rejected(_, let authenticationRequired) = publication, authenticationRequired {
            onAuthenticationRequired?()
        }
        onPublication?(publication)
    }

    /// Recalcule au début de chaque journée locale (`scheduleNextDay`) : une
    /// série et les colonnes jour/semaine/mois peuvent changer à minuit même
    /// sans nouvelle activité.
    private func scheduleNextDay() {
        midnightTask?.cancel()
        let gen = generation
        midnightTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                let delay = Self.nanosecondsUntilNextLocalMidnight()
                try? await Task.sleep(nanoseconds: delay)
                guard !Task.isCancelled, gen == self.generation else { return }
                self.bumpRevision()
            }
        }
    }
}
