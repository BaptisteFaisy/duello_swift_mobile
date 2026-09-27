import Foundation

// V1 2026-09-26 (U06#4) : flashcards du chapitre (`CourseFlashcardsDocument`),
// clé de stockage Expo conservée (`src/storage/keys.ts`).
// Scindé depuis `TrainCourseStore.swift` (ratchet : ≤ 10 fonctions/fichier).

// MARK: - Flashcards du chapitre

/// Flashcards d'un chapitre (`CourseFlashcardsDocument`), clé de stockage Expo
/// conservée (`courseFlashcardsStorageKey`, `prepapp-course-flashcards:v1:`).
enum TrainChapterFlashcards {
    /// `courseFlashcardsStorageKey(chapterId)`.
    static func storageKey(chapterId: String) -> String {
        "prepapp-course-flashcards:v1:\(chapterId)"
    }

    /// Relit les cartes du chapitre, `nil` si absentes ou illisibles.
    static func load(chapterId: String) -> CollFlashcardsDocument? {
        let raw = UserDefaults.standard.string(forKey: storageKey(chapterId: chapterId))
        return CollFlashcards.parse(raw)
    }

    /// `saveCourseFlashcards` : écrit les cartes du chapitre.
    static func save(_ document: CollFlashcardsDocument, chapterId: String) {
        guard let raw = CollFlashcards.serialize(document) else { return }
        UserDefaults.standard.set(raw, forKey: storageKey(chapterId: chapterId))
    }

    /// Date du jour en millisecondes (`Date.now()` de la source).
    static func now() -> Double { Date().timeIntervalSince1970 * 1000 }
}
