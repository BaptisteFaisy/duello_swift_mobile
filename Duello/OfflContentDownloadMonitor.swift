//
//  OfflContentDownloadMonitor.swift
//  Duello
//
//  État partagé du téléchargement des banques (observable SwiftUI).
//
//  Fichiers source Expo portés : `src/content/contentDownloadState.ts`
//  (`setContentDownloadState`, `contentDownloadState`,
//  `subscribeToContentDownload`), `src/content/contentDownloadCoordinator.ts`
//  (`downloadContent` avec déduplication d'une synchronisation en vol) et
//  `src/hooks/useContentDownload.ts`.
//
//  Une seule synchronisation tourne à la fois : une demande identique partage
//  la tâche en cours, une demande différente attend la fin de la précédente.
//  Les mises à jour de `@Published` sont ramenées sur le fil principal ; leur
//  ordre est préservé (file principale FIFO), l'état final arrivant après les
//  progressions.
//
//  Cible : iOS 16.
//
import Combine
import Foundation

/// Moniteur observable du téléchargement des banques (`useContentDownload`).
final class OfflContentDownloadMonitor: ObservableObject {
    static let shared = OfflContentDownloadMonitor()

    @Published private(set) var state = OfflContentDownloadState.initial

    private let lock = NSLock()
    private var activeTask: Task<OfflRemoteContentSummary, Never>?
    private var activeKey: String?

    /// `downloadContent` : déduplique une synchronisation identique en vol.
    func download(
        order: [OfflContentBundleId] = [],
        ids: [OfflContentBundleId]? = nil,
        concurrency: Int = 1,
        baseUrl: String = OfflDownloadConfig.contentPathPrefix
    ) async -> OfflRemoteContentSummary {
        let key = keyFor(order: order, ids: ids, concurrency: concurrency, baseUrl: baseUrl)
        lock.lock()
        if let activeTask, activeKey == key {
            lock.unlock()
            return await activeTask.value
        }
        let previous = activeTask
        lock.unlock()
        if let previous { _ = await previous.value }

        let task = Task { await self.run(order: order, ids: ids, concurrency: concurrency, baseUrl: baseUrl) }
        lock.lock()
        activeTask = task
        activeKey = key
        lock.unlock()

        let summary = await task.value
        lock.lock()
        if activeKey == key { activeTask = nil; activeKey = nil }
        lock.unlock()
        return summary
    }

    /// Exécute la synchronisation et publie les états `checking`/`downloading`/
    /// `complete`/`error` de `ContentDownloadState`.
    private func run(
        order: [OfflContentBundleId],
        ids: [OfflContentBundleId]?,
        concurrency: Int,
        baseUrl: String
    ) async -> OfflRemoteContentSummary {
        publish(OfflContentDownloadState(status: .checking, completed: 0, total: 0, downloaded: 0, rejected: 0))
        let summary = await OfflSync.refreshRemoteContent(
            baseUrl: baseUrl,
            store: .shared,
            knownDigests: OfflSync.contentDigests(),
            order: order.map { $0.rawValue },
            ids: ids,
            concurrency: concurrency,
            onProgress: { [weak self] progress in
                // Pendant le téléchargement, les compteurs `downloaded`/
                // `rejected` restent à zéro : ils sont posés au bilan final,
                // comme `contentDownloadState` le fait côté Expo.
                self?.publish(OfflContentDownloadState(
                    status: .downloading,
                    completed: progress.completed,
                    total: progress.total,
                    downloaded: 0,
                    rejected: 0
                ))
            }
        )
        publish(OfflContentDownloadState(
            status: summary.checked > 0 && summary.rejected.isEmpty ? .complete : .error,
            completed: summary.checked,
            total: summary.checked,
            downloaded: summary.downloaded.count,
            rejected: summary.rejected.count
        ))
        return summary
    }

    /// Publie un nouvel état sur le fil principal.
    private func publish(_ next: OfflContentDownloadState) {
        DispatchQueue.main.async { [weak self] in self?.state = next }
    }

    /// Clé de déduplication (`contentRefreshKey`).
    private func keyFor(
        order: [OfflContentBundleId],
        ids: [OfflContentBundleId]?,
        concurrency: Int,
        baseUrl: String
    ) -> String {
        let idsKey = ids.map { $0.map { $0.rawValue }.joined(separator: ",") } ?? "nil"
        let orderKey = order.map { $0.rawValue }.joined(separator: ",")
        return "\(baseUrl)|\(idsKey)|\(orderKey)|\(concurrency)"
    }
}
