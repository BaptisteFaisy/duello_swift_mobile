//
//  OfflServedBank+Raw.swift
//  Duello
//
//  Accès bruts aux banques appliquées et paires `[clé, valeur]`.
//
//  Fichier source Expo porté : `src/content/servedBank.ts` (`contentBundle` /
//  `partialContentBundle` lus comme des `unknown`, et le décodage des tables
//  servies en paires). Fichier séparé pour tenir le budget de fonctions de
//  `OfflServedBank.swift` (ratchet ≤ 10 fonctions par fichier).
//
//  Cible : iOS 16.
//
import Foundation

extension OfflServedBank {

    /// `contentBundle(id)` : tableau brut d'une banque complète appliquée, ou
    /// `nil` si elle n'est pas encore arrivée.
    static func bundleRaw(_ id: OfflContentBundleId) -> [Any]? {
        OfflSync.bundles[id].flatMap { OfflContentJSON.array($0.serialized) }
    }

    /// `partialContentBundle(id)` : entrées ciblées appliquées (vide si aucune).
    static func partialRaw(_ id: OfflContentBundleId) -> [Any] {
        OfflSync.partialBundles[id].flatMap { OfflContentJSON.array($0.serialized) } ?? []
    }

    /// Paires `[clé, valeur]` d'une table servie (`servedRecord`), ou `nil` quand
    /// la banque n'est pas arrivée.
    static func recordPairs<T>(
        _ raw: [Any]?,
        isValue: (Any) -> T?
    ) -> [String: T]? {
        guard let raw else { return nil }
        var record: [String: T] = [:]
        for entry in raw {
            guard let pair = entry as? [Any], pair.count == 2,
                  let key = pair[0] as? String, !key.isEmpty,
                  let value = isValue(pair[1]) else { continue }
            record[key] = value
        }
        return record
    }
}
