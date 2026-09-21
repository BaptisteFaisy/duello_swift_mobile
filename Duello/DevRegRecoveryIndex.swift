import Foundation

// Suite de `src/utils/deviceRecovery.ts` : gestion de l'index des comptes
// connus (`storedRecoveryAccounts`, `rememberRecoveryAccount`,
// `forgetDeviceRecoveryAccount`) dans le trousseau.

extension DevRegRecovery {
    /// Comptes connus, relus et assainis depuis l'index
    /// (`storedRecoveryAccounts`) : entrées malformées ou dupliquées ignorées.
    static func storedAccounts() -> [DevRegRecoveryAccount] {
        guard let data = DevRegKeychain.read(service: keychainService, account: accountIndexKey),
              let parsed = try? JSONDecoder().decode([DevRegRecoveryAccount].self, from: data)
        else { return [] }
        var entries: [DevRegRecoveryAccount] = []
        for value in parsed {
            guard isValidAccountId(value.accountId) else { continue }
            let email = normalizeEmail(value.email)
            guard isValidEmail(email) else { continue }
            guard !entries.contains(where: { $0.accountId == value.accountId }) else { continue }
            entries.append(DevRegRecoveryAccount(accountId: value.accountId, email: email))
        }
        return entries
    }

    /// Mémorise (ou met à jour) un compte dans l'index
    /// (`rememberRecoveryAccount`) : le compte courant passe en tête, les
    /// doublons d'identifiant ou d'e-mail sont retirés.
    static func rememberAccount(accountId: String, email: String) {
        let normalized = normalizeEmail(email)
        let entries = storedAccounts()
        if entries.first(where: { $0.accountId == accountId })?.email == normalized { return }
        var next = [DevRegRecoveryAccount(accountId: accountId, email: normalized)]
        next.append(contentsOf: entries.filter {
            $0.accountId != accountId && $0.email != normalized
        })
        saveIndex(next)
    }

    /// Retire la preuve locale d'un compte que le serveur vient de supprimer
    /// (`forgetDeviceRecoveryAccount`).
    static func forgetAccount(_ accountId: String) {
        guard isValidAccountId(accountId) else { return }
        let entries = storedAccounts()
        DevRegKeychain.delete(service: keychainService, account: scopedKey(accountId))
        let remaining = entries.filter { $0.accountId != accountId }
        if remaining.isEmpty {
            DevRegKeychain.delete(service: keychainService, account: accountIndexKey)
        } else {
            saveIndex(remaining)
        }
    }

    /// Écrit l'index (JSON) dans le trousseau.
    static func saveIndex(_ entries: [DevRegRecoveryAccount]) {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        DevRegKeychain.save(
            data,
            service: keychainService,
            account: accountIndexKey,
            accessible: accessibility
        )
    }

    /// `/^\S+@\S+\.\S+$/` sur l'e-mail normalisé.
    static func isValidEmail(_ email: String) -> Bool {
        guard !email.contains(where: { $0.isWhitespace }) else { return false }
        let parts = email.split(separator: "@", omittingEmptySubsequences: false)
        guard parts.count == 2, !parts[0].isEmpty else { return false }
        let domain = parts[1]
        guard let dot = domain.firstIndex(of: "."),
              dot != domain.startIndex,
              domain.index(after: dot) != domain.endIndex else { return false }
        return true
    }
}
