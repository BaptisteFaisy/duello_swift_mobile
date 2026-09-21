import Foundation

// Porté depuis `src/utils/remotePhotoSessions.ts` (lot N, photo à distance).
// Cycle de vie de la session : création (ordinateur), lecture d'état, session
// courante du compte, réclamation par le téléphone, déconnexion des deux
// côtés. Aucune modification de `DuelloAPI.swift`.

/// Sessions de connexion photo à distance (ordinateur ↔ téléphone).
enum RemPhotoSessions {
    /// `createRemotePhotoSession` : ouvre une session en attente d'appairage.
    static func create(token: String?) async throws -> RemPhotoSessionCreated {
        let data = try await RemPhotoAPI.request(
            path: RemPhotoAPI.sessionPath,
            method: "POST",
            token: token
        )
        if let session = RemPhotoProtocol.parseSessionCreated(RemPhotoAPI.dictionary(data)) {
            return session
        }
        throw RemPhotoError(
            message: "Le serveur a renvoyé une session illisible.",
            status: nil,
            code: "invalid-remote-photo-session"
        )
    }

    /// `fetchRemotePhotoSession` : état d'une session précise.
    static func fetch(token: String?, sessionId: String) async throws -> RemPhotoSessionStatus {
        let data = try await RemPhotoAPI.request(
            path: RemPhotoAPI.sessionPath,
            token: token,
            query: [URLQueryItem(name: "id", value: sessionId)]
        )
        if let status = RemPhotoProtocol.parseSessionStatus(RemPhotoAPI.dictionary(data)) {
            return status
        }
        throw RemPhotoError(
            message: "Le serveur a renvoyé un état de connexion illisible.",
            status: nil,
            code: "invalid-remote-photo-status"
        )
    }

    /// `fetchCurrentRemotePhotoSession` : session ouverte du compte, sinon `nil`.
    static func current(token: String?) async throws -> RemPhotoSessionStatus? {
        let data = try await RemPhotoAPI.request(path: RemPhotoAPI.currentSessionPath, token: token)
        let payload = RemPhotoAPI.dictionary(data)
        if payload["session"] is NSNull { return nil }
        if let status = RemPhotoProtocol.parseSessionStatus(payload["session"]) { return status }
        throw RemPhotoError(
            message: "Le serveur a renvoyé une connexion PC illisible.",
            status: nil,
            code: "invalid-remote-photo-status"
        )
    }

    /// `claimRemotePhotoSession` : relie le téléphone à la session du même
    /// compte, sans QR ni jeton. `nil` tant qu'aucun PC n'a ouvert de session.
    static func claim(token: String?) async throws -> RemPhotoClaimedSession? {
        let data = try await RemPhotoAPI.request(
            path: RemPhotoAPI.claimPath,
            method: "POST",
            token: token,
            headers: ["Content-Type": "application/json"],
            body: RemPhotoAPI.jsonBody([:])
        )
        let payload = RemPhotoAPI.dictionary(data)
        guard let raw = payload["session"], !(raw is NSNull) else { return nil }
        if let session = RemPhotoProtocol.parseClaimedSession(raw) { return session }
        throw RemPhotoError(
            message: "Le serveur a renvoyé une connexion PC illisible.",
            status: nil,
            code: "invalid-remote-photo-claim"
        )
    }

    /// `disconnectRemotePhotoOwner` : l'ordinateur ferme sa session.
    static func disconnectOwner(token: String?, sessionId: String) async throws {
        _ = try await RemPhotoAPI.request(
            path: RemPhotoAPI.sessionPath,
            method: "DELETE",
            token: token,
            query: [URLQueryItem(name: "id", value: sessionId)]
        )
    }

    /// `disconnectRemotePhotoSender` : le téléphone se détache via son jeton.
    static func disconnectSender(token: String?, pairingToken: String) async throws {
        _ = try await RemPhotoAPI.request(
            path: RemPhotoAPI.sessionPath,
            method: "DELETE",
            token: token,
            headers: [RemPhotoAPI.pairingHeader: pairingToken]
        )
    }
}
