//
//  SubjChapterNotebook+Storage.swift
//  Duello
//
//  Port de src/storage/keys.ts (RN) — emplacement local du carnet d'un chapitre
//  (`chapterNotebookStorageKey`, préfixe `prepapp-chapter-notebook:v1:`), lecture
//  et écriture synchrones dans `UserDefaults`.
//
//  Découpage (24/09/2026) : section extraite de `SubjChapterNotebook.swift`
//  (porté du même fichier source).
//
//  Cible : iOS 16, aucune dépendance externe.
//
import Foundation

// MARK: - Persistance locale

/// Emplacement local du carnet d'un chapitre.
enum ChapterNotebookStorage {
    /// `chapterNotebookStorageKey(chapterId)` : la clé logique
    /// (`prepapp-chapter-notebook:v1:`) est conservée à l'identique.
    static func chapterNotebookKey(chapterId: String) -> String {
        "prepapp-chapter-notebook:v1:\(chapterId)"
    }

    /// Relecture du carnet d'un chapitre (`parseChapterNotebook`).
    static func loadChapterNotebook(chapterId: String) -> ChapterNotebook {
        let raw = UserDefaults.standard.string(forKey: chapterNotebookKey(chapterId: chapterId))
        return ChapterNotebookCodec.parseChapterNotebook(raw)
    }

    /// Écriture du carnet d'un chapitre (`serializeChapterNotebook`).
    static func saveChapterNotebook(_ notebook: ChapterNotebook, chapterId: String) {
        let text = ChapterNotebookCodec.serializeChapterNotebook(notebook)
        guard !text.isEmpty else { return }
        UserDefaults.standard.set(text, forKey: chapterNotebookKey(chapterId: chapterId))
    }
}
