import Foundation

// File d'attente sérialisée et boucle de reprise des synchronisations push.
//
// Sources Expo portées : `src/utils/pushNotificationOperationQueue.ts` (file
// par compte, suspension/reprise) et `src/utils/pushNotificationRetryLoop.ts`
// (boucle sérialisée et annulable, délai doublant plafonné).
//
// Pur et portable : aucun appel système, seulement des `Task` et de l'attente.
// Tout est `@MainActor` : l'état partagé reste sur le fil principal, comme les
// promesses chaînées d'Expo s'exécutaient sur une seule boucle.

// MARK: - File sérialisée

/// File sérialisée par compte, avec suspension
/// (`pushNotificationOperationQueue.ts`).
@MainActor
final class PushNotifOperationQueue {

    private var suspendedAccounts: Set<String> = []
    private var tails: [String: Task<Void, Never>] = [:]

    /// Suspend la file d'un compte (par exemple pendant une déconnexion).
    func suspend(_ accountId: String) {
        suspendedAccounts.insert(accountId)
    }

    /// Relance la file d'un compte.
    func resume(_ accountId: String) {
        suspendedAccounts.remove(accountId)
    }

    /// Sérialise une opération derrière les précédentes du même compte.
    /// Renvoie `nil` si la file est suspendue et que l'opération n'est pas
    /// autorisée à forcer (`allowWhileSuspended`).
    func enqueue<T>(
        _ accountId: String,
        allowWhileSuspended: Bool = false,
        _ operation: @escaping @MainActor () async throws -> T
    ) async throws -> T? {
        let previous = tails[accountId]
        let work = Task { () -> T? in
            _ = await previous?.value
            if suspendedAccounts.contains(accountId) && !allowWhileSuspended {
                return nil
            }
            return try await operation()
        }
        tails[accountId] = Task { _ = try? await work.value }
        return try await work.value
    }
}

// MARK: - Boucle de reprise

/// Boucle de reprise annulable (`pushNotificationRetryLoop.ts`).
@MainActor
final class PushNotifRetryLoop {

    private static let initialDelayNanos: UInt64 = 2_000_000_000
    private static let maximumDelayNanos: UInt64 = 60_000_000_000

    private let reconcile: () async -> Bool
    private var active = true
    private var running = false
    private var rerunRequested = false
    private var retryDelayNanos = PushNotifRetryLoop.initialDelayNanos
    private var retryTask: Task<Void, Never>?

    init(reconcile: @escaping () async -> Bool) {
        self.reconcile = reconcile
    }

    /// Demande une réconciliation ; enchaîne si une autre est déjà demandée.
    func request() {
        guard active else { return }
        rerunRequested = true
        if !running { Task { await self.run() } }
    }

    /// Arrête la boucle et annule toute reprise programmée.
    func stop() {
        active = false
        rerunRequested = false
        retryTask?.cancel()
        retryTask = nil
    }

    /// Exécute la boucle jusqu'à épuisement des demandes.
    private func run() async {
        running = true
        while active && rerunRequested {
            rerunRequested = false
            if await reconcile() {
                scheduleRetry()
            } else {
                resetRetry()
            }
        }
        running = false
        if active && rerunRequested { Task { await self.run() } }
    }

    /// Programme une reprise en doublant le délai, plafonné.
    private func scheduleRetry() {
        guard active, retryTask == nil else { return }
        let delay = retryDelayNanos
        retryDelayNanos = min(retryDelayNanos * 2, Self.maximumDelayNanos)
        retryTask = Task { [weak self] in
            _ = try? await Task.sleep(nanoseconds: delay)
            guard let self else { return }
            self.retryTask = nil
            self.request()
        }
    }

    /// Réarme le délai initial après une réconciliation réussie.
    private func resetRetry() {
        retryTask?.cancel()
        retryTask = nil
        retryDelayNanos = Self.initialDelayNanos
    }
}
