import Foundation
import Combine

// Synchronisation du badge global des notifications.
//
// Source Expo portée : `src/components/NotificationBadgeSync.tsx` — sondage
// serveur toutes les 30 s au premier plan, relecture locale immédiate, arrêt du
// sondage en arrière-plan, rafraîchissement sur push reçu.
//
// Portable (Foundation/Combine). Le magasin local de notifications
// (`utils/notifications.ts`) et l'appel social (`socialApi.ts`) sont **hors de
// ce lot** : ils sont injectés sous forme de fermetures, exactement comme le
// composant Expo les reçoit de ses hooks. La logique de fusion et le comptage
// des non-lues restent donc à la charge de l'appelant.

// MARK: - Fournisseurs

/// Fournisseurs injectés pour la synchronisation du badge.
struct PushNotifBadgeProviders {
    /// Recalcule le nombre de non-lues à partir du stockage local.
    var loadUnreadCount: () async -> Int
    /// Relit le serveur, fusionne et renvoie le nombre de non-lues.
    var synchronize: () async -> Int
}

// MARK: - Contrôleur

/// Contrôleur du badge global (`NotificationBadgeSync.tsx`).
@MainActor
final class PushNotifBadgeController: ObservableObject {

    /// Intervalle de sondage du serveur, comme `NOTIFICATION_POLL_MS` (30 s).
    static let pollIntervalNanos: UInt64 = 30_000_000_000

    /// Nombre de notifications non lues, pour le badge global.
    @Published private(set) var unreadCount = 0
    /// Vrai quand l'application est au premier plan.
    @Published private(set) var isActive = true

    private let providers: PushNotifBadgeProviders
    private var pollTask: Task<Void, Never>?
    private var syncing = false

    init(providers: PushNotifBadgeProviders) {
        self.providers = providers
    }

    /// Relit le stockage local (léger), sans toucher au réseau.
    func refreshLocal() async {
        unreadCount = await providers.loadUnreadCount()
    }

    /// Bascule premier plan / arrière-plan : relance ou coupe le sondage.
    func setActive(_ active: Bool) {
        isActive = active
        if active {
            Task { await syncRemote() }
            startPolling()
        } else {
            stopPolling()
        }
    }

    /// Démarre : lecture locale immédiate puis sondage serveur.
    func start() {
        Task { await refreshLocal() }
        startPolling()
    }

    /// Arrête le sondage (par exemple à la déconnexion).
    func stop() {
        stopPolling()
    }

    // MARK: Interne

    /// Lance la boucle de sondage, une seule à la fois.
    private func startPolling() {
        guard pollTask == nil, isActive else { return }
        pollTask = Task { [weak self] in
            while let self = self, self.isActive {
                _ = try? await Task.sleep(nanoseconds: Self.pollIntervalNanos)
                if !self.isActive { break }
                await self.syncRemote()
            }
        }
    }

    /// Coupe la boucle de sondage.
    private func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
    }

    /// Relit le serveur sans chevauchement ; en cas d'échec, le badge local
    /// reste exact (le serveur sera relu au prochain passage).
    private func syncRemote() async {
        guard !syncing, isActive else { return }
        syncing = true
        defer { syncing = false }
        unreadCount = await providers.synchronize()
    }
}
