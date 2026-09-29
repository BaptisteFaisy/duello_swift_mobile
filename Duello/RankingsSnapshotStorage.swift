//
//  RankingsSnapshotStorage.swift
//  Duello
//
//  Couture de stockage clé/valeur des instantanés de classement (analogue
//  d'`AsyncStorage` côté RN) et son implémentation `UserDefaults`, comme les
//  autres préférences natives (`OfflUserDefaultsPrefetchStorage`).
//
//  Fichier séparé pour tenir le budget de fonctions de
//  `RankingSnapshotCache.swift` (ratchet Hermes) : le protocole de couture et
//  le stockage concret vivent ici, le store seul reste dans
//  `RankingSnapshotCache.swift`.
//
//  Cible : iOS 16.
//
import Foundation

// MARK: - Couture de stockage

/// Stockage clé/valeur des instantanés (analogue d'`AsyncStorage`).
protocol RankingsSnapshotStorage {
    func getItem(_ key: String) async -> String?
    func setItem(_ key: String, _ value: String) async
    func removeItem(_ key: String) async
}

/// Stockage `UserDefaults`, comme les autres préférences de l'application.
final class RankingsUserDefaultsSnapshotStorage: RankingsSnapshotStorage {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func getItem(_ key: String) async -> String? {
        defaults.string(forKey: key)
    }

    func setItem(_ key: String, _ value: String) async {
        defaults.set(value, forKey: key)
    }

    func removeItem(_ key: String) async {
        defaults.removeObject(forKey: key)
    }
}
