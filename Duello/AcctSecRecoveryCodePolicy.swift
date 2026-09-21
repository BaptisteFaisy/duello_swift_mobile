import Foundation

// Politique du code de secours administrateur — portée depuis
// `src/utils/credentials.ts` (`generateRecoveryCode`, `normalizeRecoveryCode`,
// `hashRecoveryCode`, `verifyRecoveryCode`, `issueRecoveryCode`,
// `resetAccountPassword`) et `src/utils/recoveryCodePolicy.ts`
// (`canUseRecoveryCode`, `needsUserRecoveryCodeRemoval`).
//
// Module volontairement pur — aucun accès au stockage ni à l'écran — pour
// rester vérifiable hors de l'application, comme `biometricPolicy.ts`.

/// Rôle d'un compte, tel que les politiques de sécurité le lisent
/// (`role` de `StoredAccount` dans `src/utils/auth.ts`).
enum AcctSecAccountRole: String, Codable, Equatable {
    case admin
    case user
}

/// Ce qu'il faut connaître d'un compte pour les règles de sécurité : le rôle,
/// l'activation biométrique et l'empreinte du code de secours.
struct AcctSecAccount: Equatable {
    var role: AcctSecAccountRole
    var biometricEnabled: Bool = false
    var recoveryCodeHash: String? = nil
}

/// Erreur de politique de mot de passe, alignée sur
/// `NEW_PASSWORD_POLICY_MESSAGE` de `shared/new-password-policy.mjs`.
enum AcctSecRecoveryCodeError: LocalizedError {
    case passwordPolicy

    var errorDescription: String? { AcctSecRecoveryCodePolicy.passwordPolicyMessage }
}

/// Politique du code de secours : génération, empreinte, vérification et
/// gardes d'accès. Fonctions pures, sans état.
enum AcctSecRecoveryCodePolicy {
    /// Alphabet sans caractère ambigu : le code se recopie à la main, et un
    /// `O` pris pour un `0` condamnerait le compte qu'il doit justement rouvrir.
    static let alphabet = "ACDEFGHJKLMNPQRTUVWXY34679"
    /// Longueur en lettres du code, hors tirets.
    static let codeLength = 16
    /// Taille d'un groupe séparé par un tiret (`XXXX-XXXX-XXXX-XXXX`).
    static let groupSize = 4
    /// Exemple affiché dans le champ de saisie (voir `LoginScreen.tsx`).
    static let placeholder = "XXXX-XXXX-XXXX-XXXX"
    /// Message de politique de mot de passe, mot pour mot.
    static let passwordPolicyMessage = "Le mot de passe doit contenir entre 8 et 128 caractères."

    /// Code neuf, groupé par quatre. Le tirage passe par `Int.random(in:)`,
    /// uniforme : contrairement à `randomBytes` côté Expo, aucun biais de
    /// modulo n'est possible.
    static func generateCode() -> String {
        let letters = Array(alphabet)
        var code = ""
        while code.count < codeLength {
            code.append(letters[Int.random(in: 0..<letters.count)])
        }
        return stride(from: 0, to: code.count, by: groupSize).map { start in
            let from = code.index(code.startIndex, offsetBy: start)
            let to = code.index(from, offsetBy: groupSize, limitedBy: code.endIndex) ?? code.endIndex
            return String(code[from..<to])
        }.joined(separator: "-")
    }

    /// Un code se retape sans tiret ni casse : la comparaison passe par cette forme.
    static func normalize(_ code: String) -> String {
        code.uppercased().filter { $0.isLetter || $0.isNumber }
    }

    /// Empreinte locale du code. Le préfixe `recovery$` la distingue de celle
    /// des mots de passe, qui partage la même fonction.
    static func hash(_ code: String) -> String {
        let normalized = normalize(code)
        return "recovery$\(fingerprint(normalized))$\(normalized.count)"
    }

    /// Vérifie une saisie contre l'empreinte enregistrée. Une empreinte absente
    /// n'est jamais une empreinte qui accepte tout.
    static func verify(_ code: String, matches storedHash: String?) -> Bool {
        let normalized = normalize(code)
        guard let storedHash, !storedHash.isEmpty, !normalized.isEmpty else { return false }
        return hash(normalized) == storedHash
    }

    /// Délivre un code à un compte qui n'en a pas, sans toucher à son mot de
    /// passe : les comptes créés avant ce mécanisme resteraient sinon
    /// irrécupérables.
    static func issue(for account: AcctSecAccount) -> (account: AcctSecAccount, code: String) {
        let code = generateCode()
        var updated = account
        updated.recoveryCodeHash = hash(code)
        return (updated, code)
    }

    /// Repose le mot de passe et délivre un code neuf : un code de secours ne
    /// sert qu'une fois, sinon celui qui l'a lu une fois rouvrirait le compte
    /// à volonté.
    static func resetPassword(for account: AcctSecAccount, password: String) throws
        -> (account: AcctSecAccount, code: String) {
        guard password.count >= 8, password.count <= 128 else {
            throw AcctSecRecoveryCodeError.passwordPolicy
        }
        let code = generateCode()
        var updated = account
        updated.recoveryCodeHash = hash(code)
        return (updated, code)
    }

    /// Le code de secours appartient exclusivement à la surface administrateur.
    /// Ce garde central évite qu'un écran public le réactive par accident.
    static func canUseRecoveryCode(_ account: AcctSecAccount?) -> Bool {
        account?.role == .admin
    }

    /// Détecte l'ancien champ afin que le registre utilisateur soit réécrit
    /// sans son empreinte, y compris lorsque sa valeur était déjà nulle.
    static func needsUserRecoveryCodeRemoval(rawRegistry: String?) -> Bool {
        guard let rawRegistry,
              let data = rawRegistry.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data),
              let entries = object as? [[String: Any]] else { return false }
        return entries.contains { entry in
            let role = entry["role"] as? String
            return role != AcctSecAccountRole.admin.rawValue
                && entry.keys.contains("recoveryCodeHash")
        }
    }

    // MARK: Interne

    /// Empreinte FNV-1a 32 bits, alignée sur `fingerprint` de `credentials.ts`
    /// (qui hache les unités de code UTF-16, comme `charCodeAt`).
    private static func fingerprint(_ value: String) -> String {
        var hash: UInt32 = 0x811c9dc5
        for unit in value.utf16 {
            hash ^= UInt32(unit)
            hash = hash &* 0x01000193
        }
        return String(hash, radix: 16)
    }
}
