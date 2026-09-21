//
//  OfflPrefetchStorage.swift
//  Duello
//
//  Stockage concret de la file reprenable du préchargement.
//
//  Fichier source Expo porté : `src/content/resumableExercisePrefetch.ts`
//  (`ExercisePrefetchStorage` adossé à `AsyncStorage` côté Expo). Côté natif,
//  l'intention tient dans `UserDefaults`, comme les autres préférences de
//  l'application (`PlanStorage`, `HecJourneyStore`…).
//
//  Cible : iOS 16.
//
import Foundation

/// Stockage des préférences (`UserDefaults`) pour la file de préchargement.
final class OfflUserDefaultsPrefetchStorage: OfflExercisePrefetchStorage {
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
