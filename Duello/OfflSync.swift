//
//  OfflSync.swift
//  Duello
//
//  Registre en mémoire des banques appliquées et révision de contenu.
//
//  Fichier source Expo porté : `src/content/contentStore.ts` (registre des
//  banques, sélections partielles, corrigés, révision et abonnés).
//
//  Les banques restent embarquées : elles sont le socle hors ligne. Une banque
//  distante validée vient les recouvrir ; le registre ne conserve que des
//  banques déjà vérifiées (SHA-256 et nombre d'entrées contrôlés avant l'appel).
//  La révision change dès qu'un contenu distant est appliqué, et jamais
//  autrement — les banques dérivées s'y mémoïsent.
//
//  Cible : iOS 16.
//
import Foundation

/// Registre des banques servies et révision de contenu.
enum OfflSync {
    /// Entrée stockée : empreinte de validation et texte sérialisé.
    struct StoredBundle {
        var digest: String
        var serialized: String
    }

    static var bundles: [OfflContentBundleId: StoredBundle] = [:]
    static var partialBundles: [OfflContentBundleId: StoredBundle] = [:]
    static var exerciseSolutions: [String: String?] = [:]
    static var listeners: [UUID: () -> Void] = [:]
    static var revision = 0
    /// Semeur unique des URL de relance (`uniqueCacheBuster`).
    static var uniqueCacheBuster = Int(Date().timeIntervalSince1970)

    /// Révision courante (`contentRevision`).
    static var contentRevision: Int { revision }

    /// `subscribeToContent` : rend une fonction de désabonnement.
    static func subscribeToContent(_ listener: @escaping () -> Void) -> () -> Void {
        let id = UUID()
        listeners[id] = listener
        return { listeners[id] = nil }
    }

    /// `announce` : un abonné défaillant ne bloque pas les autres.
    static func announce() {
        let current = Array(listeners.values)
        for listener in current {
            listener()
        }
    }

    /// `applyContentBundle` : ignore une banque déjà appliquée à l'identique.
    static func applyBundle(_ id: OfflContentBundleId, digest: String, serialized: String) {
        if bundles[id]?.digest == digest { return }
        bundles[id] = StoredBundle(digest: digest, serialized: serialized)
        revision += 1
        announce()
    }

    /// `applyPartialContentBundle` : fusionne par identité sans passer pour une
    /// banque complète ; inopérant si la banque entière est déjà appliquée.
    static func applyPartialBundle(_ id: OfflContentBundleId, digest: String, serialized: String) {
        guard bundles[id] == nil else { return }
        guard let incoming = OfflContentJSON.array(serialized), !incoming.isEmpty else { return }
        if partialBundles[id]?.digest == digest { return }
        var merged = partialBundles[id].flatMap { OfflContentJSON.array($0.serialized) } ?? []
        for item in incoming {
            let key = entryIdentity(item)
            if let index = merged.firstIndex(where: { entryIdentity($0) == key }) {
                merged[index] = item
            } else {
                merged.append(item)
            }
        }
        guard let mergedSerialized = OfflContentJSON.string(merged) else { return }
        let mergedDigest = partialBundles[id].map { "\($0.digest):\(digest)" } ?? digest
        partialBundles[id] = StoredBundle(digest: mergedDigest, serialized: mergedSerialized)
        revision += 1
        announce()
    }

    /// `forgetContentBundles`.
    static func forgetBundles() {
        guard !(bundles.isEmpty && partialBundles.isEmpty && exerciseSolutions.isEmpty) else { return }
        bundles.removeAll()
        partialBundles.removeAll()
        exerciseSolutions.removeAll()
        revision += 1
        announce()
    }

    /// `contentBundle<T>` : banque complète décodée, ou `nil`.
    static func contentBundle<T: Decodable>(_ id: OfflContentBundleId, as type: T.Type = T.self) -> [T]? {
        guard let stored = bundles[id] else { return nil }
        return try? JSONDecoder().decode([T].self, from: Data(stored.serialized.utf8))
    }

    /// `partialContentBundle<T>` : entrées ciblées présentes, sinon tableau vide.
    static func partialContentBundle<T: Decodable>(_ id: OfflContentBundleId, as type: T.Type = T.self) -> [T] {
        guard let stored = partialBundles[id] else { return [] }
        return (try? JSONDecoder().decode([T].self, from: Data(stored.serialized.utf8))) ?? []
    }

    /// `contentDigests` : empreintes connues, pour ne retélécharger que le neuf.
    static func contentDigests() -> [String: String] {
        var result: [String: String] = [:]
        for (id, bundle) in bundles {
            result[id.rawValue] = bundle.digest
        }
        return result
    }

    /// Identité d'une entrée (`partialEntryKey`) : première chaîne d'un tableau,
    /// ou `chapterId::key` d'un objet.
    static func entryIdentity(_ entry: Any) -> String {
        if let array = entry as? [Any], let first = array.first as? String {
            return first
        }
        if let object = entry as? [String: Any], let key = object["key"] as? String {
            let chapterId = object["chapterId"] as? String ?? ""
            return "\(chapterId)::\(key)"
        }
        return OfflContentJSON.string(entry) ?? ""
    }
}
