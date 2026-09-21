//
//  OfflResumablePrefetch.swift
//  Duello
//
//  File persistante du préchargement des énoncés.
//
//  Fichier source Expo porté : `src/content/resumableExercisePrefetch.ts`
//  (`ExercisePrefetchStorage`, `ExercisePrefetchJob`, `ExercisePrefetchResult`,
//  `ExercisePrefetchAttemptStatus`, `parseExercisePrefetchJob`,
//  `enqueueExercisePrefetchJob`, `exercisePrefetchCompleted`,
//  `runExercisePrefetchAttempt`).
//
//  Les fichiers de chapitre sont déjà écrits et validés un par un par le
//  préchargement ; cette file ne conserve donc que l'intention de terminer le
//  corpus. Après une fermeture ou une panne, une nouvelle tentative saute les
//  chapitres à jour et repart au premier manquant.
//
//  Cible : iOS 16.
//
import Foundation

/// Stockage clé/valeur de la file (`ExercisePrefetchStorage`).
protocol OfflExercisePrefetchStorage {
    func getItem(_ key: String) async -> String?
    func setItem(_ key: String, _ value: String) async
    func removeItem(_ key: String) async
}

/// Intention persistée (`ExercisePrefetchJob`).
struct OfflExercisePrefetchJob: Codable {
    var version: Int
    var bundleIds: [OfflContentBundleId]
}

/// Bilan d'une passe (`ExercisePrefetchResult`).
struct OfflExercisePrefetchResult {
    var downloaded: [OfflContentChapterRequest]
    var rejected: [OfflContentChapterRequest]
}

/// Statut d'une passe (`ExercisePrefetchAttemptStatus`).
enum OfflExercisePrefetchAttemptStatus {
    case idle, pending, complete
}

/// Règles pures de la file reprenable.
enum OfflExercisePrefetch {
    /// `parseExercisePrefetchJob` : intention valide, ou `nil`.
    static func parseJob(_ serialized: String?) -> OfflExercisePrefetchJob? {
        guard let serialized, let data = serialized.data(using: .utf8),
              let candidate = try? JSONDecoder().decode(OfflExercisePrefetchJob.self, from: data),
              candidate.version == 1
        else { return nil }
        let bundleIds = candidate.bundleIds.filter { OfflDownloadConfig.isExerciseStatementBundleId($0) }
        guard !bundleIds.isEmpty,
              bundleIds.count == candidate.bundleIds.count,
              Set(bundleIds).count == bundleIds.count
        else { return nil }
        return OfflExercisePrefetchJob(version: 1, bundleIds: bundleIds)
    }

    /// `enqueueExercisePrefetchJob` : enregistre l'intention avant le réseau.
    static func enqueueJob(_ storage: OfflExercisePrefetchStorage, bundleIds: [OfflContentBundleId]) async -> OfflExercisePrefetchJob? {
        let normalized = normalizedBundleIds(bundleIds)
        guard !normalized.isEmpty else { return nil }
        if let current = parseJob(await storage.getItem(OfflDownloadConfig.exercisePrefetchJobStorageKey)),
           current.bundleIds.count == normalized.count,
           zip(current.bundleIds, normalized).allSatisfy({ pair in pair.0 == pair.1 }) {
            return current
        }
        let job = OfflExercisePrefetchJob(version: 1, bundleIds: normalized)
        if let data = try? JSONEncoder().encode(job), let text = String(data: data, encoding: .utf8) {
            await storage.setItem(OfflDownloadConfig.exercisePrefetchJobStorageKey, text)
        }
        return job
    }

    /// `exercisePrefetchCompleted` : toutes les banques ont un chapitre vérifié.
    static func completed(_ job: OfflExercisePrefetchJob, _ result: OfflExercisePrefetchResult) -> Bool {
        if !result.rejected.isEmpty { return false }
        let downloaded = Set(result.downloaded.map { $0.bundleId })
        return job.bundleIds.allSatisfy { downloaded.contains($0) }
    }

    /// `runExercisePrefetchAttempt` : une passe reprenable, clé retirée au succès.
    static func runAttempt(
        _ storage: OfflExercisePrefetchStorage,
        prefetch: ([OfflContentBundleId]) async throws -> OfflExercisePrefetchResult
    ) async -> OfflExercisePrefetchAttemptStatus {
        guard let serialized = await storage.getItem(OfflDownloadConfig.exercisePrefetchJobStorageKey) else {
            return .idle
        }
        guard let job = parseJob(serialized) else {
            await storage.removeItem(OfflDownloadConfig.exercisePrefetchJobStorageKey)
            return .idle
        }
        guard let result = try? await prefetch(job.bundleIds) else { return .pending }
        if !completed(job, result) { return .pending }
        // Une nouvelle sélection enregistrée pendant la passe ne doit jamais
        // être effacée par l'ancienne tâche qui vient de finir.
        guard let latest = parseJob(await storage.getItem(OfflDownloadConfig.exercisePrefetchJobStorageKey)) else {
            return .complete
        }
        if !sameBundleSet(latest.bundleIds, job.bundleIds) { return .pending }
        await storage.removeItem(OfflDownloadConfig.exercisePrefetchJobStorageKey)
        return .complete
    }

    /// `normalizedBundleIds` : banques d'énoncés, dédupliquées, ordre conservé.
    static func normalizedBundleIds(_ bundleIds: [OfflContentBundleId]) -> [OfflContentBundleId] {
        var seen = Set<OfflContentBundleId>()
        var result: [OfflContentBundleId] = []
        for id in bundleIds where OfflDownloadConfig.isExerciseStatementBundleId(id) {
            if seen.insert(id).inserted { result.append(id) }
        }
        return result
    }

    /// `sameBundleSet` : mêmes banques, sans tenir compte de l'ordre.
    static func sameBundleSet(_ left: [OfflContentBundleId], _ right: [OfflContentBundleId]) -> Bool {
        left.count == right.count && Set(left) == Set(right)
    }
}
