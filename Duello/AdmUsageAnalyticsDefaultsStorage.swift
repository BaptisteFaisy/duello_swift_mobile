//
//  AdmUsageAnalyticsDefaultsStorage.swift
//  Duello
//
//  Adaptateur de stockage du journal d'usage local : `AdmUsageStorage` adossé à
//  `UserDefaults`, cloisonné par compte comme `AccountStorage` côté Expo.
//
//  Fichiers source Expo portés (clés et règles repris mot pour mot) :
//    - src/utils/storageScope.ts (`accountStorageKey`,
//      `ONBOARDING_ACCOUNT_STORAGE_ID`) ;
//    - src/storage/AccountStorage.tsx (`getItem` / `setItem`).
//
//  La clé physique est `RewStorageScope.accountStorageKey(accountId:logicalKey:)`
//  avec la clé logique `AdmUsageRules.storageKey` (`prepapp-usage-analytics:v1`) :
//  le cloisonnement par compte de la source est reproduit à l'identique.
//
//  Note (limite assumée, 24/09/2026) : la source écrit dans `AccountStorage`
//  (donc synchronisé avec le serveur) ; ici le journal reste local
//  (`UserDefaults`). Le chemin d'envoi au serveur est hors périmètre de ce lot
//  (à câbler avec la synchronisation de compte).
//
//  Cible : iOS 16. Aucune dépendance externe.
//
import Foundation

/// `AdmUsageStorage` sur `UserDefaults`, cloisonné par compte.
struct AdmUsageAnalyticsDefaultsStorage: AdmUsageStorage {
    /// Identifiant de compte local (`ConsentPremiumGate.accountId(email:)`, ou
    /// la portée d'avant-session hors connexion).
    let accountId: String
    var defaults: UserDefaults = .standard

    func getItem(_ key: String) async -> String? {
        defaults.string(forKey: physicalKey(key))
    }

    func setItem(_ key: String, _ value: String) async {
        defaults.set(value, forKey: physicalKey(key))
    }

    /// Clé physique de la donnée de compte ; sans compte, la portée est celle
    /// des écrans d'avant-session.
    private func physicalKey(_ logicalKey: String) -> String {
        let scope = accountId.isEmpty ? RewStorageScope.onboardingAccountStorageId : accountId
        return (try? RewStorageScope.accountStorageKey(accountId: scope, logicalKey: logicalKey))
            ?? logicalKey
    }
}

// MARK: - Écriture depuis un écran

/// Journalise une action d'usage (`recordUsageAction`) depuis un écran.
///
/// Construit le journal du compte du porteur de l'adresse, écrit l'action, puis
/// laisse l'adaptateur persister la copie durable. Un journal par appel suffit :
/// `AdmUsageAnalyticsStore` relit la copie persistée avant chaque mutation.
@MainActor
enum AdmUsageAnalyticsRecorder {
    /// Compte le passage à l'action `action` pour le compte de `email` (session),
    /// ou pour la portée d'avant-session si l'adresse est vide.
    static func recordAction(_ action: AdmUsageActionKind, email: String) async {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let accountId = trimmed.isEmpty
            ? RewStorageScope.onboardingAccountStorageId
            : ConsentPremiumGate.accountId(email: trimmed)
        let store = AdmUsageAnalyticsStore(
            storage: AdmUsageAnalyticsDefaultsStorage(accountId: accountId)
        )
        _ = await store.recordUsageAction(action: action)
    }
}
