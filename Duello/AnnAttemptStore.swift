//
//  AnnAttemptStore.swift
//  Duello
//
//  Port de `src/utils/annaleAttempt.ts` — persistance :
//  `loadAnnaleAttempts`, `updateAnnaleAttempts`, `saveAnnaleAttempt`,
//  `removeAnnaleAttempt`.
//
//  Adaptations imposées : pas d'`AccountStorage` en Swift → `UserDefaults`
//  standard avec la clé logique `prepapp-annale-attempts:v1`, isolée par compte
//  via `scopedKey(base, accountId:)` (modèle `ChalProgress.swift`).
//
//  À raccorder (vague 5) : `ChalProgress.saveAttempt` (fichier gelé, vague W)
//  écrit un brouillon réduit (`ChalAttemptDraft`) sous la MÊME clé
//  `prepapp-annale-attempts:v1` (même `scopedKey`). Tant que les deux magasins
//  coexistent, la clé est partagée : les écritures de l'un peuvent masquer les
//  lectures de l'autre selon le format (String JSON ici, Data côté ChalProgress).
//
//  Cible : iOS 16, aucune API iOS 17.
//
import Foundation

/// File d'écriture sérialisée par compte (`annaleAttemptWrites`) : une file
/// commune empêche deux sauvegardes rapprochées de relire la même ancienne
/// valeur puis de s'écraser.
var annaleAttemptWrites: [String: Task<AnnAttemptMap, Never>] = [:]

enum AnnAttemptStore {
    /// Clé logique de persistance (`ACCOUNT_STORAGE_KEYS.annaleAttempts`).
    static let storageKey = "prepapp-annale-attempts:v1"

    /// Clé isolée par compte, comme le stockage de compte d'Expo.
    static func scopedKey(_ base: String, accountId: String) -> String {
        let trimmed = accountId.trimmingCharacters(in: .whitespacesAndNewlines)
        return "\(base):\(trimmed.isEmpty ? "local" : trimmed)"
    }

    /// Lit les tentatives du compte (`loadAnnaleAttempts`).
    static func loadAnnaleAttempts(accountId: String) -> AnnAttemptMap {
        let key = scopedKey(storageKey, accountId: accountId)
        guard let raw = UserDefaults.standard.string(forKey: key) else { return [:] }
        return parseAnnaleAttempts(raw: raw)
    }

    /// Rejoue la mise à jour dans la file du compte (`updateAnnaleAttempts`).
    @discardableResult
    static func updateAnnaleAttempts(
        accountId: String,
        update: (inout AnnAttemptMap) -> Void
    ) async -> AnnAttemptMap {
        let previous = annaleAttemptWrites[accountId]
        let write = Task { () -> AnnAttemptMap in
            _ = await previous?.value
            var attempts = loadAnnaleAttempts(accountId: accountId)
            update(&attempts)
            persist(attempts, accountId: accountId)
            return attempts
        }
        annaleAttemptWrites[accountId] = write
        let saved = await write.value
        if annaleAttemptWrites[accountId] == write {
            annaleAttemptWrites[accountId] = nil
        }
        return saved
    }

    /// Enregistre une tentative (`saveAnnaleAttempt`).
    static func saveAnnaleAttempt(accountId: String, attempt: AnnAttempt) async {
        var snapshot = attempt
        snapshot.answers = attempt.answers
        snapshot.reviews = attempt.reviews
        snapshot.submissionCounts = attempt.submissionCounts ?? [:]
        snapshot.metricHistory = (attempt.metricHistory ?? []).map { entry in
            var copy = entry
            copy.submissionCounts = entry.submissionCounts
            return copy
        }
        snapshot.updatedAt = annNowISOString()
        await updateAnnaleAttempts(accountId: accountId) { attempts in
            attempts[snapshot.itemId] = snapshot
        }
    }

    /// Supprime une tentative (`removeAnnaleAttempt`).
    static func removeAnnaleAttempt(accountId: String, itemId: String) async {
        await updateAnnaleAttempts(accountId: accountId) { attempts in
            attempts[itemId] = nil
        }
    }

    /// Écrit la collection sous forme de chaîne JSON dans `UserDefaults`.
    private static func persist(_ attempts: AnnAttemptMap, accountId: String) {
        guard let data = try? JSONEncoder().encode(attempts),
              let raw = String(data: data, encoding: .utf8)
        else { return }
        UserDefaults.standard.set(raw, forKey: scopedKey(storageKey, accountId: accountId))
    }
}
