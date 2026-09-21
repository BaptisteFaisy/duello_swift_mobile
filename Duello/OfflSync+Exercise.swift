//
//  OfflSync+Exercise.swift
//  Duello
//
//  Téléchargement ciblé d'un exercice et de son corrigé unitaire.
//
//  Fichier source Expo porté : `src/content/contentSync.ts`
//  (`exerciseEntryMatches`, `parsedExerciseSolution`,
//  `refreshRemoteExerciseSolution`, `refreshRemoteExerciseOnce`,
//  `refreshRemoteExercise`, `cachedChapterEntries`).
//
//  Le format public reste au niveau de la banque (ou du chapitre) tandis que le
//  cache local ne conserve que l'exercice demandé et ses éventuels corrigés :
//  le choix « cet exo » est respecté sans changer le serveur.
//
//  Cible : iOS 16.
//
import Foundation

extension OfflSync {
    /// `exerciseEntryMatches` : l'entrée désigne-t-elle cet exercice ?
    static func exerciseEntryMatches(_ entry: Any, itemId: String) -> Bool {
        let exerciseKey = itemId.components(separatedBy: "::").last ?? itemId
        if let array = entry as? [Any], let first = array.first as? String {
            return first == itemId || first == exerciseKey
        }
        guard let object = entry as? [String: Any] else { return false }
        if object["id"] as? String == itemId { return true }
        guard let chapterId = object["chapterId"] as? String,
              let key = object["key"] as? String
        else { return false }
        return "\(chapterId)::exercice::\(key)" == itemId || "\(chapterId)::colle::\(key)" == itemId
    }

    /// `parsedExerciseSolution` : charge utile cohérente, ou `nil`.
    static func parsedExerciseSolution(_ serialized: String, itemId: String) -> OfflExerciseSolutionPayload? {
        guard let payload = try? JSONDecoder().decode(OfflExerciseSolutionPayload.self, from: Data(serialized.utf8)),
              payload.version == 1,
              payload.itemId == itemId,
              payload.sha256 == OfflContentHash.hex(payload.solution ?? "")
        else { return nil }
        return payload
    }

    /// Chapitre déjà présent sur l'appareil, relu sans réseau.
    static func cachedChapterEntries(store: OfflContentStore, request: OfflContentChapterRequest) -> [Any]? {
        guard let cached = store.readChapter(request) else { return nil }
        return parsedEntries(cached.descriptor, serialized: cached.serialized)
    }

    /// `refreshRemoteExerciseSolution` : corrigé du seul exercice ouvert.
    static func refreshRemoteExerciseSolution(baseUrl: String, store: OfflContentStore, itemId: String) async -> Bool {
        if hasExerciseSolutionResult(itemId) { return true }
        if let cached = store.readSolution(itemId),
           let payload = parsedExerciseSolution(cached, itemId: itemId) {
            applyExerciseSolution(itemId, solution: payload.solution)
            return true
        }
        guard let data = try? await DuelloAPI.request("\(baseUrl)/solutions/\(OfflContentHash.hex(itemId)).json"),
              let payload = parsedExerciseSolution(String(decoding: data, as: UTF8.self), itemId: itemId)
        else { return false }
        applyExerciseSolution(itemId, solution: payload.solution)
        _ = store.writeSolution(itemId, String(decoding: data, as: UTF8.self))
        return true
    }

    /// `refreshRemoteExerciseOnce` : ne retient que l'exercice demandé.
    static func refreshRemoteExerciseOnce(
        baseUrl: String,
        store: OfflContentStore,
        bundleIds: [OfflContentBundleId],
        itemId: String,
        urlSuffix: String = ""
    ) async -> OfflExerciseDownloadResult {
        var result = OfflExerciseDownloadResult.empty
        guard let manifestData = try? await DuelloAPI.request("\(baseUrl)/manifest.json", query: cacheQuery(urlSuffix)),
              let bundles = manifestBundles(manifestData)
        else { return result }

        for (position, id) in bundleIds.enumerated() {
            guard let descriptor = bundles.first(where: { $0.id == id.rawValue }) else {
                result.rejected.append(id)
                continue
            }
            do {
                let data = try await DuelloAPI.request("\(baseUrl)/\(descriptor.file)", query: cacheQuery(urlSuffix))
                let serialized = String(decoding: data, as: UTF8.self)
                guard let entries = await verifiedEntriesCooperative(descriptor, serialized: serialized) else {
                    throw OfflContentError.integrity
                }
                let selected = entries.filter { exerciseEntryMatches($0, itemId: itemId) }
                // Seule la banque principale doit impérativement retrouver l'exercice.
                if selected.isEmpty {
                    if position == 0 { throw OfflContentError.missing }
                    continue
                }
                guard let partialSerialized = OfflContentJSON.string(selected) else {
                    throw OfflContentError.integrity
                }
                let partialDigest = OfflContentHash.hex(partialSerialized)
                applyPartialBundle(id, digest: partialDigest, serialized: partialSerialized)
                result.downloaded.append(id)
                _ = store.writePartial(id, OfflPartialContentCacheEntry(
                    sourceDigest: descriptor.sha256, digest: partialDigest, serialized: partialSerialized
                ))
            } catch {
                result.rejected.append(id)
            }
        }
        return result
    }

    /// `refreshRemoteExercise` : une seule relance par URL inédite en cas d'échec.
    static func refreshRemoteExercise(
        baseUrl: String,
        store: OfflContentStore,
        bundleIds: [OfflContentBundleId],
        itemId: String
    ) async -> OfflExerciseDownloadResult {
        let first = await refreshRemoteExerciseOnce(baseUrl: baseUrl, store: store, bundleIds: bundleIds, itemId: itemId)
        if !first.downloaded.isEmpty { return first }
        return await refreshRemoteExerciseOnce(
            baseUrl: baseUrl, store: store, bundleIds: bundleIds, itemId: itemId, urlSuffix: nextCacheBusterSuffix()
        )
    }
}
