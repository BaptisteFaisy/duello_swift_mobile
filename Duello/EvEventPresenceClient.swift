//
//  EvEventPresenceClient.swift
//  Duello
//
//  Présence live d'un événement — socket dédiée (suite de
//  `EvEventPresenceStore.swift`).
//
//  Port de src/hooks/useEventPresence.ts (ouverture, authentification,
//  `watch-event`, reconnexion après coupure involontaire) ; la lecture des
//  messages vient de `EvEventPresenceProtocol`.
//
//  La socket est portée par `URLSessionWebSocketTask` (iOS 13+), l'équivalent
//  natif de `WebSocket` côté Expo : rien n'est simulé. Elle est **distincte** de
//  la socket de présence globale (`SocPresenceStore`), comme la source, qui
//  ouvre sa propre socket par page d'événement.
//
//  Cible : iOS 16.
//
import Foundation

extension EvEventPresenceStore {
    /// Ouvre la socket dédiée de l'événement et s'authentifie.
    ///
    /// Sans jeton — ou hors premier plan, ou déjà ouverte — rien ne s'ouvre :
    /// comme `useEventPresence`, qui attend une session serveur, une nouvelle
    /// tentative est programmée tant que la session manque.
    ///
    /// Volontairement non isolée : les appelants sont les rappels SwiftUI
    /// (apparition, retour au premier plan), exécutés sur le fil principal.
    func connect() {
        guard !disposed, appActive, socket == nil else { return }
        guard let token else {
            scheduleReconnect()
            return
        }
        guard let url = SocPresenceProtocol.socketURL(for: DuelloAPI.baseURL) else { return }

        let task = URLSession.shared.webSocketTask(with: url)
        socket = task
        task.resume()
        send(["type": "authenticate", "token": token], on: task)
        receiveTask = Task { [weak self] in
            await self?.receiveLoop(task)
        }
    }

    /// Ferme la socket (départ de l'arrière-plan, fin du suivi).
    func closeSocket() {
        reconnectTask?.cancel()
        reconnectTask = nil
        guard let task = socket else { return }
        socket = nil
        task.cancel(with: .goingAway, reason: nil)
    }

    /// Programme une nouvelle tentative après une coupure involontaire
    /// (`RECONNECT_DELAY_MS`).
    func scheduleReconnect() {
        guard !disposed, appActive, reconnectTask == nil else { return }
        reconnectTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: Self.reconnectDelayNanoseconds)
            guard !Task.isCancelled else { return }
            self?.reconnectTask = nil
            self?.connect()
        }
    }

    /// Lit la socket jusqu'à sa fermeture et traite chaque message.
    @MainActor
    private func receiveLoop(_ task: URLSessionWebSocketTask) async {
        while !Task.isCancelled && socket === task {
            do {
                let message = try await task.receive()
                guard let raw = text(message),
                      let parsed = EvEventPresenceProtocol.message(from: raw) else { continue }
                handle(parsed, task: task)
            } catch {
                handleDisconnect(task)
                return
            }
        }
    }

    /// Traite un message : `ready` pose l'observation, `event-presence` publie.
    @MainActor
    private func handle(_ message: EvEventPresenceMessage, task: URLSessionWebSocketTask) {
        switch message {
        case .ready:
            send(["type": "watch-event", "eventId": eventId], on: task)
        case let .event(event):
            apply(event)
        }
    }

    /// Coupure involontaire : la socket est abandonnée, puis une nouvelle
    /// tentative est programmée (`onclose` de la source).
    @MainActor
    private func handleDisconnect(_ task: URLSessionWebSocketTask) {
        if socket === task { socket = nil }
        scheduleReconnect()
    }

    /// Envoie une charge JSON sur la socket.
    private func send(_ payload: [String: String], on task: URLSessionWebSocketTask) {
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let text = String(data: data, encoding: .utf8) else { return }
        task.send(.string(text)) { _ in }
    }

    /// Texte d'un message de socket, `nil` pour les charges binaires illisibles.
    private func text(_ message: URLSessionWebSocketTask.Message) -> String? {
        switch message {
        case let .string(value): return value
        case let .data(value): return String(data: value, encoding: .utf8)
        default: return nil
        }
    }
}
