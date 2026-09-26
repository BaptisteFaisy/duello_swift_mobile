//
//  ReportPublicProfilePublisher.swift
//  Duello
//
//  V1 (2026-09-26) — écart U08#3 : publication continue du profil public.
//
//  Fichier source Expo porté :
//    - src/components/PublicProfilePublisher.tsx (monté App.tsx:2589-2595) :
//      maintient le profil distant sans dépendre de l'onglet affiché.
//
//  Le publieur republie l'identité du profil à chaque changement de profil
//  (comme l'effet principal de `PublicProfilePublisher`), en regroupant les
//  écritures rapprochées (750 ms à la première, 120 ms ensuite) et en
//  recalculant l'instantané au début de chaque journée locale. En mode capture
//  (`ScreenshotTour`), aucune publication n'est déclenchée.
//
//  Limite assumée (continuation P1 #26, non corrigée ici) : le publieur
//  ne dispose que du corps d'identité déjà porté (`ReportPublicProfile.payload`,
//  `details: nil`) ; les déclencheurs de statistiques (clés de stockage
//  grades/elo/xp, sous-jacent `publicProfileSnapshot.ts:133-355`) et le
//  bootstrap de session serveur invité (`ensureGuestServerSession`) relèvent de
//  l'instantané complet. Tant qu'aucun instantané complet n'est publié, la
//  publication emploie donc le repli `ReportPublicPerformance.fallback`, comme
//  le publieur de racine de la source (`EMPTY_PERFORMANCE`).
//
//  Cible : iOS 16, aucune API iOS 17.
//
import Combine
import Foundation

/// Publieur du profil public (`PublicProfilePublisher`) : ne dépend pas de
/// l'onglet affiché et republie l'identité du profil de façon continue.
@MainActor
final class ReportPublicProfilePublisher: ObservableObject {
    /// Dernière publication connue, exposée à l'appelant.
    @Published private(set) var publication: ReportDirectoryPublication?
    /// Appelée quand le serveur exige une réauthentification (401). La source
    /// la câble à `requireServerAuthentication` (`App.tsx:1675`) ; l'UI de
    /// réauthentification n'étant pas encore portée, l'hôte du publieur la
    /// laisse `nil` tant qu'elle n'existe pas (seam honnête).
    var onAuthenticationRequired: (() -> Void)?

    private var profile = UserProfile()
    /// Session observée, gardée faible : elle fournit le jeton de publication.
    private weak var session: SessionStore?
    /// `revision` de la source : 0 à la première exécution, incrémenté au
    /// début de chaque journée locale.
    private var revision = 0
    private var lastPublishedBody: Data?
    private var publishTask: Task<Void, Never>?
    private var dayTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    /// Délais de regroupement (`revision === 0 ? 750 : 120` de la source).
    private static let firstDelayNanos: UInt64 = 750_000_000
    private static let nextDelayNanos: UInt64 = 120_000_000

    /// Observe le profil et programme la republication quotidienne.
    func activate(session: SessionStore) {
        guard dayTask == nil else { return }
        self.session = session
        profile = session.profile
        session.accountStore.$profile
            .removeDuplicates()
            .sink { [weak self] in self?.profileChanged($0) }
            .store(in: &cancellables)
        scheduleNextDay()
        schedulePublish()
    }

    /// Arrête l'écoute et les minuteries (l'hôte le rappelle à la démontée).
    func deactivate() {
        publishTask?.cancel()
        dayTask?.cancel()
        publishTask = nil
        dayTask = nil
        cancellables.removeAll()
    }

    /// Un changement de profil relance la publication (la source distingue
    /// l'effet par ses dépendances, sans toucher à `revision`).
    func profileChanged(_ profile: UserProfile) {
        self.profile = profile
        schedulePublish()
    }

    // MARK: Rythme

    private func bumpRevision() {
        revision += 1
        schedulePublish()
    }

    /// `scheduleNextDay` de la source : une série ou les colonnes
    /// jour/semaine/mois peuvent changer à minuit même sans nouvelle activité ;
    /// le prochain instantané est recalculé au début de chaque journée locale.
    private func scheduleNextDay() {
        dayTask?.cancel()
        dayTask = Task { [weak self] in
            let calendar = Calendar.current
            while !Task.isCancelled {
                let now = Date()
                let startOfDay = calendar.startOfDay(for: now)
                // `nextDay.setHours(24, 0, 1, 0)` : lendemain, 1 s après minuit.
                guard let midnight = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { return }
                let seconds = max(1, midnight.addingTimeInterval(1).timeIntervalSince(now))
                try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                guard !Task.isCancelled else { return }
                self?.bumpRevision()
            }
        }
    }

    /// Minuterie de regroupement (`revision === 0 ? 750 : 120`).
    private func schedulePublish() {
        guard !ScreenshotTour.isActive else { return }
        publishTask?.cancel()
        let delay = revision == 0 ? Self.firstDelayNanos : Self.nextDelayNanos
        publishTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: delay)
            guard !Task.isCancelled else { return }
            await self?.publish()
        }
    }

    // MARK: Publication

    /// `publishSocialProfile` de la source : ne publie que l'identité visible
    /// dans l'annuaire, jamais l'e-mail ni le mot de passe ; ne republie pas
    /// un corps inchangé (`lastPublished`).
    private func publish() async {
        guard let token = token(for: profile) else { return }
        // `performance ?? lastPerformance.get(profileId) ?? EMPTY_PERFORMANCE`
        // et `premium ?? lastPremium.get(profileId) ?? false` de la source :
        // tant que l'instantané complet (#26) n'est pas porté, le publieur de
        // racine publie le repli, exactement comme la racine d'Expo.
        let payload = ReportPublicProfile.payload(
            profile: profile,
            performance: .fallback,
            premium: false
        )
        guard !payload.displayName.isEmpty else {
            publication = .incomplete
            return
        }
        guard let body = try? DuelloAPI.encodeBody(payload) else {
            publication = .unreachable(message: "Publication impossible")
            return
        }
        guard body != lastPublishedBody else {
            publication = .published(at: Date(), profile: nil)
            return
        }

        let result = await ReportPublicProfile.publish(payload, token: token)
        if case .published = result { lastPublishedBody = body }
        if case let .rejected(_, authenticationRequired) = result, authenticationRequired {
            onAuthenticationRequired?()
        }
        publication = result
    }

    /// Jeton de publication, ou `nil` si le profil ne doit pas être publié :
    /// comptes purement locaux (`isLocalOnlyDemoEmail`) et adresses invitées
    /// (`isGuestEmail`, dont le bootstrap de session serveur n'est pas porté).
    private func token(for profile: UserProfile) -> String? {
        guard !RewStorageScope.isLocalOnlyDemoEmail(profile.email) else { return nil }
        guard !RewStorageScope.isGuestEmail(profile.email) else { return nil }
        return session?.token
    }
}
