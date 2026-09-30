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
    /// Banque complète ou énoncé ciblé adopté (`servedBanks`).
    static var servedBanksCount = 0
    /// Corrigé d'un exercice téléchargé (`corrections`).
    static var correctionsCount = 0
    /// Semeur unique des URL de relance (`uniqueCacheBuster`).
    static var uniqueCacheBuster = Int(Date().timeIntervalSince1970)

    /// Révision des banques servies, pour un calcul qui ne lit aucun corrigé
    /// (`servedBanksRevision`) : les annonces et les regroupements d'exercices en
    /// dépendent, les reconstruire à l'arrivée d'un corrigé jetait la liste des
    /// annales de l'année entière.
    static var servedBanksRevision: Int { servedBanksCount }

    /// Révision des banques servies et des corrigés, pour les items de chapitre
    /// (`chapterItemsRevision`).
    static var chapterItemsRevision: Int { servedBanksCount + correctionsCount }

    /// Révision de ce que les écrans doivent redessiner (`contentRevision`) :
    /// les deux compteurs réunis.
    static var contentRevision: Int { servedBanksCount + correctionsCount }

    /// Compat `applyExerciseSolution` (`OfflSync+Solutions`) : un corrigé unitaire
    /// n'incrémente que le compteur des corrigés (`noteCorrectionsChanged`), et
    /// jamais celui des banques servies.
    static var revision: Int {
        get { correctionsCount }
        set { correctionsCount = newValue }
    }

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
        servedBanksCount += 1
        announce()
    }

    /// `applyPartialContentBundle` : fusionne par identité sans passer pour une
    /// banque complète ; inopérant si la banque entière est déjà appliquée.
    static func applyPartialBundle(_ id: OfflContentBundleId, digest: String, serialized: String) {
        guard bundles[id] == nil else { return }
        guard let incoming = OfflContentJSON.array(serialized), !incoming.isEmpty else { return }
        if partialBundles[id]?.digest == digest { return }
        var merged = partialBundles[id].flatMap { OfflContentJSON.array($0.serialized) } ?? []
        // La recherche d'un emplacement parcourt les entrées avec un index
        // d'identités : le balayage linéaire qu'elle remplace recalculait
        // l'identité de chaque entrée à chaque comparaison, donc en cubique sur
        // une sélection qui s'allonge à chaque sujet ouvert.
        var positions: [String: Int] = [:]
        for (index, item) in merged.enumerated() { positions[entryIdentity(item)] = index }
        for item in incoming {
            let key = entryIdentity(item)
            if let index = positions[key] {
                merged[index] = item
            } else {
                positions[key] = merged.count
                merged.append(item)
            }
        }
        guard let mergedSerialized = OfflContentJSON.string(merged) else { return }
        // L'empreinte est celle de ce lot, non un cumul des précédents : la chaîne
        // qu'elle formait (recopiée à chaque sujet ouvert) grossissait sans borne.
        partialBundles[id] = StoredBundle(digest: digest, serialized: mergedSerialized)
        servedBanksCount += 1
        announce()
    }

    /// `forgetContentBundles`.
    static func forgetBundles() {
        guard !(bundles.isEmpty && partialBundles.isEmpty && exerciseSolutions.isEmpty) else { return }
        bundles.removeAll()
        partialBundles.removeAll()
        exerciseSolutions.removeAll()
        servedBanksCount += 1
        correctionsCount += 1
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
