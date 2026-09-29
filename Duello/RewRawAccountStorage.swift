//
//  RewRawAccountStorage.swift
//  Duello
//
//  `AsyncStorage` brut de `src/storage/AccountStorage.tsx` : accès aux clés
//  **physiques** (préfixées par compte). Le cloisonnement logique vit dans
//  `RewStorageScope` ; ce protocole ne fait que lire/écrire des clés déjà
//  préfixées, comme `AsyncStorage.getItem` / `multiGet` / `getAllKeys`.
//
//  Fichier source Expo porté :
//    - src/storage/AccountStorage.tsx — primitives `AsyncStorage` utilisées par
//      `removeLocalAccountData`, `copyAccountData` et `migrateLegacyAccountData`.
//
//  Cible : iOS 16, aucune dépendance externe.
//
import Foundation

/// Primitives brutes de stockage (`AsyncStorage`), sur clés physiques.
protocol RewRawAccountStorage {
    func allKeys() -> [String]
    func multiGet(_ physicalKeys: [String]) -> [(key: String, value: String?)]
    func getItem(_ physicalKey: String) -> String?
    func setItem(_ physicalKey: String, _ value: String)
}

/// Implémentation par défaut adossée à `UserDefaults` (équivalent iOS
/// d'`AsyncStorage`).
struct RewUserDefaultsRawAccountStorage: RewRawAccountStorage {
    var defaults: UserDefaults = .standard

    func allKeys() -> [String] {
        Array(defaults.dictionaryRepresentation().keys)
    }

    func multiGet(_ physicalKeys: [String]) -> [(key: String, value: String?)] {
        physicalKeys.map { ($0, defaults.string(forKey: $0)) }
    }

    func getItem(_ physicalKey: String) -> String? {
        defaults.string(forKey: physicalKey)
    }

    func setItem(_ physicalKey: String, _ value: String) {
        defaults.set(value, forKey: physicalKey)
    }
}
