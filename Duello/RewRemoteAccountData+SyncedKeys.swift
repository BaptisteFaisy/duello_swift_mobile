//
//  RewRemoteAccountData+SyncedKeys.swift
//  Duello
//
//  Port de src/storage/keys.ts (RN) — `isServerSyncedAccountKey` : quelles clés
//  logiques sont réellement synchronisées côté serveur.
//
//  Découpage (24/09/2026) : section extraite de `RewRemoteAccountData.swift`
//  (porté du même fichier source).
//
//  Cible : iOS 16, aucune dépendance externe.
//
import Foundation

// MARK: - Politique des clés synchronisées

/// `keys.ts` : quelles clés logiques sont réellement synchronisées côté serveur.
enum RewServerSyncedKeys {
    /// `SERVER_SYNCED_EXACT_KEYS` (valeurs de `ACCOUNT_STORAGE_KEYS`).
    static let exact: Set<String> = [
        "prepapp-class-schedule",
        "prepapp-program-tasks",
        "prepapp-grades",
        "prepapp-social-state",
        "prepapp-xp-activity",
        "prepapp-subject-elo:v1",
        "prepapp-subject-elo-history:v1",
        "prepapp-annale-attempts:v1",
        "prepapp-correction-grade-history:v1",
        "prepapp-exercise-progress",
        "prepapp-notifications",
        "prepapp-maths-program-placement:v1",
        "prepapp-ecg-option-change-count:v1",
        "prepapp-hec-journey-timeline:v1",
        "prepapp-hec-journey-timeline-year-migration:v1",
        "prepapp-hec-journey-admission:v1",
        "prepapp-training-time:v1",
        "prepapp-subject-xp:v1",
    ]

    /// `SERVER_SYNCED_PREFIXES` (valeurs de `ACCOUNT_STORAGE_PREFIXES`).
    static let prefixes: [String] = [
        "prepapp-subjects:",
        "prepapp-hec-journey-timeline:v2:",
        "prepapp-chapter-notebook:v1:",
        "prepapp-colle-completion:v1:",
    ]

    /// `isServerSyncedAccountKey` : données durables restaurées sur les
    /// appareils authentifiés du même compte.
    static func isServerSyncedAccountKey(_ logicalKey: String) -> Bool {
        exact.contains(logicalKey) || prefixes.contains { logicalKey.hasPrefix($0) }
    }
}
