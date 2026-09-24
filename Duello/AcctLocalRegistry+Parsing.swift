//
//  AcctLocalRegistry+Parsing.swift
//  Duello
//
//  Port de src/utils/auth.ts (RN) — analyse du registre local :
//  `parseAccountArray`, `parseSingleAccount`, `uniqueUsers`.
//
//  Découpage (24/09/2026) : section extraite de `AcctLocalRegistry.swift`
//  (porté du même fichier source).
//
//  Cible : iOS 16, aucune dépendance externe.
//
import Foundation

// MARK: - Analyse du registre

extension AcctLocalRegistry {
    /// `parseAccountArray` : tableau JSON → comptes normalisés (les entrées
    /// inexploitables sont ignorées).
    static func parseAccountArray(_ raw: String?) -> [AcctStoredAccount] {
        guard let entries = AcctLocalRegistryJSON.array(raw) else { return [] }
        return entries.compactMap { normalizeStoredAccount($0) }
    }

    /// `parseSingleAccount` : objet JSON unique → compte normalisé, ou `nil`.
    static func parseSingleAccount(_ raw: String?) -> AcctStoredAccount? {
        guard let object = AcctLocalRegistryJSON.object(raw) else { return nil }
        return normalizeStoredAccount(object)
    }

    /// `uniqueUsers` : retire les doublons de `id` **et** d'e-mail (un doublon
    /// d'e-mail hérité n'a jamais été valide — l'index unique `lower(email)` du
    /// serveur l'interdit).
    static func uniqueUsers(_ accounts: [AcctStoredAccount]) -> [AcctStoredAccount] {
        var seenIds = Set<String>()
        var seenEmails = Set<String>()
        return accounts.filter { account in
            if seenIds.contains(account.id) { return false }
            let emailKey = normalizeEmail(account.email)
            if seenEmails.contains(emailKey) { return false }
            seenIds.insert(account.id)
            seenEmails.insert(emailKey)
            return true
        }
    }
}
