import Foundation

// V1 2026-09-26 (U06#3, U06#4) : fichier neuf. Document de cours d'un chapitre
// (`StoredCourseDocument`) et flashcards du chapitre
// (`CourseFlashcardsDocument`), avec les clés de stockage Expo exactes
// (`prepapp-course-document:v2:{année}:{chapitre}`,
// `prepapp-course-flashcards:v1:{chapitre}`, `src/storage/keys.ts`).

// MARK: - Document de cours

/// Document de cours importé pour un chapitre (`StoredCourseDocument` de
/// `src/utils/courseDocument.ts`), clé de stockage Expo conservée.
enum TrainCourseDocument {
    /// `courseDocumentYearStorageKey(year, chapterId)` (`v2`, par année).
    static func documentKey(year: Int, chapterId: String) -> String {
        "prepapp-course-document:v2:\(year):\(chapterId)"
    }

    /// `courseDocumentStorageKey(chapterId)` (v1 patrimoniale, lue en secours).
    static func legacyDocumentKey(chapterId: String) -> String {
        "prepapp-course-document:v1:\(chapterId)"
    }

    /// Dossier des cours importés (`new Directory(Paths.document,
    /// 'duello-courses')`). Créé au premier import.
    static func importsDirectory() -> URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        return base.appendingPathComponent("duello-courses", isDirectory: true)
    }

    /// Relit le document d'un chapitre (v2 puis v1).
    static func load(year: Int, chapterId: String) -> CtdStoredCourseDocument? {
        let raw = UserDefaults.standard.string(forKey: documentKey(year: year, chapterId: chapterId))
            ?? UserDefaults.standard.string(forKey: legacyDocumentKey(chapterId: chapterId))
        guard let raw, let data = raw.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(CtdStoredCourseDocument.self, from: data)
    }

    /// `serializeStoredCourseDocument` : écrit le document sous la clé v2.
    static func save(_ document: CtdStoredCourseDocument, year: Int, chapterId: String) {
        guard let data = try? JSONEncoder().encode(document),
              let raw = String(data: data, encoding: .utf8)
        else { return }
        UserDefaults.standard.set(raw, forKey: documentKey(year: year, chapterId: chapterId))
    }

    /// Supprime les deux clés (v2 + v1 patrimoniale).
    static func remove(year: Int, chapterId: String) {
        UserDefaults.standard.removeObject(forKey: documentKey(year: year, chapterId: chapterId))
        UserDefaults.standard.removeObject(forKey: legacyDocumentKey(chapterId: chapterId))
    }

    /// Supprime le fichier importé quand il vit sous `duello-courses` : un
    /// éventuel fichier orphelin ne doit ni faire réapparaître le cours ni
    /// bloquer l'interface.
    static func removeFile(uri: String) {
        let directory = importsDirectory()
        let prefix = directory.absoluteString.hasSuffix("/")
            ? directory.absoluteString : directory.absoluteString + "/"
        guard uri.hasPrefix(prefix), let url = URL(string: uri) else { return }
        try? FileManager.default.removeItem(at: url)
    }
}
