//
//  OfflSync+Chapters.swift
//  Duello
//
//  Téléchargement et préchargement des chapitres.
//
//  Fichier source Expo porté : `src/content/contentSync.ts`
//  (`refreshRemoteChapterExerciseOnce`, `refreshRemoteChapterExercise`,
//  `refreshRemoteChapters`, `prefetchRemoteChapterRequests`,
//  `prefetchRemoteChapters`).
//
//  Le découpage public reste au niveau du chapitre ; le cache local ne retient
//  que l'exercice touché. Un fichier de chapitre absent ou tronqué retombe sur
//  la banque annuelle vérifiée (filet de sécurité), tandis que le
//  préchargement écrit les fichiers sans publier de révision (aucun rendu).
//
//  Cible : iOS 16.
//
import Foundation

extension OfflSync {
    /// `refreshRemoteChapterExerciseOnce` : applique le seul exercice touché.
    static func refreshRemoteChapterExerciseOnce(
        baseUrl: String,
        store: OfflContentStore,
        request: OfflContentChapterRequest,
        itemId: String,
        urlSuffix: String = ""
    ) async -> OfflChapterDownloadResult {
        var result = OfflChapterDownloadResult.empty

        if let cachedEntries = cachedChapterEntries(store: store, request: request) {
            let selected = cachedEntries.filter { exerciseEntryMatches($0, itemId: itemId) }
            if !selected.isEmpty, let serialized = OfflContentJSON.string(selected) {
                applyPartialBundle(request.bundleId, digest: OfflContentHash.hex(serialized), serialized: serialized)
                result.downloaded.append(request)
                return result
            }
        }

        guard let manifestData = try? await DuelloAPI.request("\(baseUrl)/manifest.json", query: cacheQuery(urlSuffix)),
              let descriptors = manifestChapters(manifestData),
              let descriptor = descriptors.first(where: {
                  $0.bundleId == request.bundleId.rawValue && $0.chapterId == request.chapterId
              })
        else {
            return await fallbackExercise(baseUrl: baseUrl, store: store, request: request, itemId: itemId, urlSuffix: urlSuffix)
        }

        if await applyChapterExercise(descriptor, baseUrl: baseUrl, store: store, request: request, itemId: itemId, urlSuffix: urlSuffix) {
            result.downloaded.append(request)
            return result
        }
        return await fallbackExercise(baseUrl: baseUrl, store: store, request: request, itemId: itemId, urlSuffix: urlSuffix)
    }

    /// Vérifie le fichier de chapitre et applique l'exercice touché.
    private static func applyChapterExercise(
        _ descriptor: OfflContentChapterDescriptor,
        baseUrl: String,
        store: OfflContentStore,
        request: OfflContentChapterRequest,
        itemId: String,
        urlSuffix: String
    ) async -> Bool {
        var entries: [Any]?
        if let cached = store.readChapter(request), cached.descriptor.sha256 == descriptor.sha256 {
            entries = parsedEntries(descriptor, serialized: cached.serialized)
        }
        if entries == nil {
            guard let data = try? await DuelloAPI.request("\(baseUrl)/\(descriptor.file)", query: cacheQuery(urlSuffix)) else {
                return false
            }
            entries = await verifiedEntriesCooperative(descriptor, serialized: String(decoding: data, as: UTF8.self))
        }
        guard let entries else { return false }
        let selected = entries.filter { exerciseEntryMatches($0, itemId: itemId) }
        guard !selected.isEmpty, let serialized = OfflContentJSON.string(selected) else { return false }
        let digest = OfflContentHash.hex(serialized)
        applyPartialBundle(request.bundleId, digest: digest, serialized: serialized)
        _ = store.writePartial(request.bundleId, OfflPartialContentCacheEntry(
            sourceDigest: descriptor.sha256, digest: digest, serialized: serialized
        ))
        return true
    }

    /// `refreshRemoteChapterExercise` : une seule relance par URL inédite.
    static func refreshRemoteChapterExercise(
        baseUrl: String,
        store: OfflContentStore,
        request: OfflContentChapterRequest,
        itemId: String
    ) async -> OfflChapterDownloadResult {
        let first = await refreshRemoteChapterExerciseOnce(baseUrl: baseUrl, store: store, request: request, itemId: itemId)
        if !first.downloaded.isEmpty { return first }
        return await refreshRemoteChapterExerciseOnce(
            baseUrl: baseUrl, store: store, request: request, itemId: itemId, urlSuffix: nextCacheBusterSuffix()
        )
    }

    /// `refreshRemoteChapters` : vrais petits fichiers, manifeste lu une fois.
    static func refreshRemoteChapters(
        baseUrl: String,
        store: OfflContentStore,
        requests: [OfflContentChapterRequest]
    ) async -> OfflChapterDownloadResult {
        var result = OfflChapterDownloadResult.empty
        guard let manifestData = try? await DuelloAPI.request("\(baseUrl)/manifest.json"),
              let descriptors = manifestChapters(manifestData)
        else { return result }

        for request in requests {
            guard let descriptor = descriptors.first(where: {
                $0.bundleId == request.bundleId.rawValue && $0.chapterId == request.chapterId
            }) else {
                result.rejected.append(request)
                continue
            }
            if let cached = store.readChapter(request), cached.descriptor.sha256 == descriptor.sha256,
               parsedEntries(descriptor, serialized: cached.serialized) != nil {
                applyPartialBundle(request.bundleId, digest: descriptor.sha256, serialized: cached.serialized)
                result.downloaded.append(request)
                continue
            }
            do {
                let data = try await DuelloAPI.request("\(baseUrl)/\(descriptor.file)")
                let serialized = String(decoding: data, as: UTF8.self)
                guard await verifiedEntriesCooperative(descriptor, serialized: serialized) != nil else {
                    throw OfflContentError.integrity
                }
                applyPartialBundle(request.bundleId, digest: descriptor.sha256, serialized: serialized)
                _ = store.writeChapter(request, OfflChapterContentCacheEntry(descriptor: descriptor, serialized: serialized))
                result.downloaded.append(request)
            } catch {
                result.rejected.append(request)
            }
        }
        return result
    }

    /// `prefetchRemoteChapterRequests` : écrit les chapitres sans révision publiée.
    static func prefetchRemoteChapterRequests(
        baseUrl: String,
        store: OfflContentStore,
        requests: [OfflContentChapterRequest]
    ) async -> OfflChapterDownloadResult {
        guard let manifestData = try? await DuelloAPI.request("\(baseUrl)/manifest.json"),
              let descriptors = manifestChapters(manifestData),
              !requests.isEmpty
        else { return .empty }
        var result = OfflChapterDownloadResult.empty
        for request in requests {
            guard let descriptor = descriptors.first(where: {
                $0.bundleId == request.bundleId.rawValue && $0.chapterId == request.chapterId
            }) else {
                result.rejected.append(request)
                continue
            }
            if store.readChapterDescriptor(request)?.sha256 == descriptor.sha256 {
                result.downloaded.append(request)
                continue
            }
            if await prefetchOne(descriptor, baseUrl: baseUrl, store: store) {
                result.downloaded.append(request)
            } else {
                result.rejected.append(request)
            }
        }
        return result
    }

    /// `prefetchRemoteChapters` : précharge par vagues bornées, sans rendu.
    static func prefetchRemoteChapters(
        baseUrl: String,
        store: OfflContentStore,
        bundleIds: [OfflContentBundleId],
        concurrency: Int = 2
    ) async -> OfflChapterDownloadResult {
        guard let manifestData = try? await DuelloAPI.request("\(baseUrl)/manifest.json"),
              let descriptors = manifestChapters(manifestData),
              !bundleIds.isEmpty
        else { return .empty }

        let wanted = Set(bundleIds.map { $0.rawValue })
        let queue = descriptors.filter { wanted.contains($0.bundleId) }
        var result = OfflChapterDownloadResult.empty
        let workers = max(1, min(max(1, concurrency), max(1, queue.count)))
        var index = 0
        while index < queue.count {
            let end = min(index + workers, queue.count)
            let wave = Array(queue[index..<end])
            let outcomes = await withTaskGroup(of: (OfflContentChapterDescriptor, Bool).self) { group in
                for descriptor in wave {
                    group.addTask {
                        let ok = await prefetchOne(descriptor, baseUrl: baseUrl, store: store)
                        return (descriptor, ok)
                    }
                }
                var collected: [(OfflContentChapterDescriptor, Bool)] = []
                for await outcome in group { collected.append(outcome) }
                return collected
            }
            for (descriptor, ok) in outcomes {
                let request = OfflContentChapterRequest(
                    bundleId: OfflContentBundleId(rawValue: descriptor.bundleId) ?? .mpStatements,
                    chapterId: descriptor.chapterId
                )
                if ok { result.downloaded.append(request) } else { result.rejected.append(request) }
            }
            index = end
        }
        return result
    }

    /// Filet de sécurité : la banque annuelle vérifiée si le chapitre échoue.
    private static func fallbackExercise(
        baseUrl: String,
        store: OfflContentStore,
        request: OfflContentChapterRequest,
        itemId: String,
        urlSuffix: String
    ) async -> OfflChapterDownloadResult {
        var result = OfflChapterDownloadResult.empty
        let fallback = await refreshRemoteExerciseOnce(
            baseUrl: baseUrl, store: store, bundleIds: [request.bundleId], itemId: itemId, urlSuffix: urlSuffix
        )
        if fallback.downloaded.contains(request.bundleId) {
            result.downloaded.append(request)
        } else {
            result.rejected.append(request)
        }
        return result
    }

    /// Télécharge et écrit un chapitre si son empreinte a changé.
    private static func prefetchOne(_ descriptor: OfflContentChapterDescriptor, baseUrl: String, store: OfflContentStore) async -> Bool {
        if let id = OfflContentBundleId(rawValue: descriptor.bundleId) {
            let request = OfflContentChapterRequest(bundleId: id, chapterId: descriptor.chapterId)
            if store.readChapterDescriptor(request)?.sha256 == descriptor.sha256 { return true }
        }
        guard let data = try? await DuelloAPI.request("\(baseUrl)/\(descriptor.file)") else { return false }
        let serialized = String(decoding: data, as: UTF8.self)
        guard await verifiedEntriesCooperative(descriptor, serialized: serialized) != nil,
              let id = OfflContentBundleId(rawValue: descriptor.bundleId)
        else { return false }
        let request = OfflContentChapterRequest(bundleId: id, chapterId: descriptor.chapterId)
        return store.writeChapter(request, OfflChapterContentCacheEntry(descriptor: descriptor, serialized: serialized))
    }
}
