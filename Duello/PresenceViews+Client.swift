//
//  PresenceViews+Client.swift
//  Duello
//
//  Lot « Social » — client WebSocket de présence (suite de `PresenceViews.swift`).
//
//  Fichier source Expo porté : `src/hooks/usePresenceConnection.ts`
//  (socket, authentification, reconnexion après coupure involontaire).
//
//  Extrait de `PresenceViews.swift` pour respecter la règle « ≤ 10 fonctions par
//  fichier » (AGENTS.md du projet) : ce fichier ne porte que le cycle de vie de
//  la socket de `SocPresenceStore`, laissé intact ailleurs.
//
//  La socket est portée par `URLSessionWebSocketTask` (iOS 13+), l'équivalent
//  natif de `WebSocket` côté Expo : rien n'est simulé.
//
//  Cible : iOS 16, aucune API iOS 17.
//
import Foundation

extension SocPresenceStore {
    /// Ouvre la socket de la session active.
    ///
    /// Sans compte connecté — ou sans jeton, comme `usePresenceConnection` qui
    /// attend une session serveur — rien ne s'ouvre : un invité local n'est
    /// jamais annoncé en ligne.
    ///
    /// Volontairement non isolée : les appelants sont les rappels SwiftUI
    /// (ouverture, retour au premier plan), qui s'exécutent déjà sur le fil
    /// principal.
    func connect(accountId: String, token: String?) {
        guard !accountId.isEmpty, let token, socket == nil else { return }
        guard let url = SocPresenceProtocol.socketURL(for: DuelloAPI.baseURL) else { return }

        let task = URLSession.shared.webSocketTask(with: url)
        socket = task
        task.resume()

        if let payload = try? JSONSerialization.data(withJSONObject: ["type": "authenticate", "token": token]),
           let text = String(data: payload, encoding: .utf8) {
            task.send(.string(text)) { _ in }
        }

        receiveTask = Task { [weak self] in
            await self?.receiveLoop(task, accountId: accountId, token: token)
        }
    }

    /// Ferme la socket : la personne n'est plus « en ligne ». La dernière
    /// photographie des connectés reste affichée, comme côté Expo.
    func disconnect() {
        receiveTask?.cancel()
        receiveTask = nil
        socket?.cancel(with: .goingAway, reason: nil)
        socket = nil
        isConnected = false
    }

    /// Lit la socket jusqu'à sa fermeture et applique chaque événement.
    @MainActor
    private func receiveLoop(_ task: URLSessionWebSocketTask, accountId: String, token: String?) async {
        while !Task.isCancelled && socket === task {
            do {
                let message = try await task.receive()
                let raw: String?
                switch message {
                case let .string(value): raw = value
                case let .data(value): raw = String(data: value, encoding: .utf8)
                default: raw = nil
                }
                guard let raw, let event = SocPresenceProtocol.event(from: raw) else { continue }
                apply(event)
            } catch {
                await handleDisconnect(accountId: accountId, token: token)
                return
            }
        }
    }

    /// Coupure involontaire : la socket est abandonnée, puis une nouvelle
    /// tentative est programmée (`scheduleReconnect`).
    @MainActor
    private func handleDisconnect(accountId: String, token: String?) async {
        socket = nil
        isConnected = false
        try? await Task.sleep(nanoseconds: Self.reconnectDelayNanoseconds)
        guard !Task.isCancelled else { return }
        connect(accountId: accountId, token: token)
    }
}
