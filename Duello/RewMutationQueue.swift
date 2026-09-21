//
//  RewMutationQueue.swift
//  Duello
//
//  File d'écriture des sources d'XP d'un même compte.
//
//  Fichier source Expo porté (commentaires repris mot pour mot) :
//    - src/utils/activityMutationQueue.ts   (`enqueueActivityMutation`)
//
//  La source garde une `Map<string, Promise>` globale, clé = identifiant de
//  compte : chaque mutation attend la précédente du même compte. Porté tel quel
//  (une file par compte, portée par l'instance). L'accès à la table est protégé
//  par un verrou ; la file est alimentée depuis des contextes `async`.
//
//  Cible : iOS 16, aucune dépendance externe.
//
import Foundation

/// Sérialise toutes les sources d'XP d'un même compte, y compris les bonus.
final class RewMutationQueue {
    /// Maillon de file : la tâche en cours pour un compte.
    private final class Slot {
        let task: Task<Void, Never>
        init(_ task: Task<Void, Never>) { self.task = task }
    }

    private let lock = NSLock()
    private var tails: [String: Slot] = [:]

    /// `enqueueActivityMutation` : attend la mutation précédente du même compte,
    /// puis exécute celle-ci. Une mutation précédente en échec n'empêche pas la
    /// suivante (`previous.catch(() => undefined)`).
    func enqueue<Result>(
        accountId: String,
        _ operation: @escaping () async throws -> Result
    ) async throws -> Result {
        lock.lock()
        let previous = tails[accountId]?.task
        let running = Task<Result, Error> {
            if let previous { _ = await previous.value }
            return try await operation()
        }
        let tail = Slot(Task { _ = try? await running.value })
        tails[accountId] = tail
        lock.unlock()

        defer {
            lock.lock()
            if tails[accountId] === tail { tails[accountId] = nil }
            lock.unlock()
        }
        return try await running.value
    }
}
