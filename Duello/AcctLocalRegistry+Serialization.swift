//
//  AcctLocalRegistry+Serialization.swift
//  Duello
//
//  Port de src/utils/auth.ts (RN) — encodage JSON du registre (`JSON.stringify`).
//
//  Découpage (24/09/2026) : section extraite de `AcctLocalRegistry.swift`
//  (porté du même fichier source).
//
//  Cible : iOS 16, aucune dépendance externe.
//
import Foundation

// MARK: - Sérialisation

extension AcctLocalRegistry {
    /// `JSON.stringify(accounts)`.
    static func encode(_ accounts: [AcctStoredAccount]) -> String {
        guard let data = try? JSONEncoder().encode(accounts) else { return "[]" }
        return String(data: data, encoding: .utf8) ?? "[]"
    }

    /// `JSON.stringify(account)` (registre admin : un objet unique).
    static func encodeSingle(_ account: AcctStoredAccount) -> String {
        guard let data = try? JSONEncoder().encode(account) else { return "{}" }
        return String(data: data, encoding: .utf8) ?? "{}"
    }
}
