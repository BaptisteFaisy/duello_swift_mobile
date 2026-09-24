//
//  AcctLocalRegistry+Persistence.swift
//  Duello
//
//  Port de src/utils/auth.ts (RN) — lecture, écriture et retrait des comptes du
//  registre local (`loadAccounts`, `saveAccount`, `removeUserAccount`, …).
//
//  Découpage (24/09/2026) : section extraite de `AcctLocalRegistry.swift`
//  (porté du même fichier source).
//
//  Cible : iOS 16, aucune dépendance externe.
//
import Foundation

// MARK: - Persistance

extension AcctLocalRegistry {
    /// `loadAccounts` : charge les deux registres sans jamais réécrire les
    /// utilisateurs avec l'admin ; réécrit le registre utilisateur si une
    /// migration le requiert.
    static func loadAccounts(
        storage: AcctLocalRegistryStorage = AcctUserDefaultsRegistryStorage()
    ) -> [AcctStoredAccount] {
        let usersRaw = storage.getItem(AcctLocalRegistryKeys.userAccounts)
        let adminRaw = storage.getItem(AcctLocalRegistryKeys.adminAccount)
        let legacyAccountsRaw = storage.getItem(AcctLocalRegistryKeys.legacyAccounts)
        let legacyAccountRaw = storage.getItem(AcctLocalRegistryKeys.legacyAccount)

        let legacyAccounts = parseAccountArray(legacyAccountsRaw)
            + (parseSingleAccount(legacyAccountRaw).map { [$0] } ?? [])
        let users = uniqueUsers(
            usersRaw != nil
                ? parseAccountArray(usersRaw).filter { $0.isUser }
                : legacyAccounts.filter { $0.isUser }
        )
        let storedAdmin = parseSingleAccount(adminRaw)
        let admin = (storedAdmin?.isAdmin == true ? storedAdmin : nil)
            ?? legacyAccounts.first { $0.isAdmin }

        if !users.isEmpty,
           usersRaw == nil || AcctLocalRegistryMigrations.needsRewrite(usersRaw: usersRaw) {
            storage.setItem(AcctLocalRegistryKeys.userAccounts, encode(users))
        }
        if adminRaw == nil, let admin {
            storage.setItem(AcctLocalRegistryKeys.adminAccount, encodeSingle(admin))
        }
        return users + (admin.map { [$0] } ?? [])
    }

    /// `loadAccount` : premier compte du registre, ou `nil`.
    static func loadAccount(
        storage: AcctLocalRegistryStorage = AcctUserDefaultsRegistryStorage()
    ) -> AcctStoredAccount? {
        loadAccounts(storage: storage).first
    }

    /// `saveAccount` : admin et utilisateurs vivent dans deux registres ; une
    /// mise à jour admin ne réécrit jamais la liste élève.
    static func saveAccount(
        _ account: AcctStoredAccount,
        storage: AcctLocalRegistryStorage = AcctUserDefaultsRegistryStorage()
    ) {
        guard let normalized = normalizeStoredAccount(account) else { return }
        if normalized.isAdmin {
            storage.setItem(AcctLocalRegistryKeys.adminAccount, encodeSingle(normalized))
            return
        }
        let users = loadAccounts(storage: storage).filter { $0.isUser }
        let updated = [normalized] + users.filter { $0.id != normalized.id }
        storage.setItem(AcctLocalRegistryKeys.userAccounts, encode(updated))
    }

    /// `removeUserAccount` : retire seulement l'inscription locale ; les
    /// données du compte restent récupérables.
    static func removeUserAccount(
        _ accountId: String,
        storage: AcctLocalRegistryStorage = AcctUserDefaultsRegistryStorage()
    ) {
        let users = loadAccounts(storage: storage).filter { $0.isUser }
        let remaining = users.filter { $0.id != accountId }
        storage.setItem(AcctLocalRegistryKeys.userAccounts, encode(remaining))
    }

    /// `findAccountByEmail` : correspondance sur l'adresse normalisée.
    static func findAccountByEmail(
        _ accounts: [AcctStoredAccount],
        email: String
    ) -> AcctStoredAccount? {
        let normalized = normalizeEmail(email)
        return accounts.first { normalizeEmail($0.email) == normalized }
    }

    /// `verifyCredentials` : adresse identique **et** empreinte concordante.
    /// Une empreinte absente ne vaut jamais acceptation.
    static func verifyCredentials(
        _ account: AcctStoredAccount,
        email: String,
        password: String
    ) -> Bool {
        guard normalizeEmail(email) == normalizeEmail(account.email),
              let stored = account.passwordHash else { return false }
        return LoginScrCredential.hashPassword(password) == stored
    }
}
