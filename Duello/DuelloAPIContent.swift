import Foundation

// Découpage de `DuelloAPI.swift` — contenu servi : manifeste des banques et
// énoncés réels d'un chapitre. Aucun type, membre ni signature renommé.

extension DuelloAPI {
    // MARK: Contenu servi (énoncés réels)

    /// Descripteur d'une banque servie (`ContentBundleDescriptor`).
    struct ContentBundleDescriptor: Decodable {
        var id: String
        var file: String
        var size: Int
        var sha256: String
        var count: Int
    }

    /// Descripteur d'un chapitre au sein du manifeste.
    struct ContentChapterDescriptor: Decodable {
        var bundleId: String
        var chapterId: String
        var file: String
        var size: Int
        var sha256: String
        var count: Int
    }

    /// Manifeste du contenu servi (`GET /content/manifest.json`).
    struct ContentManifest: Decodable {
        var version: Int
        var publishedAt: String?
        var bundles: [ContentBundleDescriptor]?
        var chapters: [ContentChapterDescriptor]?
    }

    /// `GET /content/manifest.json` — descripteurs des banques servies.
    static func contentManifest() async throws -> ContentManifest {
        try await request(ContentManifest.self, "content/manifest.json")
    }

    /// Énoncé réel servi par le serveur (`ExerciseSeedShape` de
    /// `content/servedBank.ts`). Seuls les champs lus par le joueur sont
    /// décodés ; `source` et les liens d'attribution restent côté écran web.
    struct ChapterExercise: Decodable {
        var key: String
        var chapterId: String
        var title: String
        var difficulty: Int?
        var statement: String
        var solution: String?
    }

    /// `GET /content/<chemin du descripteur>` — énoncés d'un chapitre.
    static func chapterExercises(_ descriptor: ContentChapterDescriptor) async throws -> [ChapterExercise] {
        let data = try await request("content/" + descriptor.file)
        return try decoder.decode([ChapterExercise].self, from: data)
    }
}
