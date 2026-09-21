//
//  OfflSync+Remote.swift
//  Duello
//
//  Adoption du cache local et synchronisation distante des banques.
//
//  Fichier source Expo porté : `src/content/contentSync.ts`
//  (`adoptCachedContent`, `incompleteRemoteContentDownload`,
//  `retryRemoteContentDownload`, `orderedBundles`, `refreshRemoteContent`,
//  `nextCacheBusterSuffix`) et `src/content/contentDownloadCoordinator.ts`.
//
//  Deux temps séparés : au démarrage `adoptCachedContent` relit le cache sans
//  réseau ; en tâche de fond `refreshRemoteContent` compare les empreintes,
//  télécharge ce qui a changé, vérifie et écrit pour le lancement suivant. Une
//  relance passe par une URL inédite (semeur unique) pour traverser les caches
//  intermédiaires servis périmés.
//
//  Le parallélisme borne la mémoire par vagues successives (comme
//  `AnnCopyService.uploadPages`), sans index partagé entre tâches.
//
//  Cible : iOS 16.
//
import Foundation

extension OfflSync {
    /// `adoptCachedContent` : applique les banques déjà sur l'appareil.
    static func adoptCachedContent(store: OfflContentStore, ids: [OfflContentBundleId]) async -> [OfflContentBundleId] {
        var adopted: [OfflContentBundleId] = []
        for id in ids {
            guard let entry = store.readBundle(id),
                  parsedEntries(entry.descriptor, serialized: entry.serialized) != nil
            else { continue }
            applyBundle(id, digest: entry.descriptor.sha256, serialized: entry.serialized)
            adopted.append(id)
        }
        for id in ids {
            guard let entry = store.readPartial(id),
                  OfflContentHash.hex(entry.serialized) == entry.digest,
                  let entries = OfflContentJSON.array(entry.serialized), !entries.isEmpty
            else { continue }
            applyPartialBundle(id, digest: entry.digest, serialized: entry.serialized)
        }
        return adopted
    }

    /// `incompleteRemoteContentDownload` : la synchronisation doit-elle être rejouée ?
    static func incompleteRemoteContentDownload(_ summary: OfflRemoteContentSummary, ids: [OfflContentBundleId]?) -> Bool {
        if summary.checked == 0 || !summary.rejected.isEmpty { return true }
        if let ids { return summary.checked != ids.count }
        return false
    }

    /// `retryRemoteContentDownload` : rejoue une synchronisation incomplète.
    static func retryRemoteContentDownload(
        download: () async throws -> OfflRemoteContentSummary,
        ids: [OfflContentBundleId]?,
        retryDelays: [Int]
    ) async -> OfflRemoteContentSummary {
        var last = OfflRemoteContentSummary.empty
        for attempt in 0...retryDelays.count {
            if let summary = try? await download() {
                last = summary
                if !incompleteRemoteContentDownload(summary, ids: ids) { return summary }
            }
            if attempt < retryDelays.count {
                try? await Task.sleep(nanoseconds: UInt64(retryDelays[attempt]) * 1_000_000)
            }
        }
        return last
    }

    /// `orderedBundles` : tri stable selon la priorité du profil.
    static func orderedBundles(_ bundles: [OfflContentBundleDescriptor], order: [String]) -> [OfflContentBundleDescriptor] {
        var rank: [String: Int] = [:]
        for (index, id) in order.enumerated() { rank[id] = index }
        return bundles.enumerated().sorted { left, right in
            let leftRank = rank[left.element.id] ?? Int.max
            let rightRank = rank[right.element.id] ?? Int.max
            return leftRank == rightRank ? left.offset < right.offset : leftRank < rightRank
        }.map { $0.element }
    }

    /// `refreshRemoteContent` : télécharge les banques modifiées par vagues.
    static func refreshRemoteContent(
        baseUrl: String,
        store: OfflContentStore,
        knownDigests: [String: String] = OfflSync.contentDigests(),
        order: [String] = [],
        ids: [OfflContentBundleId]? = nil,
        concurrency: Int = 1,
        onProgress: ((OfflRemoteContentProgress) -> Void)? = nil
    ) async -> OfflRemoteContentSummary {
        guard let data = try? await DuelloAPI.request("\(baseUrl)/manifest.json"),
              let all = manifestBundles(data)
        else { return .empty }

        let wanted = ids.map { Set($0.map { $0.rawValue }) }
        let selected = wanted.map { set in all.filter { set.contains($0.id) } } ?? all
        var summary = OfflRemoteContentSummary(checked: selected.count, downloaded: [], rejected: [])
        onProgress?(OfflRemoteContentProgress(completed: 0, total: selected.count, currentId: nil))

        let queue = orderedBundles(selected, order: order)
        let workers = max(1, min(max(1, concurrency), max(1, queue.count)))
        var completed = 0
        var index = 0
        while index < queue.count {
            let end = min(index + workers, queue.count)
            let wave = Array(queue[index..<end])
            let outcomes = await withTaskGroup(of: (String, OfflBundleOutcome).self) { group in
                for descriptor in wave {
                    group.addTask { await downloadOne(descriptor, baseUrl: baseUrl, store: store, knownDigests: knownDigests) }
                }
                var collected: [(String, OfflBundleOutcome)] = []
                for await outcome in group { collected.append(outcome) }
                return collected
            }
            for (rawId, outcome) in outcomes {
                guard let id = OfflContentBundleId(rawValue: rawId) else { continue }
                switch outcome {
                case .downloaded: summary.downloaded.append(id)
                case .rejected: summary.rejected.append(id)
                case .known: break
                }
                completed += 1
                onProgress?(OfflRemoteContentProgress(completed: completed, total: selected.count, currentId: id))
            }
            index = end
        }
        return summary
    }

    /// Télécharge et vérifie une banque, puis l'applique et la met en cache.
    private static func downloadOne(
        _ descriptor: OfflContentBundleDescriptor,
        baseUrl: String,
        store: OfflContentStore,
        knownDigests: [String: String]
    ) async -> (String, OfflBundleOutcome) {
        if knownDigests[descriptor.id] == descriptor.sha256 {
            return (descriptor.id, .known)
        }
        guard let data = try? await DuelloAPI.request("\(baseUrl)/\(descriptor.file)") else {
            return (descriptor.id, .rejected)
        }
        let serialized = String(decoding: data, as: UTF8.self)
        guard await verifiedEntriesCooperative(descriptor, serialized: serialized) != nil else {
            return (descriptor.id, .rejected)
        }
        if let id = OfflContentBundleId(rawValue: descriptor.id) {
            applyBundle(id, digest: descriptor.sha256, serialized: serialized)
            _ = store.writeBundle(id, OfflContentCacheEntry(descriptor: descriptor, serialized: serialized))
        }
        return (descriptor.id, .downloaded)
    }

    /// `nextCacheBusterSuffix` : suffixe de requête inédit (jamais mémorisé).
    static func nextCacheBusterSuffix() -> String {
        uniqueCacheBuster += 1
        return "duello-cache=\(uniqueCacheBuster)"
    }

    /// Convertit un suffixe `nom=valeur` en éléments de requête.
    static func cacheQuery(_ suffix: String) -> [URLQueryItem] {
        guard !suffix.isEmpty, let separator = suffix.firstIndex(of: "=") else { return [] }
        let name = String(suffix[..<separator])
        let value = String(suffix[suffix.index(after: separator)...])
        return [URLQueryItem(name: name, value: value)]
    }
}
