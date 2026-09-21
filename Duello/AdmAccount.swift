//
//  AdmAccount.swift
//  Duello
//
//  Registre de comptes **propre à l'espace d'administration**.
//
//  Fichiers source Expo portés :
//    - src/utils/auth.ts             (`AdminAccount`, `AdminProfile`, `AccountRole`)
//    - src/utils/accountIdentity.ts  (`ADMIN_ACCOUNT_EMAIL`, `isAdminEmail`)
//    - src/storage/keys.ts           (`ACCOUNT_STORAGE_KEYS.adminApiToken`)
//    - src/admin/AdminApp.tsx        (identité affichée dans l'en-tête admin)
//
//  Invariant du projet : l'administration est une **surface produit séparée**,
//  avec un registre de comptes **distinct**. Un compte admin n'est jamais un
//  `UserProfile` : il est décrit par `AdmAccount`, qui ne porte ni profil
//  scolaire, ni progression, ni planning. Aucun écran élève n'est affiché dans
//  cet espace, et réciproquement.
//
//  Cible : iOS 16. Aucune dépendance externe.
//

import Foundation

/// `AdminProfile` de `src/utils/auth.ts` : nom et adresse affichés.
struct AdmProfile: Equatable {
    var displayName: String
    var email: String
}

/// `AdminAccount` de `src/utils/auth.ts`, réduit aux champs lus par l'espace
/// d'administration : identifiant fixe `admin`, rôle, adresse et profil.
///
/// Volontairement **sans** `UserProfile` : le registre admin ne partage ni les
/// types ni le stockage du registre utilisateur.
struct AdmAccount: Identifiable, Equatable {
    let id: String
    var email: String
    var displayName: String
    var role: String
    var profile: AdmProfile
    /// `requiresPasswordSetup` : le compte admin neuf doit définir son mot de passe.
    var requiresPasswordSetup: Bool

    /// `createInitialAdminAccount` : le rôle et l'identifiant sont fixés par le
    /// registre ; l'adresse vient de `ADMIN_ACCOUNT_EMAIL` côté Expo et n'est
    /// jamais recopiée dans le code.
    init(email: String, displayName: String, requiresPasswordSetup: Bool = true) {
        self.id = AdmAccountRegistry.adminIdentifier
        self.email = email
        self.displayName = displayName
        self.role = AdmAccountRegistry.adminRole
        self.profile = AdmProfile(displayName: displayName, email: email)
        self.requiresPasswordSetup = requiresPasswordSetup
    }
}

/// Constantes du registre admin isolé (`src/utils/auth.ts`,
/// `src/storage/keys.ts`). Aucune valeur métier n'est écrite en dur ailleurs.
enum AdmAccountRegistry {
    /// Identifiant du compte admin (`id: 'admin'`).
    static let adminIdentifier = "admin"
    /// Rôle porté par le compte admin (`role: 'admin'`).
    static let adminRole = "admin"
    /// `ADMIN_ACCOUNT_STORAGE_KEY` : clé sous laquelle l'appelant persiste le
    /// compte admin, séparée de celle des comptes utilisateurs.
    static let accountStorageKey = "@prepapp/admin-account-v1"
    /// Entrée Keychain du jeton admin : ce stockage est celui du compte admin
    /// seul, jamais celui d'un compte utilisateur.
    static let keychainService = "com.duello.ios.admin"
    static let keychainAccount = "admin-api-token-v1"

    /// Lit la clé d'accès serveur mémorisée sur l'appareil.
    static func loadApiToken() -> String {
        guard let data = Keychain.read(service: keychainService, account: keychainAccount),
              let value = String(data: data, encoding: .utf8) else { return "" }
        return value
    }

    /// Mémorise la clé d'accès serveur (ou l'efface quand elle est vide).
    static func saveApiToken(_ value: String) {
        if value.isEmpty {
            Keychain.delete(service: keychainService, account: keychainAccount)
            return
        }
        Keychain.save(Data(value.utf8), service: keychainService, account: keychainAccount)
    }
}
