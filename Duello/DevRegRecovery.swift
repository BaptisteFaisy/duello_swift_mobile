import Foundation
import Security

// Port de `src/utils/deviceRecovery.ts` : preuve de reconnexion locale
// (identifiant d'installation + secret `drs_…`) permettant à une réinstallation
// de retrouver un compte. Clés, service et accessibilité du trousseau sont
// repris mot pour mot de la source.

/// Entrée de l'index des comptes connus (`RecoveryAccountEntry`).
struct DevRegRecoveryAccount: Codable, Equatable {
    var accountId: String
    var email: String
}

/// Preuve transmise au serveur (`deviceRecoveryProof`).
struct DevRegRecoveryProof {
    var deviceId: String
    var recoverySecret: String?
    var recoveryEmail: String?
}

/// Preuve de reconnexion d'appareil et son stockage.
enum DevRegRecovery {
    /// Clé historique : relue pour migrer les comptes déjà inscrits, plus
    /// jamais réutilisée en écriture (`RECOVERY_SECRET_KEY`).
    static let legacySecretKey = "duello-device-recovery-v1"
    /// Index des comptes connus (`RECOVERY_ACCOUNT_INDEX_KEY`).
    static let accountIndexKey = "duello-device-recovery-accounts-v2"
    /// Préfixe des secrets par compte (`RECOVERY_SECRET_KEY_PREFIX`).
    static let secretKeyPrefix = "duello-device-recovery-v2-"
    /// Service du trousseau (`keychainService` de `RECOVERY_SECRET_OPTIONS`).
    static let keychainService = "duello-device-recovery"
    /// Accessibilité `AFTER_FIRST_UNLOCK`.
    static let accessibility = kSecAttrAccessibleAfterFirstUnlock

    /// `/^drs_[a-f0-9]{64}$/`.
    static func isValidSecret(_ value: String?) -> Bool {
        guard let value, value.hasPrefix("drs_"), value.count == 68 else { return false }
        return value.dropFirst(4).allSatisfy { $0.isHexDigit }
    }

    /// `/^user-[a-f0-9]{8,2048}$/`.
    static func isValidAccountId(_ value: String) -> Bool {
        guard value.hasPrefix("user-") else { return false }
        let suffix = value.dropFirst(5)
        guard (8...2048).contains(suffix.count) else { return false }
        return suffix.allSatisfy { $0.isHexDigit }
    }

    /// Clé du trousseau propre à un compte (`scopedRecoverySecretKey`).
    static func scopedKey(_ accountId: String) -> String {
        "\(secretKeyPrefix)\(accountId)"
    }

    /// `drs_` + deux UUID sans tirets (64 caractères hexadécimaux,
    /// `randomRecoverySecret`).
    static func randomSecret() -> String {
        let part = { UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased() }
        return "drs_\(part())\(part())"
    }

    /// E-mail normalisé (`normalizeEmail` de `accountIdentity.ts`).
    static func normalizeEmail(_ email: String) -> String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    /// Secret enregistré pour un compte, ou le secret historique sans compte
    /// (`storedDeviceRecoverySecret`).
    static func storedSecret(accountId: String?) -> String? {
        let key = accountId.map(scopedKey) ?? legacySecretKey
        guard let data = DevRegKeychain.read(service: keychainService, account: key),
              let secret = String(data: data, encoding: .utf8),
              isValidSecret(secret) else { return nil }
        return secret
    }

    /// Délivre (ou retrouve) le secret d'un compte (`ensureDeviceRecoverySecret`).
    static func ensureSecret(accountId: String, email: String) -> String? {
        guard isValidAccountId(accountId) else { return nil }
        if let existing = storedSecret(accountId: accountId) {
            rememberAccount(accountId: accountId, email: email)
            return existing
        }
        let secret = randomSecret()
        DevRegKeychain.save(
            Data(secret.utf8),
            service: keychainService,
            account: scopedKey(accountId),
            accessible: accessibility
        )
        rememberAccount(accountId: accountId, email: email)
        return secret
    }

    /// Preuve complète (`deviceRecoveryProof`).
    static func proof(
        createSecret: Bool,
        accountId: String? = nil,
        accountEmail: String? = nil
    ) -> DevRegRecoveryProof {
        let deviceId = DevReg.registrationDeviceId()
        var recoveryAccountId = accountId.flatMap { isValidAccountId($0) ? $0 : nil }
        var recoveryEmail = accountEmail.map(normalizeEmail)
        if recoveryAccountId == nil && recoveryEmail == nil && !createSecret {
            let accounts = storedAccounts()
            if accounts.count == 1 {
                recoveryAccountId = accounts[0].accountId
                recoveryEmail = accounts[0].email
            }
        }

        let recoverySecret: String?
        if createSecret, let id = recoveryAccountId, let email = recoveryEmail {
            recoverySecret = ensureSecret(accountId: id, email: email)
        } else if let id = recoveryAccountId {
            recoverySecret = storedSecret(accountId: id) ?? storedSecret(accountId: nil)
        } else {
            recoverySecret = storedSecret(accountId: nil)
        }
        return DevRegRecoveryProof(
            deviceId: deviceId,
            recoverySecret: recoverySecret,
            recoveryEmail: recoveryEmail
        )
    }
}
