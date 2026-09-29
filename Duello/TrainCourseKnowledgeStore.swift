import Foundation

// V3 2026-09-29 (complexité) : extrait de `TrainCourseStore.swift` (qui portait
// 12 fonctions, seuil 10). Index de connaissances d'un chapitre
// (`courseKnowledgeIndexStorageKey` / `courseKnowledgeJobStorageKey`,
// `src/storage/keys.ts`), relu et rangé à l'ouverture de la page « Mon cours ».
// Corps et clés de stockage inchangés.

/// Index de connaissances d'un chapitre (`courseKnowledgeIndexStorageKey` /
/// `courseKnowledgeJobStorageKey`, `src/storage/keys.ts`), relu et rangé à
/// l'ouverture de la page « Mon cours ».
enum TrainCourseKnowledge {
    /// `courseKnowledgeIndexStorageKey(year, chapterId)`.
    static func storageKey(year: Int, chapterId: String) -> String {
        "prepapp-course-knowledge-index:v1:\(year):\(chapterId)"
    }

    /// `courseKnowledgeJobStorageKey(year, chapterId)`.
    static func jobStorageKey(year: Int, chapterId: String) -> String {
        "prepapp-course-knowledge-job:v1:\(year):\(chapterId)"
    }

    /// Relit l'index du chapitre, `nil` si absent ou illisible.
    static func load(year: Int, chapterId: String) -> CollKnowledgeDocument? {
        CollCourseIndex.parse(
            UserDefaults.standard.string(forKey: storageKey(year: year, chapterId: chapterId))
        )
    }

    /// `serializeCourseKnowledgeIndex` : écrit l'index du chapitre.
    static func save(_ index: CollKnowledgeDocument, year: Int, chapterId: String) {
        guard let raw = CollCourseIndex.serialize(index) else { return }
        UserDefaults.standard.set(raw, forKey: storageKey(year: year, chapterId: chapterId))
    }

    /// Supprime l'index du chapitre (nouveau document importé ou suppression).
    static func remove(year: Int, chapterId: String) {
        UserDefaults.standard.removeObject(forKey: storageKey(year: year, chapterId: chapterId))
    }
}
