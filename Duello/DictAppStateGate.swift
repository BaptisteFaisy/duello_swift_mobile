//
//  DictAppStateGate.swift
//  Duello
//
//  Portage de `src/hooks/useDictationAppState.ts` : une fenêtre système peut
//  masquer l'application avant que le micro soit autorisé, et aucun flux audio
//  ne démarre derrière elle. Ce portail attend le retour au premier plan.
//
//  La source observe `AppState` de React Native ; ici, l'observation passe par
//  les notifications système (`UIApplicationDidBecomeActiveNotification`),
//  nommées par chaîne pour rester compilable hors UIKit. L'appelant fournit
//  `estActif` et reçoit les observateurs à conserver.
//
//  Cible : iOS 16. Aucune dépendance externe.
//

import Foundation

/// Boîte mutable partagée entre la demande et son réveil — évite de capturer
/// une variable locale mutée depuis une continuation.
private final class DictAppStateGateBox {
    var reveil: (() -> Void)?
}

/// Portail premier plan/arrière-plan de la dictée — `useDictationAppState`.
final class DictAppStateGate {
    /// Appelé quand l'application passe en arrière-plan sans demande en attente.
    var onCancel: (() -> Void)?

    private var enAttente: [UUID: () -> Void] = [:]
    private let estActif: () -> Bool

    init(estActif: @escaping () -> Bool) {
        self.estActif = estActif
    }

    /// Réveille toutes les demandes en attente — `resume`.
    func resume() {
        for reveil in enAttente.values { reveil() }
    }

    /// Réveille puis vide les demandes en attente — `cancelPending`.
    func cancelPending() {
        resume()
        enAttente.removeAll()
    }

    /// Demande une permission et attend le retour au premier plan si nécessaire.
    ///
    /// Aucun flux audio ne démarre derrière une fenêtre système : la demande
    /// attend, tant que la permission est accordée et que l'application n'est
    /// pas active, d'être réveillée par `resume()`. Après `cancelPending`, la
    /// demande n'est plus en attente et l'attente se termine.
    func requestPermission(_ request: () async -> Bool) async -> Bool {
        let cle = UUID()
        let boite = DictAppStateGateBox()
        enAttente[cle] = { boite.reveil?() }
        defer { enAttente.removeValue(forKey: cle) }

        let accordee = await request()
        while accordee && enAttente[cle] != nil && !estActif() {
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                boite.reveil = { continuation.resume() }
            }
        }
        return accordee
    }

    /// Observe les notifications d'activité et rend les observateurs à conserver.
    func demarrerObservation() -> [NSObjectProtocol] {
        let centre = NotificationCenter.default
        let actif = centre.addObserver(
            forName: Notification.Name("UIApplicationDidBecomeActiveNotification"),
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.resume()
        }
        let inactif = centre.addObserver(
            forName: Notification.Name("UIApplicationWillResignActiveNotification"),
            object: nil, queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            if self.enAttente.isEmpty { self.onCancel?() }
        }
        return [actif, inactif]
    }
}
