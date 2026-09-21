//
//  RewStorageScope.swift
//  Duello
//
//  Portée locale des données de compte : identifiants de stockage et clés
//  physiques cloisonnées par compte.
//
//  Fichier source Expo porté (libellés et message repris mot pour mot) :
//    - src/utils/storageScope.ts
//        `ACCOUNT_DATA_PREFIX`, `ONBOARDING_ACCOUNT_STORAGE_ID`,
//        `GUEST_EMAIL_DOMAIN`, `userStorageId`, `storedUserAccountId`,
//        `accountStorageKey`, `accountStoragePrefix`, `isAccountStorageKeyFor`.
//      (les helpers d'invité vivent dans `RewGuestIdentity.swift`)
//
//  Cible : iOS 16, aucune dépendance externe.
//
import Foundation

/// Erreur d'encodage d'une clé de stockage de compte.
enum RewStorageScopeError: Error, Equatable {
    /// `Une clé de stockage de compte ne peut pas être vide.`
    case emptyLogicalKey
}

/// `storageScope.ts` : encodage et cloisonnement des données de compte.
enum RewStorageScope {
    /// `ACCOUNT_DATA_PREFIX` : préfixe physique de toutes les données d'un compte.
    static let accountDataPrefix = "@prepapp/account-data:v1"

    /// `ONBOARDING_ACCOUNT_STORAGE_ID` : portée des écrans d'avant-session
    /// (accueil, connexion, inscription), cloisonnée au lieu de planter faute de
    /// `AccountStorageProvider`.
    static let onboardingAccountStorageId = "user-onboarding"

    /// `GUEST_EMAIL_DOMAIN` : domaine des adresses invitées.
    static let guestEmailDomain = "guest.duello.local"

    /// `userStorageId` : encodage stable et injectif d'une adresse normalisée.
    /// Chaque unité de code devient quatre chiffres hexadécimaux (les adresses
    /// e-mail tiennent dans le plan multilingue de base : équivalent à
    /// `charCodeAt` + `padStart(4, '0')`).
    static func userStorageId(_ email: String) -> String {
        let normalized = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        var encoded = ""
        for scalar in normalized.unicodeScalars {
            encoded += String(format: "%04x", scalar.value)
        }
        return "user-\(encoded)"
    }

    /// `storedUserAccountId` : la valeur persistée gagne toujours, même quand
    /// l'adresse change. Recalculer l'identifiant depuis l'e-mail couperait la
    /// liaison de session serveur et séparerait les données locales de leur
    /// compte ; il ne sert qu'aux enregistrements qui n'en ont pas encore.
    static func storedUserAccountId(_ storedId: String?, email: String) -> String {
        if let storedId, storedId.hasPrefix("user-") { return storedId }
        return userStorageId(email)
    }

    /// `accountStorageKey` : une donnée de compte ne peut être lue qu'avec
    /// l'identifiant de son propriétaire ; une clé logique vide est refusée.
    static func accountStorageKey(accountId: String, logicalKey: String) throws -> String {
        let normalizedKey = logicalKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedKey.isEmpty else { throw RewStorageScopeError.emptyLogicalKey }
        return accountStoragePrefix(accountId: accountId) + normalizedKey
    }

    /// `accountStoragePrefix` : préfixe physique commun à toutes les données
    /// appartenant à un compte.
    static func accountStoragePrefix(accountId: String) -> String {
        "\(accountDataPrefix):\(accountId):"
    }

    /// `isAccountStorageKeyFor` : la clé physique appartient-elle à ce compte ?
    static func isAccountStorageKeyFor(accountId: String, storageKey: String) -> Bool {
        storageKey.hasPrefix(accountStoragePrefix(accountId: accountId))
    }
}
