//
//  OfflDownloadConfig.swift
//  Duello
//
//  Constantes et limites du contenu hors ligne.
//
//  Fichiers source Expo portés :
//   - `src/content/contentDownloadConfig.ts` (`CONTENT_BASE_URL`,
//     `CONTENT_REFRESH_RETRY_DELAYS_MS`)
//   - `src/content/contentSync.ts` (`CONTENT_MANIFEST_VERSION`,
//     `MAX_CONTENT_BUNDLE_BYTES`, `CONTENT_REQUEST_TIMEOUT_MS`)
//   - `src/content/contentCache.ts` (`CACHE_DIRECTORY`)
//   - `src/content/contentInteractionGate.ts`
//     (`CONTENT_INTERACTION_IDLE_GRACE_MS`)
//   - `src/content/resumableExercisePrefetch.ts`
//     (`EXERCISE_PREFETCH_JOB_STORAGE_KEY`, `EXERCISE_PREFETCH_RETRY_DELAYS_MS`,
//     `EXERCISE_CONTENT_SCAN_DELAY_MS`, `EXERCISE_CONTENT_SCAN_INTERVAL_MS`)
//
//  En natif, `DUELLO_API_URL` est déjà porté par `DuelloAPI.baseURL` : le
//  préfixe `content/` de `CONTENT_BASE_URL` est donc le seul segment à poser.
//
//  Cible : iOS 16.
//
import Foundation

/// Constantes et limites du contenu servi séparément.
enum OfflDownloadConfig {
    /// `CONTENT_MANIFEST_VERSION`.
    static let manifestVersion = 1
    /// `MAX_CONTENT_BUNDLE_BYTES` (24 Mio).
    static let maxBundleBytes = 24 * 1024 * 1024
    /// `CONTENT_REQUEST_TIMEOUT_MS` (liaison lente : 60 s).
    static let requestTimeoutMs = 60_000
    /// `CONTENT_REFRESH_RETRY_DELAYS_MS`.
    static let refreshRetryDelaysMs: [Int] = [2_000, 8_000]
    /// `EXERCISE_PREFETCH_RETRY_DELAYS_MS`.
    static let prefetchRetryDelaysMs: [Int] = [2_000, 10_000, 30_000, 60_000, 300_000]
    /// `EXERCISE_CONTENT_SCAN_DELAY_MS`.
    static let exerciseContentScanDelayMs = 8_000
    /// `EXERCISE_CONTENT_SCAN_INTERVAL_MS`.
    static let exerciseContentScanIntervalMs = 15 * 60 * 1_000
    /// `CONTENT_INTERACTION_IDLE_GRACE_MS`.
    static let interactionIdleGraceMs = 900
    /// `CACHE_DIRECTORY` (dossier Documents de l'application).
    static let cacheDirectoryName = "duello-content"
    /// `EXERCISE_PREFETCH_JOB_STORAGE_KEY`.
    static let exercisePrefetchJobStorageKey = "duello-content:exercise-prefetch:v1"
    /// `CONTENT_BASE_URL` natif : `${DUELLO_API_URL}/content`.
    static let contentPathPrefix = "content"

    /// `isContentBundleId` : l'identifiant correspond-il à une banque connue ?
    static func isContentBundleId(_ value: String) -> Bool {
        OfflContentBundleId(rawValue: value) != nil
    }

    /// `isExerciseStatementBundleId` : banque d'énoncés d'exercice (hors
    /// surcharges manuelles), seule concernée par la file de préchargement.
    static func isExerciseStatementBundleId(_ id: OfflContentBundleId) -> Bool {
        id.rawValue.hasSuffix("-statements")
            && id != .manualExerciseStatementOverrides
            && id != .manualExerciseStatementOverrides2
    }
}
