//
//  CollFlashcardGenerationPool.swift
//  Duello
//
//  Port de src/utils/courseFlashcardsApi.ts (RN) — générations en vol
//  (`inFlightGenerations`) : un même document et chapitre ne part qu'une fois.
//
//  Notes datées (24/09/2026) :
//    - Le `Map<string, Promise>` de la source devient un dictionnaire de
//      `Task` gardé par un verrou (`NSLock`) : la comparaison d'identité
//      (`===` de la source) est reproduite par l'`UUID` de l'entrée.
//
//  Cible : iOS 16, aucune dépendance externe.
//

import Foundation

/// `inFlightGenerations` : un même document et chapitre ne part qu'une fois ;
/// les appelants concurrents attendent la même tâche.
final class CollFlashcardGenerationPool {
    static let shared = CollFlashcardGenerationPool()

    private struct Entry {
        let id = UUID()
        let task: Task<CollFlashcardsDocument, Error>
    }

    private let lock = NSLock()
    private var entries: [String: Entry] = [:]

    /// Tâche partagée de la clé, créée par `make` si elle n'existe pas encore.
    func shared(
        forKey key: String,
        make: () -> Task<CollFlashcardsDocument, Error>
    ) -> Task<CollFlashcardsDocument, Error> {
        lock.lock()
        if let entry = entries[key] {
            lock.unlock()
            return entry.task
        }
        let entry = Entry(task: make())
        entries[key] = entry
        lock.unlock()
        Task { [weak self] in
            _ = try? await entry.task.value
            self?.drop(key: key, id: entry.id)
        }
        return entry.task
    }

    /// Retire l'entrée si c'est toujours la même tâche (`===` de la source).
    private func drop(key: String, id: UUID) {
        lock.lock()
        defer { lock.unlock() }
        if entries[key]?.id == id { entries[key] = nil }
    }
}
