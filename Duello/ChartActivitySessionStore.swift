//
//  ChartActivitySessionStore.swift
//  Duello
//
//  Sessions d'entraînement relues du journal d'activité local.
//
//  Fichier source Expo porté (libellés repris mot pour mot) :
//    - src/utils/activity.ts (`loadActivity` → `activity.sessions`) ;
//    - src/types.ts (`ActivitySession` : `at`, `subject`, `minutes`).
//
//  La source relit les sessions via `AccountStorage` ; ici le journal vit dans
//  les préférences standard, sous la clé `prepapp-xp-activity`
//  (`RewStorageKeys.activity`), comme les autres journaux locaux.
//
//  Limite documentée : aucun producteur local n'ajoute de session ; le journal
//  peut venir d'une synchronisation distante (`RewRemoteAccountData+SyncedKeys`).
//  Une absence de sessions rend une liste vide, jamais une erreur.
//
//  Cible : iOS 16, aucune dépendance externe.
//
import Foundation

/// `activity.sessions` du journal d'activité local, réduites au temps travaillé
/// (`ChartActivitySession` de `ChartTimeSeries.swift`).
enum ChartActivitySessionStore {

    /// Clé logique de `ACCOUNT_STORAGE_KEYS.activity` (`RewStorageKeys.activity`).
    static let storageKey = "prepapp-xp-activity"

    /// Forme brute : seule la part « temps travaillé » est consommée.
    private struct RawSession: Decodable {
        var subject: String?
        var minutes: Double?
        var at: Double?
    }

    /// Journal réduit aux sessions (`loadActivity` de `utils/activity.ts`).
    private struct RawActivity: Decodable {
        var sessions: [RawSession]?
    }

    /// Sessions terminées, relues du journal persisté. Une entrée illisible est
    /// écartée seule ; un stockage absent rend une liste vide.
    static func load() -> [ChartActivitySession] {
        guard let raw = UserDefaults.standard.string(forKey: storageKey),
              let data = raw.data(using: .utf8),
              let activity = try? JSONDecoder().decode(RawActivity.self, from: data)
        else { return [] }
        return (activity.sessions ?? []).compactMap { session in
            guard let subject = session.subject,
                  let minutes = session.minutes, minutes > 0,
                  let at = session.at, at > 0
            else { return nil }
            return ChartActivitySession(at: at, subject: subject, minutes: minutes)
        }
    }
}
