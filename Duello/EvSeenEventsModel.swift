//
//  EvSeenEventsModel.swift
//  Duello
//
//  Identifiants des événements déjà vus par le compte, exposés comme un objet
//  observable. La pastille « nouveau » s'allume sur l'onglet Événements et sur
//  chaque carte d'événement ajouté depuis, jusqu'à l'ouverture de l'événement.
//
//  Port de src/hooks/useSeenEvents.ts (RN) : `useSeenEvents(active, storage,
//  visibleIds)` devient cet `ObservableObject` (mêmes entrées `active` et
//  `visibleIds`, même état `seenIds` — `nil` avant le premier chargement — et
//  même opération `markEventSeen`). La persistance passe par `EvEventSeen`.
//
//  Couture honnête (seam) — ce qui n'est pas porté :
//    - Expo abonne un magasin partagé (`subscribeToAccountStorage`) qui notifie
//      les clés logiques modifiées, y compris par un autre écran. iOS n'a pas de
//      magasin multi-écritures : la couture retenue est
//      `UserDefaults.didChangeNotification`, qui ne transporte pas la clé
//      modifiée. On relit donc à chaque changement de `UserDefaults` (coût
//      négligeable), au lieu de filtrer sur `seenEvents` comme la source. Les
//      écritures hors processus (extension, autre app) ne sont pas notifiées.
//    - Le rechargement d'Expo est asynchrone et annulable ; `UserDefaults` étant
//      synchrone, `reload()` est immédiat et ne peut pas être « annulé en vol ».
//      La bascule de compte reste explicite (`update(accountId:)` remet
//      `seenIds` à `nil`, comme la source).
//
//  Cible : iOS 16.
//
import Foundation
import Combine

/// État des événements vus, réutilisable par tout écran qui affiche l'onglet
/// Événements (accueil Défis) ou la liste des concours blancs.
final class EvSeenEventsModel: ObservableObject {
    /// Identifiants vus ; `nil` tant que le premier chargement n'a pas eu lieu.
    @Published private(set) var seenIds: [String]?

    private var accountId: String
    private var active: Bool
    private var visibleIds: [String]
    private var observer: NSObjectProtocol?

    init(accountId: String, active: Bool, visibleIds: [String]) {
        self.accountId = accountId
        self.active = active
        self.visibleIds = visibleIds
        refreshSubscription()
    }

    /// Construit le modèle à partir de l'e-mail de session, comme le magasin de
    /// compte d'Expo porte lui-même l'identifiant public du compte.
    convenience init(email: String, active: Bool, visibleIds: [String]) {
        self.init(
            accountId: DuelloAPI.publicProfileId(email: email),
            active: active,
            visibleIds: visibleIds
        )
    }

    deinit { unsubscribe() }

    /// Reprend les dépendances du hook RN (`active`, compte, identifiants
    /// visibles). Un changement de compte repart de zéro, comme la source.
    func update(accountId: String, active: Bool, visibleIds: [String]) {
        let accountChanged = accountId != self.accountId
        self.accountId = accountId
        self.active = active
        self.visibleIds = visibleIds
        if accountChanged { seenIds = nil }
        refreshSubscription()
    }

    /// Pastille « nouveau » : au moins un événement visible jamais vu. Fausse
    /// tant que `seenIds` n'a pas été chargé, comme `seenIds !== null` côté RN.
    var hasUnseenEvents: Bool {
        guard let seenIds else { return false }
        return visibleIds.contains { !seenIds.contains($0) }
    }

    /// Identifiants visibles jamais vus, dans l'ordre du catalogue.
    func unseenVisibleIds() -> [String] {
        EvEventSeen.unseenEventIds(visibleIds: visibleIds, seenIds: seenIds ?? [])
    }

    /// Ajoute un événement aux vus et persiste la liste, sans doublon
    /// (`markEventSeen`). Sans effet si l'identifiant est déjà vu.
    func markEventSeen(_ eventId: String) {
        let base = seenIds ?? []
        if base.contains(eventId) { return }
        seenIds = EvEventSeen.storeSeenEventId(
            accountId: accountId,
            seenIds: base,
            eventId: eventId
        )
    }

    // MARK: - Chargement

    /// Charge puis s'abonne si actif, se désabonne sinon. L'état courant de
    /// `seenIds` est conservé quand la section n'est plus active, comme la
    /// source garde son `useState`.
    private func refreshSubscription() {
        guard active else {
            unsubscribe()
            return
        }
        reload()
        subscribe()
    }

    private func reload() {
        seenIds = EvEventSeen.loadSeenEventIds(accountId: accountId, visibleIds: visibleIds)
    }

    private func subscribe() {
        guard observer == nil else { return }
        observer = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.reload()
        }
    }

    private func unsubscribe() {
        if let observer { NotificationCenter.default.removeObserver(observer) }
        observer = nil
    }
}
