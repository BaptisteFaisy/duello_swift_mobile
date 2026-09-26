//
//  LoginScrRegistry.swift
//  Duello
//
//  V1 2026-09-26 — écart #1 du rapport `out/02-connexion.md`.
//
//  Registre local des comptes, porté de `src/utils/auth.ts` : `StoredAccount`,
//  `AdminAccount` / `UserAccount`, `createInitialAdminAccount`, `loadAccounts`,
//  `saveAccount`. (`findAccountByEmail` vit déjà dans `LoginScrAccountBook.find`.)
//
//  Il alimente `LoginScrProps.accounts` / `account` / `persistAccount`
//  (`LoginIntAssembly`). Sans lui, `accounts` restait vide, donc
//  `selectedAccount` toujours nul : connexion compte connu, activation et
//  récupération administrateur, proposition biométrie et pré-remplissage
//  étaient inatteignables.
//
//  Équivalent iOS du stockage `AsyncStorage` de la source : `UserDefaults`,
//  sous les **mêmes clés** (`@prepapp/user-accounts-v3`,
//  `@prepapp/admin-account-v1`). L'administrateur et les utilisateurs restent
//  deux registres séparés (`saveAccount`) : une mise à jour admin ne réécrit
//  jamais la liste élève.
//
//  Réduction assumée : les clés d'héritage (`@prepapp/accounts-v2`,
//  `@prepapp/account-v1`) et leurs migrations (`normalizeStoredAccount`,
//  retrait d'`isPublic` / `recoveryCodeHash` élève) ne sont pas portées —
//  l'application Swift n'a jamais écrit ces formats. La lecture dédoublonne
//  néanmoins les utilisateurs par identifiant **et** par adresse, comme
//  `uniqueUsers`.
//
//  Cible : iOS 16. Aucune dépendance externe.
//

import Foundation

/// Registre local des comptes (`utils/auth.ts`).
enum LoginScrRegistry {
    /// `USER_ACCOUNTS_STORAGE_KEY`.
    static let usersKey = "@prepapp/user-accounts-v3"
    /// `ADMIN_ACCOUNT_STORAGE_KEY`.
    static let adminKey = "@prepapp/admin-account-v1"
    /// `ADMIN_ACCOUNT_DISPLAY_NAME`.
    static let adminDisplayName = "Admin Duello"
    /// `ADMIN_ACCOUNT_EMAIL` (`utils/accountIdentity.ts`) : même source que
    /// `AppleAuthAccountResolver.adminEmails`, jamais recopiée en dur.
    static var adminEmail: String { AppleAuthAccountResolver.adminEmails.first ?? "" }

    /// `createInitialAdminAccount` : compte admin neuf, jamais encore activé.
    static func initialAdminAccount() -> LoginScrAccount {
        LoginScrAccount(
            id: "admin",
            email: adminEmail,
            displayName: adminDisplayName,
            role: .admin,
            passwordHash: nil,
            googleSubject: nil,
            appleSubject: nil,
            biometricEnabled: false,
            requiresPasswordSetup: true,
            recoveryCodeHash: nil,
            isGuest: false
        )
    }

    /// `loadAccounts` : registres utilisateurs + administrateur. Un
    /// administrateur absent est créé et persisté, comme au démarrage de la
    /// source (`App.tsx:867-875`).
    static func load() -> [LoginScrAccount] {
        let users = uniqueUsers(readUsers())
        var admin = readAdmin()
        if admin == nil {
            let created = initialAdminAccount()
            writeAdmin(created)
            admin = created
        }
        return users + (admin.map { [$0] } ?? [])
    }

    /// `saveAccount` : l'administrateur et les utilisateurs sont écrits dans
    /// deux registres distincts ; une mise à jour admin ne lit ni ne réécrit
    /// jamais la liste élève.
    static func save(_ account: LoginScrAccount) {
        if account.role == .admin {
            writeAdmin(account)
            return
        }
        let others = readUsers().filter { $0.id != account.id }
        writeUsers([account] + others)
    }

    /// `preferredUserLoginAccount` (`utils/loginAccountSelection.ts`) : premier
    /// utilisateur non invité, jamais l'administrateur par défaut.
    static func preferredAccount(in accounts: [LoginScrAccount]) -> LoginScrAccount? {
        accounts.first { $0.role == .user && !$0.isGuest }
    }

    /// `userStorageId` (`utils/storageScope.ts`) : `user-` + chaque unité UTF-16
    /// de l'adresse normalisée en hexadécimal (4 chiffres). Encodage stable et
    /// injectif de la source, repris tel quel.
    static func userId(email: String) -> String {
        var encoded = ""
        for unit in LoginScrCredential.normalize(email).utf16 {
            encoded += String(format: "%04x", unit)
        }
        return "user-\(encoded)"
    }

    /// `accountFromServerRecovery` (`App.tsx:327`) sans le profil : le compte
    /// élève que le serveur vient de valider, mémorisé par la connexion d'un
    /// compte encore inconnu (`saveAccount`). `passwordHash` nul et biométrie
    /// éteinte, comme la source ; les sujets fournisseurs ne sont pas renvoyés
    /// par `POST /auth/password/login` (`DuelloAPIAccount`), ils restent nuls.
    static func recoveredAccount(email: String, displayName: String) -> LoginScrAccount {
        LoginScrAccount(
            id: userId(email: email),
            email: LoginScrCredential.normalize(email),
            displayName: displayName,
            role: .user,
            passwordHash: nil,
            googleSubject: nil,
            appleSubject: nil,
            biometricEnabled: false,
            requiresPasswordSetup: false,
            recoveryCodeHash: nil,
            isGuest: false
        )
    }

    // MARK: Stockage

    private static func readUsers() -> [LoginScrAccount] {
        decodeUsers(UserDefaults.standard.data(forKey: usersKey))
    }

    private static func readAdmin() -> LoginScrAccount? {
        guard let data = UserDefaults.standard.data(forKey: adminKey),
              let account = try? JSONDecoder().decode(LoginScrAccount.self, from: data),
              account.role == .admin else { return nil }
        return account
    }

    private static func writeUsers(_ accounts: [LoginScrAccount]) {
        if let data = try? JSONEncoder().encode(accounts) {
            UserDefaults.standard.set(data, forKey: usersKey)
        }
    }

    private static func writeAdmin(_ account: LoginScrAccount) {
        if let data = try? JSONEncoder().encode(account) {
            UserDefaults.standard.set(data, forKey: adminKey)
        }
    }

    private static func decodeUsers(_ data: Data?) -> [LoginScrAccount] {
        guard let data,
              let accounts = try? JSONDecoder().decode([LoginScrAccount].self, from: data) else {
            return []
        }
        return accounts.filter { $0.role == .user }
    }

    /// `uniqueUsers` : ni doublon d'identifiant, ni doublon d'adresse.
    private static func uniqueUsers(_ accounts: [LoginScrAccount]) -> [LoginScrAccount] {
        var seenIds = Set<String>()
        var seenEmails = Set<String>()
        return accounts.filter { account in
            let email = LoginScrCredential.normalize(account.email)
            guard !seenIds.contains(account.id), !seenEmails.contains(email) else { return false }
            seenIds.insert(account.id)
            seenEmails.insert(email)
            return true
        }
    }
}
