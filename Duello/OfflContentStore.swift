//
//  OfflContentStore.swift
//  Duello
//
//  Cache disque des banques de sujets.
//
//  Fichier source Expo porté : `src/content/contentCache.ts` (implémentation
//  native `nativeContentCache` : lecture/écriture des banques, des sélections
//  ciblées, des chapitres et des corrigés unitaires).
//
//  Persistance documentée — dossier `Documents/duello-content` :
//   - `<id>.json` + `<id>.manifest.json` : banque complète et son descripteur ;
//   - `<id>.partial.json` + `<id>.partial.manifest.json` : sélections ciblées ;
//   - `chapters/<id>/<chapterId>.json` + `…manifest.json` : chapitres ;
//   - `solutions/<sha256(itemId)>.json` : corrigés unitaires.
//  La banque est toujours écrite **avant** son descripteur : une interruption
//  laisse un fichier orphelin, jamais un descripteur qui promet un contenu
//  absent. Le cache est indépendant des comptes (contenu identique pour tous).
//
//  Cible : iOS 16.
//
import Foundation

/// Cache disque des banques de sujets (`fileSystemContentCache`).
final class OfflContentStore {
    static let shared = OfflContentStore()

    private let root: URL

    init(directoryName: String = OfflDownloadConfig.cacheDirectoryName) {
        let base = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        root = base.appendingPathComponent(directoryName, isDirectory: true)
    }

    // MARK: Banques complètes

    func readBundle(_ id: OfflContentBundleId) -> OfflContentCacheEntry? {
        guard let metaData = try? Data(contentsOf: root.appendingPathComponent("\(id.rawValue).manifest.json")),
              let descriptor = try? JSONDecoder().decode(OfflContentBundleDescriptor.self, from: metaData),
              let serialized = try? String(contentsOf: root.appendingPathComponent("\(id.rawValue).json"), encoding: .utf8)
        else { return nil }
        return OfflContentCacheEntry(descriptor: descriptor, serialized: serialized)
    }

    func writeBundle(_ id: OfflContentBundleId, _ entry: OfflContentCacheEntry) -> Bool {
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        do {
            try Data(entry.serialized.utf8)
                .write(to: root.appendingPathComponent("\(id.rawValue).json"), options: .atomic)
            try JSONEncoder().encode(entry.descriptor)
                .write(to: root.appendingPathComponent("\(id.rawValue).manifest.json"), options: .atomic)
            return true
        } catch {
            return false
        }
    }

    // MARK: Sélections ciblées

    func readPartial(_ id: OfflContentBundleId) -> OfflPartialContentCacheEntry? {
        guard let metaData = try? Data(contentsOf: root.appendingPathComponent("\(id.rawValue).partial.manifest.json")),
              let meta = try? JSONSerialization.jsonObject(with: metaData) as? [String: Any],
              let serialized = try? String(contentsOf: root.appendingPathComponent("\(id.rawValue).partial.json"), encoding: .utf8)
        else { return nil }
        return OfflPartialContentCacheEntry(
            sourceDigest: meta["sourceDigest"] as? String ?? "",
            digest: meta["digest"] as? String ?? "",
            serialized: serialized
        )
    }

    func writePartial(_ id: OfflContentBundleId, _ entry: OfflPartialContentCacheEntry) -> Bool {
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        var merged = readPartial(id).flatMap { OfflContentJSON.array($0.serialized) } ?? []
        guard let incoming = OfflContentJSON.array(entry.serialized) else { return false }
        for item in incoming {
            let key = OfflSync.entryIdentity(item)
            if let index = merged.firstIndex(where: { OfflSync.entryIdentity($0) == key }) {
                merged[index] = item
            } else {
                merged.append(item)
            }
        }
        guard let serialized = OfflContentJSON.string(merged) else { return false }
        let meta: [String: Any] = [
            "sourceDigest": entry.sourceDigest,
            "digest": OfflContentHash.hex(serialized),
        ]
        do {
            try Data(serialized.utf8)
                .write(to: root.appendingPathComponent("\(id.rawValue).partial.json"), options: .atomic)
            try JSONSerialization.data(withJSONObject: meta)
                .write(to: root.appendingPathComponent("\(id.rawValue).partial.manifest.json"), options: .atomic)
            return true
        } catch {
            return false
        }
    }

    // MARK: Chapitres

    func readChapter(_ request: OfflContentChapterRequest) -> OfflChapterContentCacheEntry? {
        let directory = chapterDirectory(request)
        guard let descriptor = readChapterDescriptor(request),
              let serialized = try? String(contentsOf: directory.appendingPathComponent("\(request.chapterId).json"), encoding: .utf8)
        else { return nil }
        return OfflChapterContentCacheEntry(descriptor: descriptor, serialized: serialized)
    }

    func readChapterDescriptor(_ request: OfflContentChapterRequest) -> OfflContentChapterDescriptor? {
        let directory = chapterDirectory(request)
        let payload = directory.appendingPathComponent("\(request.chapterId).json")
        guard FileManager.default.fileExists(atPath: payload.path),
              let metaData = try? Data(contentsOf: directory.appendingPathComponent("\(request.chapterId).manifest.json")),
              let descriptor = try? JSONDecoder().decode(OfflContentChapterDescriptor.self, from: metaData)
        else { return nil }
        return descriptor
    }

    func writeChapter(_ request: OfflContentChapterRequest, _ entry: OfflChapterContentCacheEntry) -> Bool {
        let directory = chapterDirectory(request)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        do {
            try Data(entry.serialized.utf8)
                .write(to: directory.appendingPathComponent("\(request.chapterId).json"), options: .atomic)
            try JSONEncoder().encode(entry.descriptor)
                .write(to: directory.appendingPathComponent("\(request.chapterId).manifest.json"), options: .atomic)
            return true
        } catch {
            return false
        }
    }

    // MARK: Corrigés unitaires

    func readSolution(_ itemId: String) -> String? {
        try? String(contentsOf: solutionDirectory.appendingPathComponent("\(OfflContentHash.hex(itemId)).json"), encoding: .utf8)
    }

    func writeSolution(_ itemId: String, _ serialized: String) -> Bool {
        let directory = solutionDirectory
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        do {
            try Data(serialized.utf8)
                .write(to: directory.appendingPathComponent("\(OfflContentHash.hex(itemId)).json"), options: .atomic)
            return true
        } catch {
            return false
        }
    }

    // MARK: Chemins

    private var chaptersRoot: URL { root.appendingPathComponent("chapters", isDirectory: true) }

    private func chapterDirectory(_ request: OfflContentChapterRequest) -> URL {
        chaptersRoot.appendingPathComponent(request.bundleId.rawValue, isDirectory: true)
    }

    private var solutionDirectory: URL {
        root.appendingPathComponent("solutions", isDirectory: true)
    }
}

