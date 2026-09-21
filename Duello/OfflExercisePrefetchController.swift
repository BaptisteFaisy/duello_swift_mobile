//
//  OfflExercisePrefetchController.swift
//  Duello
//
//  Contrôleur de la file reprenable du préchargement des énoncés.
//
//  Fichier source Expo porté : `src/content/resumableExercisePrefetch.ts`
//  (`createResumableExercisePrefetchController` : `start`, `pause`, `stop`,
//  `wake`, `enqueue`, `scan`, relance par délais échelonnés).
//
//  Le contrôleur ne duplique pas la progression des fichiers : il ne fait que
//  relancer une passe tant que l'intention persiste, avec des délais croissants
//  bornés par le dernier palier. `enqueue` et `scan` sont équivalents (un scan
//  est lui aussi persisté avant l'appel réseau).
//
//  Cible : iOS 16.
//
import Foundation

/// Contrôleur du préchargement reprenable.
final class OfflExercisePrefetchController {
    private let storage: OfflExercisePrefetchStorage
    private let prefetch: ([OfflContentBundleId]) async throws -> OfflExercisePrefetchResult
    private let isActive: () -> Bool
    private let retryDelays: [Int]

    private var started = false
    private var running = false
    private var rerunRequested = false
    private var retryIndex = 0
    private var retryTask: Task<Void, Never>?

    init(
        storage: OfflExercisePrefetchStorage,
        prefetch: @escaping ([OfflContentBundleId]) async throws -> OfflExercisePrefetchResult,
        isActive: @escaping () -> Bool,
        retryDelays: [Int] = OfflDownloadConfig.prefetchRetryDelaysMs
    ) {
        self.storage = storage
        self.prefetch = prefetch
        self.isActive = isActive
        self.retryDelays = retryDelays
    }

    func start() {
        guard !started else { return }
        started = true
        wake()
    }

    /// `pause` : suspend la relance sans effacer l'intention persistée.
    func pause() {
        clearRetry()
    }

    func stop() {
        started = false
        rerunRequested = false
        clearRetry()
    }

    func wake() {
        rerunRequested = true
        clearRetry()
        if started && isActive() { Task { await self.drain() } }
    }

    /// `enqueue` : enregistre la sélection puis réveille la file.
    func enqueue(_ bundleIds: [OfflContentBundleId]) async {
        await enqueueAndWake(bundleIds)
    }

    /// `scan` : alias d'`enqueue`, persisté avant l'appel réseau.
    func scan(_ bundleIds: [OfflContentBundleId]) async {
        await enqueueAndWake(bundleIds)
    }

    private func enqueueAndWake(_ bundleIds: [OfflContentBundleId]) async {
        guard await OfflExercisePrefetch.enqueueJob(storage, bundleIds: bundleIds) != nil else { return }
        retryIndex = 0
        wake()
    }

    private func scheduleRetry() {
        guard started, isActive(), retryTask == nil else { return }
        let index = min(retryIndex, max(0, retryDelays.count - 1))
        guard index >= 0, index < retryDelays.count else { return }
        let delay = retryDelays[index]
        retryIndex += 1
        retryTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay) * 1_000_000)
            guard let self else { return }
            self.retryTask = nil
            self.wake()
        }
    }

    private func clearRetry() {
        retryTask?.cancel()
        retryTask = nil
    }

    private func drain() async {
        guard !running, started, isActive() else { return }
        running = true
        while started && isActive() && rerunRequested {
            rerunRequested = false
            let status = await OfflExercisePrefetch.runAttempt(storage, prefetch: prefetch)
            if status == .complete || status == .idle {
                retryIndex = 0
            } else if !rerunRequested {
                scheduleRetry()
            }
        }
        running = false
        if started && isActive() && rerunRequested { Task { await self.drain() } }
    }
}
