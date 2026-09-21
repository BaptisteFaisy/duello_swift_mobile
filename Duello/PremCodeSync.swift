//
//  PremCodeSync.swift
//  Duello
//
//  Recopie l’essai ou l’abonnement dès que le serveur l’accorde.
//
//  Fichier source Expo porté : `src/components/SubscriptionPaymentSync.tsx`.
//  Au montage puis toutes les cinq minutes tant que l’application est au
//  premier plan, le composant interroge `GET /subscription`, réconcilie l’état
//  stocké et prévient la célébration quand une période vient d’être payée.
//
//  ⚠️ L’application n’ouvre jamais un accès de sa propre autorité : elle ne
//  fait que recopier ce que le serveur a enregistré. Un serveur injoignable
//  laisse donc le compte exactement où il était.
//
//  Cible : iOS 16.
//
import Foundation
import Combine

/// Orchestrateur de la synchronisation d’abonnement, par compte.
final class PremCodeSync: ObservableObject {
    /// `SUBSCRIPTION_POLL_MS` : cinq minutes.
    static let pollInterval: TimeInterval = 5 * 60

    /// Abonnement local, seule source de vérité affichée.
    @Published private(set) var subscription: PremCodeSubscription.State
    /// Jours d’accès restants, recalculés à chaque réconciliation.
    @Published private(set) var daysRemaining: Int?

    let accountId: String
    let email: String
    let token: String?

    private var timer: Timer?
    private var syncing = false

    init(email: String, token: String?) {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        self.email = trimmed
        self.token = token
        self.accountId = trimmed.isEmpty ? "local" : DuelloAPI.publicProfileId(email: trimmed)
        let stored = Self.load(accountId: self.accountId)
        self.subscription = stored
        self.daysRemaining = PremCodeSubscription.remainingDays(stored, now: Self.nowMilliseconds())
    }

    deinit { timer?.invalidate() }

    /// Démarre la synchronisation : une passe immédiate, puis le rythme.
    func start() {
        PremCodePurchaser.setCurrentAccountEmail(email)
        Task { await sync() }
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: Self.pollInterval, repeats: true) {
            [weak self] _ in
            guard let self = self else { return }
            Task { await self.sync() }
        }
    }

    /// Arrête le rythme ; l’état lu reste en place.
    func stop() {
        timer?.invalidate()
        timer = nil
    }

    /// Une passe : lecture, réseau, réconciliation, événement de déblocage.
    func sync() async {
        guard !syncing, !email.isEmpty else { return }
        syncing = true
        defer { syncing = false }
        let now = Self.nowMilliseconds()
        let before = Self.load(accountId: accountId)
        do {
            let remote = try await PremCodeAPI.fetchRemoteSubscription(email: email, token: token)
            // L’état local est relu après le réseau : une résiliation faite
            // pendant la requête ne doit pas être écrasée par une réponse
            // déjà partie.
            let current = Self.load(accountId: accountId)
            let after = PremCodeSubscription.reconcile(current, remote: remote, now: now)
            if after != current { Self.save(after, accountId: accountId) }
            let activated = PremCodeSubscription.isPremiumActivation(previous: before, next: after)
            let remaining = PremCodeSubscription.remainingDays(after, now: now)
            let id = accountId
            await MainActor.run {
                self.subscription = after
                self.daysRemaining = remaining
                // La célébration relit elle-même l’état stocké, seule source de
                // vérité affichée : l’événement ne transporte rien.
                if activated { PremCodeEvents.notifyUnlocked(accountId: id) }
            }
        } catch {
            // Hors connexion, l’accès reste celui de la dernière lecture
            // connue ; la semaine payée sera reprise au prochain passage.
        }
    }

    /// `Date.now()` de la source, en millisecondes.
    private static func nowMilliseconds() -> Double {
        Date().timeIntervalSince1970 * 1000
    }

    /// Clé de persistance locale, suffixée par l’identifiant public du compte.
    private static func storageKey(_ accountId: String) -> String {
        "com.duello.ios.premcode.subscription.\(accountId)"
    }

    /// `ACCOUNT_STORAGE_KEYS.subscription` : lecture de l’état stocké.
    private static func load(accountId: String) -> PremCodeSubscription.State {
        guard let raw = UserDefaults.standard.string(forKey: storageKey(accountId)) else {
            return .empty
        }
        return PremCodeSubscription.parse(raw)
    }

    /// Écriture de l’état réconcilié, jamais un état inventé.
    private static func save(_ state: PremCodeSubscription.State, accountId: String) {
        UserDefaults.standard.set(
            PremCodeSubscription.serialize(state),
            forKey: storageKey(accountId))
    }
}
