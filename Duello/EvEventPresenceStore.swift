//
//  EvEventPresenceStore.swift
//  Duello
//
//  Présence live d'un événement — état observé et cycle de vie.
//
//  Port de src/hooks/useEventPresence.ts (état `EventPresenceState` : présents,
//  vues cumulées, partages cumulés) ; la socket vit dans
//  `EvEventPresenceClient.swift`.
//
//  Limite assumée (24/09/2026) : comme la source, une socket **dédiée** est
//  ouverte en plus de la socket de présence globale (`SocPresenceStore`) ; le
//  serveur observe la page avec `watch-event`. Les compteurs `views`/`shares`
//  valent `nil` avant le premier instantané, exactement comme la source.
//
//  Cible : iOS 16.
//
import Foundation
import Combine

/// Suit les présents et les compteurs d'un événement en direct
/// (`useEventPresence.ts`).
///
/// Le cycle de vie de la socket (connect / receiveLoop / handleDisconnect) vit
/// dans `EvEventPresenceClient.swift` ; ce fichier ne porte que l'état publié.
final class EvEventPresenceStore: ObservableObject {
    /// Comptes actuellement sur la page, soi compris.
    @Published private(set) var viewers: [EvEventPresenceViewer] = []
    /// Vues cumulées ; `nil` avant le premier instantané.
    @Published private(set) var views: Int?
    /// Partages cumulés ; `nil` avant le premier instantané.
    @Published private(set) var shares: Int?

    /// Délai avant une nouvelle tentative après une coupure involontaire
    /// (`RECONNECT_DELAY_MS`).
    static let reconnectDelayNanoseconds: UInt64 = 5_000_000_000

    /// État partagé avec `EvEventPresenceClient.swift`.
    var eventId = ""
    var token: String?
    var disposed = false
    var appActive = true
    var socket: URLSessionWebSocketTask?
    var receiveTask: Task<Void, Never>?
    var reconnectTask: Task<Void, Never>?

    deinit {
        receiveTask?.cancel()
        reconnectTask?.cancel()
        socket?.cancel(with: .goingAway, reason: nil)
    }

    /// Démarre le suivi : réinitialise l'état, charge l'instantané au repos,
    /// puis ouvre la socket (corps de `useEffect` de `useEventPresence`).
    func start(eventId: String, token: String?) {
        stop()
        disposed = false
        appActive = true
        self.eventId = eventId
        self.token = token
        viewers = []
        views = nil
        shares = nil
        loadSnapshot(eventId: eventId, token: token)
        connect()
    }

    /// Arrête le suivi et ferme la socket (nettoyage de l'effet).
    func stop() {
        disposed = true
        receiveTask?.cancel()
        receiveTask = nil
        reconnectTask?.cancel()
        reconnectTask = nil
        closeSocket()
    }

    /// Bascule premier plan / arrière-plan : la socket se ferme en arrière-plan
    /// et se rouvre au retour (écoute `AppState` de la source).
    func setActive(_ active: Bool) {
        appActive = active
        if active { connect() } else { closeSocket() }
    }

    /// Applique un instantané reçu par la socket (`event-presence`).
    @MainActor
    func apply(_ event: EvEventPresenceEvent) {
        guard !disposed, event.eventId == eventId else { return }
        viewers = event.viewers
        views = event.views
        shares = event.shares
    }

    /// Instantané au repos, sans attendre la socket (`fetchEventPresence`).
    private func loadSnapshot(eventId: String, token: String?) {
        Task { [weak self] in
            guard let snapshot = try? await EvEventPresenceAPI.snapshot(eventId: eventId, token: token) else {
                return
            }
            await self?.applySnapshot(snapshot)
        }
    }

    /// Applique l'instantané au repos, si le suivi est toujours en cours.
    @MainActor
    private func applySnapshot(_ snapshot: EvEventPresenceSnapshot) {
        guard !disposed else { return }
        viewers = snapshot.viewers
        views = snapshot.views
        shares = snapshot.shares
    }
}
