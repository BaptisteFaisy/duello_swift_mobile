//
//  OfflSync+Manifest.swift
//  Duello
//
//  Lecture du manifeste et vérification d'intégrité.
//
//  Fichier source Expo porté : `src/content/contentSync.ts`
//  (`manifestBundles`, `manifestChapters`, `parsedEntries`, `verifiedEntries`,
//  `verifiedEntriesCooperative`).
//
//  `parsedEntries` ne contrôle que la forme (tableau de la bonne longueur),
//  pour un cache local déjà passé par la vérification d'empreinte à l'écriture.
//  `verifiedEntries` ajoute taille et SHA-256 : tout téléchargement passe par
//  elle. La variante coopérative cède la main à la boucle d'événements, ce que
//  `Task.yield` reproduit côté natif.
//
//  Cible : iOS 16.
//
import Foundation

extension OfflSync {
    /// `manifestBundles` : descripteurs de banques valides du manifeste.
    static func manifestBundles(_ data: Data) -> [OfflContentBundleDescriptor]? {
        guard let manifest = try? JSONDecoder().decode(OfflContentManifest.self, from: data),
              manifest.version == OfflDownloadConfig.manifestVersion,
              let bundles = manifest.bundles
        else { return nil }
        return bundles.filter { bundle in
            OfflDownloadConfig.isContentBundleId(bundle.id)
                && bundle.file == "\(bundle.id).json"
                && bundle.size > 0
                && bundle.size <= OfflDownloadConfig.maxBundleBytes
                && bundle.sha256.range(of: "^[a-f0-9]{64}$", options: .regularExpression) != nil
                && bundle.count > 0
        }
    }

    /// `manifestChapters` : descripteurs de chapitres valides du manifeste.
    static func manifestChapters(_ data: Data) -> [OfflContentChapterDescriptor]? {
        guard let manifest = try? JSONDecoder().decode(OfflContentManifest.self, from: data),
              manifest.version == OfflDownloadConfig.manifestVersion,
              let chapters = manifest.chapters
        else { return nil }
        return chapters.filter { chapter in
            OfflDownloadConfig.isContentBundleId(chapter.bundleId)
                && chapter.chapterId.range(of: "^[a-z0-9-]+$", options: .regularExpression) != nil
                && chapter.file == "chapters/\(chapter.bundleId)/\(chapter.chapterId).json"
                && chapter.size > 0
                && chapter.size <= OfflDownloadConfig.maxBundleBytes
                && chapter.sha256.range(of: "^[a-f0-9]{64}$", options: .regularExpression) != nil
                && chapter.count > 0
        }
    }

    /// `parsedEntries` : tableau de la longueur annoncée, ou `nil`.
    static func parsedEntries(_ descriptor: OfflContentEntriesDescriptor, serialized: String) -> [Any]? {
        guard !serialized.isEmpty, let entries = OfflContentJSON.array(serialized) else { return nil }
        return entries.count == descriptor.count ? entries : nil
    }

    /// `verifiedEntries` : taille, empreinte et nombre d'entrées conformes.
    static func verifiedEntries(_ descriptor: OfflContentEntriesDescriptor, serialized: String) -> [Any]? {
        guard !serialized.isEmpty,
              serialized.utf8.count == descriptor.size,
              OfflContentHash.hex(serialized) == descriptor.sha256
        else { return nil }
        return parsedEntries(descriptor, serialized: serialized)
    }

    /// `verifiedEntriesCooperative` : intégrité stricte, sans retenir les appuis.
    static func verifiedEntriesCooperative(_ descriptor: OfflContentEntriesDescriptor, serialized: String) async -> [Any]? {
        await Task.yield()
        return verifiedEntries(descriptor, serialized: serialized)
    }
}
