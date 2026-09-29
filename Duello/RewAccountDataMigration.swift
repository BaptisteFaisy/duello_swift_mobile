//
//  RewAccountDataMigration.swift
//  Duello
//
//  Port de `src/storage/AccountStorage.tsx` (RN) — copie inter-comptes
//  (`copyAccountData`) et migration des clés héritées
//  (`migrateLegacyAccountData`).
//
//  Fichiers source Expo portés (libellés et clés repris mot pour mot) :
//    - src/storage/AccountStorage.tsx — `copyAccountData` (l. 327),
//      `migrateLegacyAccountData` (l. 425), `LEGACY_FIXED_KEYS`,
//      `MIGRATION_MARKER`, `LEGACY_MIGRATION_OWNER_KEY`, `pendingSyncKey`.
//    - src/storage/keys.ts — `ACCOUNT_STORAGE_PREFIXES.annaleDraft`,
//      `subjectProgramStorageKey` (via `RewStorageKeys`).
//
//  Seam assumé (29/09/2026) : la source écrit via `AccountStorage`, donc
//  déclenche aussi la synchronisation serveur (`writeRemoteAccountData`) et pose
//  les marqueurs `:pending-sync`. Ici la copie/migration est **locale**
//  (`UserDefaults`, clés physiques `RewStorageScope.accountStoragePrefix`) ; la
//  synchronisation distante reste portée par `RewRemoteAccountData*` au fil des
//  lectures/écritures de l'app. Le résultat observable (données du compte
//  présentes localement) est identique.
//
//  Cible : iOS 16, aucune dépendance externe.
//
import Foundation

/// `AccountStorage.tsx` : copie et migration des données de compte.
enum RewAccountDataMigration {
    /// `MIGRATION_MARKER`.
    static let migrationMarker = "__legacy-data-migrated-v1"
    /// `LEGACY_MIGRATION_OWNER_KEY`.
    static let legacyMigrationOwnerKey = "@prepapp/legacy-data-owner-v1"
    /// Suffixe des marqueurs de synchronisation (`pendingSyncKey`).
    static let pendingSyncSuffix = ":pending-sync"

    /// `LEGACY_FIXED_KEYS` : clés de l'ancienne version, sans identifiant de
    /// compte, copiées une seule fois vers le compte propriétaire de la session.
    static let legacyFixedKeys: [String] = [
        RewStorageKeys.Account.classSchedule,
        RewStorageKeys.Account.programTasks,
        RewStorageKeys.Account.grades,
        RewStorageKeys.Account.socialState,
        RewStorageKeys.Account.feedLikes,
        RewStorageKeys.Account.activity,
        RewStorageKeys.Account.subjectElo,
        RewStorageKeys.Account.annaleAttempts,
        RewStorageKeys.Account.annaleCopyCorrections,
        RewStorageKeys.Account.exerciseProgress,
        RewStorageKeys.Account.notifications,
        RewStorageKeys.Account.mathOcrSettings,
        RewStorageKeys.Account.ollamaSettings,
        RewStorageKeys.subjectProgramStorageKey(track: "MPSI", year: 1),
        RewStorageKeys.subjectProgramStorageKey(track: "MPSI", year: 2),
        RewStorageKeys.subjectProgramStorageKey(track: "ECG", year: 1),
        RewStorageKeys.subjectProgramStorageKey(track: "ECG", year: 2),
    ]

    /// Clé physique d'une clé logique de compte (`accountStorageKey`).
    static func physicalKey(accountId: String, logicalKey: String) -> String {
        (try? RewStorageScope.accountStorageKey(accountId: accountId, logicalKey: logicalKey))
            ?? logicalKey
    }

    /// `copyAccountData` : copie les données locales d'un invité vers son compte
    /// authentifié. Une valeur déjà présente sur le compte de destination reste
    /// prioritaire : relier un ancien compte ne doit jamais écraser sa
    /// progression. Retourne le nombre de données copiées.
    @discardableResult
    static func copyAccountData(
        sourceAccountId: String,
        destinationAccountId: String,
        storage: RewRawAccountStorage = RewUserDefaultsRawAccountStorage()
    ) -> Int {
        if sourceAccountId == destinationAccountId
            || RewStorageScope.isLocalOnlyDemoAccountId(sourceAccountId)
            || RewStorageScope.isLocalOnlyDemoAccountId(destinationAccountId) {
            return 0
        }

        let sourcePrefix = RewStorageScope.accountStoragePrefix(accountId: sourceAccountId)
        let sourceKeys = storage.allKeys().filter {
            $0.hasPrefix(sourcePrefix) && !$0.hasSuffix(pendingSyncSuffix)
        }

        var copied = 0
        for (physicalKey, value) in storage.multiGet(sourceKeys) {
            guard let value else { continue }
            let logicalKey = String(physicalKey.dropFirst(sourcePrefix.count))
            let destinationPhysical = self.physicalKey(
                accountId: destinationAccountId,
                logicalKey: logicalKey
            )
            if logicalKey.isEmpty || storage.getItem(destinationPhysical) != nil { continue }
            storage.setItem(destinationPhysical, value)
            copied += 1
        }
        return copied
    }

    /// `migrateLegacyAccountData` : copie une seule fois les données de l'ancienne
    /// version vers le compte qui possédait la session active. Les anciennes clés
    /// sont conservées pour rendre la migration non destructive, mais ne sont
    /// plus consultées par l'application.
    static func migrateLegacyAccountData(
        accountId: String,
        storage: RewRawAccountStorage = RewUserDefaultsRawAccountStorage()
    ) {
        if RewStorageScope.isLocalOnlyDemoAccountId(accountId) { return }

        let markerKey = physicalKey(accountId: accountId, logicalKey: migrationMarker)
        if storage.getItem(markerKey) != nil { return }

        let owner = storage.getItem(legacyMigrationOwnerKey)
        if let owner, owner != accountId { return }
        if owner == nil { storage.setItem(legacyMigrationOwnerKey, accountId) }

        for (logicalKey, legacyValue) in storage.multiGet(legacyKeys(storage: storage)) {
            guard let legacyValue else { continue }
            let target = physicalKey(accountId: accountId, logicalKey: logicalKey)
            if storage.getItem(target) != nil { continue }
            storage.setItem(target, legacyValue)
        }
        storage.setItem(markerKey, "true")
    }

    /// `LEGACY_FIXED_KEYS` + brouillons d'annale présents, sans doublon et dans
    /// l'ordre d'apparition.
    private static func legacyKeys(storage: RewRawAccountStorage) -> [String] {
        let drafts = storage.allKeys().filter {
            $0.hasPrefix(RewStorageKeys.Prefixes.annaleDraft)
        }
        var seen = Set<String>()
        var unique: [String] = []
        for key in legacyFixedKeys + drafts where seen.insert(key).inserted {
            unique.append(key)
        }
        return unique
    }
}
