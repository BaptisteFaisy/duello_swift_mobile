//
//  RewRecentCache.swift
//  Duello
//
//  Cache LRU minimal : lecture replaçant l'entrée en fin d'ordre, écriture
//  retenant la valeur et libérant les entrées les moins récemment consultées.
//
//  Le `Map` de la source est une référence mutable partagée ; la classe
//  reflète ce partage (référence), là où un `struct` copierait l'état.
//
//  Fichier source Expo porté : src/data/recentCache.ts
//
//  Cible : iOS 16, aucune dépendance externe.
//
import Foundation

/// Cache ordonné de type LRU, répliquant les deux fonctions `recentCache.ts`
/// comme méthodes d'une même instance mutable.
final class RewRecentCache<Key: Hashable, Value> {

    /// Valeurs indexées par clé (accès O(1)).
    private var values: [Key: Value] = [:]

    /// Ordre d'insertion / de consultation : la première clé est la plus
    /// ancienne, la dernière la plus récente.
    private var order: [Key] = []

    /// Nombre d'entrées actuellement retenues.
    var count: Int { order.count }

    /// Lit une entrée en la replaçant à la fin d'un cache LRU.
    ///
    /// Renvoie `nil` si la clé est absente ; sinon retire puis réinsère la
    /// clé, de sorte qu'elle occupe la position la plus récente.
    func read(_ key: Key) -> Value? {
        guard let value = values[key] else { return nil }
        removeFromOrder(key)
        order.append(key)
        return value
    }

    /// Retient une valeur et libère les entrées les moins récemment consultées.
    ///
    /// La limite porte sur les objets dérivés ; les sources embarquées restent
    /// disponibles et peuvent être reconstruites sans perte fonctionnelle.
    /// Retire puis réinsère la clé, puis évince les plus anciennes tant que
    /// `count > limit`, et renvoie la valeur retenue.
    @discardableResult
    func write(_ key: Key, _ value: Value, limit: Int) -> Value {
        removeFromOrder(key)
        values[key] = value
        order.append(key)
        while order.count > limit {
            let oldest = order.removeFirst()
            values.removeValue(forKey: oldest)
        }
        return value
    }

    /// Retire une clé de l'ordre d'insertion, si présente.
    private func removeFromOrder(_ key: Key) {
        if let index = order.firstIndex(of: key) {
            order.remove(at: index)
        }
    }
}
