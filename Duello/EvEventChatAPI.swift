//
//  EvEventChatAPI.swift
//  Duello
//
//  Extension d'`EvEventAPI` : chat des participants d'un événement — lecture
//  (`chat`), dépôt (`postChat`) et relecture d'un message (`chatMessage`).
//  Découpe de `EvEventAPI.swift` (limite de 10 fonctions par fichier),
//  comportement inchangé.
//
//  Fichier source Expo porté : `src/utils/eventApi.ts` (routes
//  `/api/events/...` du serveur social) — `fetchEventChat` /
//  `postEventChatMessage` / `sanitizeChatMessage`.
//
//  Cible : iOS 16.
//
import Foundation

extension EvEventAPI {
    /// Lit la discussion d'un événement, du plus ancien au plus récent
    /// (`fetchEventChat`). Pendant l'épreuve, le serveur répond 403 : le chat
    /// est fermé, comme le bouton.
    static func chat(eventId: String, token: String?) async throws -> EvEventChatState {
        let data = try await DuelloAPI.request(path(eventId, "chat"), token: token)
        let object = json(data)
        let messages = (object["messages"] as? [Any])?.compactMap(chatMessage) ?? []
        return EvEventChatState(messages: messages, total: whole(object["total"]))
    }

    /// Dépose un message dans le chat d'un événement (`postEventChatMessage`).
    /// Un texte vide est refusé avant l'envoi ; pendant l'épreuve, le serveur
    /// répond 403.
    static func postChat(eventId: String, text: String, token: String?) async throws {
        let trimmed = String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(500))
        guard !trimmed.isEmpty else {
            throw DirectoryError(message: "Écris un message avant de l’envoyer.")
        }
        let body = try JSONSerialization.data(withJSONObject: ["body": trimmed], options: [])
        _ = try await DuelloAPI.request(path(eventId, "chat"), method: "POST", token: token, body: body)
    }

    /// Relit un message du chat (`sanitizeChatMessage`) ; `nil` sur une forme
    /// inattendue. Le corps est borné à 500 caractères, comme côté serveur.
    ///
    /// Extrait de `EvEventAPI.swift` : était `private` (portée fichier) ;
    /// `private` retiré, élargi à `internal` car la fonction est appelée par
    /// `chat` depuis cette extension — corps inchangé.
    static func chatMessage(_ value: Any) -> EvEventChatMessage? {
        guard let object = value as? [String: Any],
              let id = object["id"] as? String, !id.isEmpty,
              let authorId = object["authorId"] as? String, !authorId.isEmpty,
              let displayName = object["displayName"] as? String, !displayName.isEmpty,
              let body = object["body"] as? String, !body.isEmpty,
              let rawCreated = object["createdAt"], !(rawCreated is Bool),
              let createdAt = rawCreated as? Double, createdAt.isFinite
        else { return nil }
        return EvEventChatMessage(
            id: id,
            authorId: authorId,
            displayName: displayName,
            photoUri: object["photoUri"] as? String,
            body: String(body.prefix(500)),
            createdAt: createdAt
        )
    }
}
