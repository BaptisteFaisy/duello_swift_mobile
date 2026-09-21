//
//  OfflContentTypes.swift
//  Duello
//
//  Types partagés du contenu hors ligne (LOT L, préfixe `Offl`).
//
//  Fichiers source Expo portés :
//   - `src/content/contentStore.ts` (`ContentBundleId`, `CONTENT_BUNDLE_IDS`)
//   - `src/content/contentSync.ts` (`ContentBundleDescriptor`,
//     `ContentManifest`, `ContentChapterDescriptor`, `ContentChapterRequest`,
//     `ContentCacheEntry`, `PartialContentCacheEntry`,
//     `ChapterContentCacheEntry`, `RemoteContentSummary`,
//     `RemoteContentProgress`, `ExerciseSolutionPayload`)
//   - `src/content/contentDownloadState.ts` (`ContentDownloadState`)
//   - `src/hooks/offlineContentCacheTypes.ts` (`OfflineContentCacheState`)
//
//  Les descripteurs sont `Codable` — contrairement à
//  `DuelloAPI.ContentManifest`, qui n'est que `Decodable` — car le cache disque
//  doit pouvoir les réécrire. Aucun type existant n'est redéfini.
//
//  Cible : iOS 16.
//
import Foundation

/// Banques de sujets servies séparément de l'application (`ContentBundleId`).
enum OfflContentBundleId: String, CaseIterable, Codable {
    case mpExercises = "mp-exercises"
    case mpsiExercises = "mpsi-exercises"
    case mpStatements = "mp-statements"
    case mpsiStatements = "mpsi-statements"
    case ecgAdvanced1Exercises = "ecg-advanced-1-exercises"
    case ecgAdvanced2Exercises = "ecg-advanced-2-exercises"
    case ecgApplied1Exercises = "ecg-applied-1-exercises"
    case ecgApplied2Exercises = "ecg-applied-2-exercises"
    case ecgAdvanced1Statements = "ecg-advanced-1-statements"
    case ecgAdvanced2Statements = "ecg-advanced-2-statements"
    case ecgApplied1Statements = "ecg-applied-1-statements"
    case ecgApplied2Statements = "ecg-applied-2-statements"
    case ecgAdvancedSolutions = "ecg-advanced-solutions"
    case ecgAppliedAnnales2025 = "ecg-applied-annales-2025"
    case ecgAppliedAnnales2024 = "ecg-applied-annales-2024"
    case ecgAppliedAnnalesYear1 = "ecg-applied-annales-year-1"
    case ecgAppliedAnnalesLegendre = "ecg-applied-annales-legendre"
    case oralDriveExercises = "oral-drive-exercises"
    case ecgAdvancedAnnales1 = "ecg-advanced-annales-1"
    case ecgAdvancedAnnales1Kleber = "ecg-advanced-annales-1-kleber"
    case ecgAdvancedAnnales2 = "ecg-advanced-annales-2"
    case ecgAdvancedAnnales2Drive = "ecg-advanced-annales-2-drive"
    case ecgAdvancedMathsIAnnales = "ecg-advanced-maths-i-annales"
    case ecgAdvancedMathsIIAnnales = "ecg-advanced-maths-ii-annales"
    case collesEcgAppliquees1 = "colles-ecg-appliquees-1"
    case collesEcgAppliquees2 = "colles-ecg-appliquees-2"
    case collesEcgApprofondies1 = "colles-ecg-approfondies-1"
    case collesEcgApprofondies2 = "colles-ecg-approfondies-2"
    case collesMpsi1 = "colles-mpsi-1"
    case manualExerciseOverrides = "manual-exercise-overrides"
    case manualExerciseOverrides2 = "manual-exercise-overrides-2"
    case manualExerciseStatementOverrides = "manual-exercise-statement-overrides"
    case manualExerciseStatementOverrides2 = "manual-exercise-statement-overrides-2"

    /// Ordre exact de `CONTENT_BUNDLE_IDS`.
    static let all: [OfflContentBundleId] = [
        .mpExercises, .mpsiExercises, .mpStatements, .mpsiStatements,
        .ecgAdvanced1Exercises, .ecgAdvanced2Exercises,
        .ecgApplied1Exercises, .ecgApplied2Exercises,
        .ecgAdvanced1Statements, .ecgAdvanced2Statements,
        .ecgApplied1Statements, .ecgApplied2Statements,
        .ecgAdvancedSolutions,
        .ecgAppliedAnnales2025, .ecgAppliedAnnales2024,
        .ecgAppliedAnnalesYear1, .ecgAppliedAnnalesLegendre,
        .oralDriveExercises,
        .ecgAdvancedAnnales1, .ecgAdvancedAnnales1Kleber,
        .ecgAdvancedAnnales2, .ecgAdvancedAnnales2Drive,
        .ecgAdvancedMathsIAnnales, .ecgAdvancedMathsIIAnnales,
        .collesEcgAppliquees1, .collesEcgAppliquees2,
        .collesEcgApprofondies1, .collesEcgApprofondies2,
        .collesMpsi1,
        .manualExerciseOverrides, .manualExerciseOverrides2,
        .manualExerciseStatementOverrides, .manualExerciseStatementOverrides2,
    ]
}

/// Descripteur d'une banque dans le manifeste (`ContentBundleDescriptor`).
struct OfflContentBundleDescriptor: Codable, Hashable {
    var id: String
    var file: String
    var size: Int
    var sha256: String
    var count: Int
}

/// Descripteur d'un chapitre dans le manifeste (`ContentChapterDescriptor`).
struct OfflContentChapterDescriptor: Codable, Hashable {
    var bundleId: String
    var chapterId: String
    var file: String
    var size: Int
    var sha256: String
    var count: Int
}

/// Manifeste du contenu servi (`GET /content/manifest.json`).
struct OfflContentManifest: Codable {
    var version: Int
    var publishedAt: String?
    var bundles: [OfflContentBundleDescriptor]?
    var chapters: [OfflContentChapterDescriptor]?
}

/// Demande de chapitre (`ContentChapterRequest`).
struct OfflContentChapterRequest: Codable, Hashable {
    var bundleId: OfflContentBundleId
    var chapterId: String
}

/// Champs communs de vérification d'une banque ou d'un chapitre.
protocol OfflContentEntriesDescriptor {
    var size: Int { get }
    var sha256: String { get }
    var count: Int { get }
}

extension OfflContentBundleDescriptor: OfflContentEntriesDescriptor {}
extension OfflContentChapterDescriptor: OfflContentEntriesDescriptor {}

/// Entrée de cache disque d'une banque (`ContentCacheEntry`).
struct OfflContentCacheEntry {
    var descriptor: OfflContentBundleDescriptor
    var serialized: String
}

/// Entrée de cache disque d'une sélection ciblée (`PartialContentCacheEntry`).
struct OfflPartialContentCacheEntry {
    var sourceDigest: String
    var digest: String
    var serialized: String
}

/// Entrée de cache disque d'un chapitre (`ChapterContentCacheEntry`).
struct OfflChapterContentCacheEntry {
    var descriptor: OfflContentChapterDescriptor
    var serialized: String
}

/// Corrigé unitaire servi (`ExerciseSolutionPayload`).
struct OfflExerciseSolutionPayload: Codable {
    var version: Int
    var itemId: String
    var solution: String?
    var sha256: String
}

/// Bilan d'une synchronisation de banques (`RemoteContentSummary`).
struct OfflRemoteContentSummary {
    var checked: Int
    var downloaded: [OfflContentBundleId]
    var rejected: [OfflContentBundleId]

    static let empty = OfflRemoteContentSummary(checked: 0, downloaded: [], rejected: [])
}

/// Avancement d'une synchronisation (`RemoteContentProgress`).
struct OfflRemoteContentProgress {
    var completed: Int
    var total: Int
    var currentId: OfflContentBundleId?
}

/// Résultat d'un téléchargement d'exercice ciblé.
struct OfflExerciseDownloadResult {
    var downloaded: [OfflContentBundleId]
    var rejected: [OfflContentBundleId]

    static let empty = OfflExerciseDownloadResult(downloaded: [], rejected: [])
}

/// Résultat d'un téléchargement de chapitres.
struct OfflChapterDownloadResult {
    var downloaded: [OfflContentChapterRequest]
    var rejected: [OfflContentChapterRequest]

    static let empty = OfflChapterDownloadResult(downloaded: [], rejected: [])
}

/// Issue d'une banque pendant la synchronisation.
enum OfflBundleOutcome {
    case known
    case downloaded
    case rejected
}

/// Erreur locale de synchronisation (jamais affichée telle quelle).
enum OfflContentError: Error {
    case download
    case integrity
    case missing
}

/// Statut du téléchargement manuel ou automatique (`ContentDownloadState`).
enum OfflContentDownloadStatus: String {
    case idle, checking, downloading, complete, error
}

/// État partagé du téléchargement des banques.
struct OfflContentDownloadState {
    var status: OfflContentDownloadStatus
    var completed: Int
    var total: Int
    var downloaded: Int
    var rejected: Int

    static let initial = OfflContentDownloadState(
        status: .idle, completed: 0, total: 0, downloaded: 0, rejected: 0
    )
}

/// Statut du cache hors connexion (`OfflineContentCacheStatus`).
enum OfflOfflineCacheStatus: String {
    case unsupported, idle, requesting, downloading, complete, error
}

/// État du cache hors connexion (`OfflineContentCacheState`).
struct OfflOfflineCacheState {
    var status: OfflOfflineCacheStatus
    var completed: Int
    var total: Int
    var cached: Int
    var totalBytes: Int
    var downloadedBytes: Int
    var downloadedItems: Int
    var activeItems: Int
    var totalItems: Int
    var updatedAt: String?
    var error: String?

    /// Le cache HTTP complet est propre à la PWA ; le socle natif reste embarqué.
    static let unsupported = OfflOfflineCacheState(
        status: .unsupported, completed: 0, total: 0, cached: 0,
        totalBytes: 0, downloadedBytes: 0, downloadedItems: 0,
        activeItems: 0, totalItems: 0, updatedAt: nil, error: nil
    )
}
