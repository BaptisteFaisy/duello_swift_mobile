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
    ///
    /// R07 2026-09-29 (U06#2) : les banques servies d'**annales**
    /// (`ecg-*-annales-*.json`) portent, au-delà du socle
    /// `key/chapterId/title/difficulty/statement/solution`, les métadonnées de
    /// fiche du catalogue généré (`compactTrainingCatalogItem` /
    /// `exerciseCatalogItems`, `scripts/build-embedded-floor.mjs:415-440`) :
    /// `kind`, `notions`, `badges`, `roles`, `annaleTypes`, `theme`,
    /// `programStatus`, `sourceUrl`, `solutionUrl`, `markingScheme`,
    /// `markingSchemeUrl`, `comments`, `commentsUrl`. Sans elles, les annales
    /// servies restaient plus pauvres que la source (badges, type d'épreuve,
    /// thème et attribution perdus). Toutes facultatives : les banques
    /// d'exercices qui ne les portent pas décodent à l'identique.
    struct ChapterExercise: Decodable {
        var key: String
        var chapterId: String
        var title: String
        var difficulty: Int?
        var statement: String
        var solution: String?
        /// `kind` : nature du sujet (`ChapterItem.kind`, `exercice`/`colle`…).
        var kind: String?
        /// `notions` : notions éditoriales du sujet (`ChapterItem.notions`).
        var notions: [String]?
        /// `badges` : format ou domaine signalé sur la fiche
        /// (`ChapterItem.badges`).
        var badges: [String]?
        /// `roles` : fonction pédagogique (`ChapterItem.roles`).
        var roles: [String]?
        /// `annaleTypes` : épreuve ou banque de concours (`ChapterItem.annaleTypes`),
        /// lue par le filtre « Type » des annales.
        var annaleTypes: [String]?
        /// `theme` : thème d'annale (`ChapterItem.theme`, `analyse`/`algebre`/
        /// `probabilites`).
        var theme: String?
        /// `programStatus` : périmètre par rapport au programme (`ChapterItem.programStatus`,
        /// `au-programme`/`a-verifier`/`hors-programme`).
        var programStatus: String?
        /// `sourceUrl` : énoncé original à ouvrir (`ChapterItem.sourceUrl`).
        var sourceUrl: String?
        /// `solutionUrl` : corrigé hébergé séparément (`ChapterItem.solutionUrl`).
        var solutionUrl: String?
        /// `markingScheme` : barème officiel retranscrit
        /// (`ChapterItem.markingScheme`).
        var markingScheme: String?
        /// `markingSchemeUrl` : barème hébergé séparément
        /// (`ChapterItem.markingSchemeUrl`).
        var markingSchemeUrl: String?
        /// `comments` : commentaires généraux officiels retranscrits
        /// (`ChapterItem.comments`).
        var comments: String?
        /// `commentsUrl` : commentaires hébergés séparément
        /// (`ChapterItem.commentsUrl`).
        var commentsUrl: String?
    }

    /// `GET /content/<chemin du descripteur>` — énoncés d'un chapitre.
    static func chapterExercises(_ descriptor: ContentChapterDescriptor) async throws -> [ChapterExercise] {
        let data = try await request("content/" + descriptor.file)
        return try decoder.decode([ChapterExercise].self, from: data)
    }
}
