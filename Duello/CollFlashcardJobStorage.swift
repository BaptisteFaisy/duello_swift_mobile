//
//  CollFlashcardJobStorage.swift
//  Duello
//
//  Port de src/utils/courseFlashcardsApi.ts (RN) — persistance du job de
//  génération (`jobStorageKey`), cloisonnée par compte.
//
//  Fichier source Expo porté :
//    - src/storage/AccountStorage.tsx — `getItem`/`setItem`/`removeItem`,
//      modélisés ici par le protocole `CollFlashcardJobStorage`. Le préfixe
//      physique reprend `RewStorageScope.accountStorageKey` (comme
//      `KbSupOcrSettingsStore`).
//
//  Notes datées (24/09/2026) :
//    - La clé logique vient de l'appelant (`options.jobStorageKey`) : le portage
//      ne l'invente pas, il la cloisonne par compte.
//
//  Cible : iOS 16, aucune dépendance externe.
//

import Foundation

/// Stockage du job de génération, cloisonné par compte
/// (`AccountStorage.getItem/setItem/removeItem`).
protocol CollFlashcardJobStorage {
    func getItem(_ key: String) -> String?
    func setItem(_ key: String, _ value: String)
    func removeItem(_ key: String)
}

/// Implémentation `UserDefaults` cloisonnée par compte, alignée sur
/// `AccountStorage` (préfixe `RewStorageScope.accountStorageKey`).
struct CollUserDefaultsFlashcardJobStorage: CollFlashcardJobStorage {
    let accountId: String
    var defaults: UserDefaults = .standard

    func getItem(_ key: String) -> String? {
        defaults.string(forKey: physicalKey(key))
    }

    func setItem(_ key: String, _ value: String) {
        defaults.set(value, forKey: physicalKey(key))
    }

    func removeItem(_ key: String) {
        defaults.removeObject(forKey: physicalKey(key))
    }

    /// Clé physique de la donnée de compte ; sans compte, la portée est celle
    /// des écrans d'avant-session.
    private func physicalKey(_ logicalKey: String) -> String {
        let scope = accountId.isEmpty ? RewStorageScope.onboardingAccountStorageId : accountId
        return (try? RewStorageScope.accountStorageKey(accountId: scope, logicalKey: logicalKey))
            ?? logicalKey
    }
}
