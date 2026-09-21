//
//  RewFollowQueue.swift
//  Duello
//
//  File de publication des listes d'abonnements d'un utilisateur.
//
//  Fichier source Expo porté (commentaires repris mot pour mot) :
//    - src/utils/followPublicationQueue.ts   (`createFollowPublicationQueue`)
//
//  La source fabrique une fonction `enqueueFollowPublication(userId, body)` qui
//  retient, par utilisateur, la dernière liste publiée et la queue d'écriture.
//  Porté sous forme de classe : `init(publish:)` puis `enqueue(userId:body:)`.
//
//  Cible : iOS 16, aucune dépendance externe.
//
import Foundation

/// Garantit que deux listes complètes d'abonnements arrivent dans leur ordre.
final class RewFollowQueue {
    /// État par utilisateur (`FollowPublicationState`).
    private final class Slot {
        /// Dernière liste publiée pour cet utilisateur.
        var published: String?
        /// Queue d'écriture de l'utilisateur.
        var tail: Task<Void, Never>

        init() { tail = Task {} }
    }

    private let lock = NSLock()
    private var slots: [String: Slot] = [:]
    private let publish: (String) async throws -> Void

    init(publish: @escaping (String) async throws -> Void) {
        self.publish = publish
    }

    /// `enqueueFollowPublication` : publie `body` s'il n'est pas déjà la
    /// dernière liste publiée de l'utilisateur, en série par utilisateur.
    func enqueue(userId: String, body: String) async throws {
        lock.lock()
        let slot = slots[userId] ?? Slot()
        slots[userId] = slot
        let previous = slot.tail
        let operation = Task<Void, Error> {
            _ = try? await previous.value
            if slot.published == body { return }
            try await publish(body)
            slot.published = body
        }
        slot.tail = Task { _ = try? await operation.value }
        lock.unlock()
        try await operation.value
    }
}
