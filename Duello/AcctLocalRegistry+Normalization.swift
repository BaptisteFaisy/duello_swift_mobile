//
//  AcctLocalRegistry+Normalization.swift
//  Duello
//
//  Port de src/utils/auth.ts (RN) — normalisation d'un enregistrement brut du
//  registre local : forme courante, ou `nil` s'il est inexploitable.
//
//  Découpage (24/09/2026) : section extraite de `AcctLocalRegistry.swift`
//  (porté du même fichier source).
//
//  Cible : iOS 16, aucune dépendance externe.
//
import Foundation

// MARK: - Normalisation

extension AcctLocalRegistry {
    /// `normalizeStoredAccount` : lit un enregistrement brut (éventuellement
    /// hérité) et le ramène à la forme courante, ou `nil` s'il est inexploitable.
    static func normalizeStoredAccount(_ raw: [String: Any]) -> AcctStoredAccount? {
        let profileEmail = (raw["profile"] as? [String: Any])?["email"] as? String
        let email = normalizeEmail((raw["email"] as? String) ?? profileEmail ?? "")
        guard !email.isEmpty else { return nil }
        if isAdminEmail(email) { return normalizeAdmin(raw) }
        return normalizeUser(raw, email: email)
    }

    /// `normalizeStoredAccount` appliqué à un compte déjà typé (utilisé par
    /// `saveAccount`) : passe par une sérialisation JSON puis la normalisation
    /// brute, garantissant une forme persistée identique.
    static func normalizeStoredAccount(_ account: AcctStoredAccount) -> AcctStoredAccount? {
        guard let data = try? JSONEncoder().encode(account),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        return normalizeStoredAccount(object)
    }

    /// Branche admin de `normalizeStoredAccount`.
    private static func normalizeAdmin(_ raw: [String: Any]) -> AcctStoredAccount {
        let canonical = createInitialAdminAccount()
        var account = canonical
        // L'identité admin appartient au produit : un ancien libellé persisté ne
        // doit pas remplacer le nom canonique.
        account.displayName = canonical.displayName
        account.passwordHash = raw["passwordHash"] as? String
        // L'admin ne traverse jamais les fournisseurs externes de l'espace élève.
        account.googleSubject = nil
        account.appleSubject = nil
        account.recoveryCodeHash = raw["recoveryCodeHash"] as? String
        account.biometricEnabled = false
        account.requiresPasswordSetup =
            AcctLocalRegistryJSON.bool(raw["requiresPasswordSetup"]) ?? (account.passwordHash == nil)
        return account
    }

    /// Branche utilisateur de `normalizeStoredAccount`.
    private static func normalizeUser(_ raw: [String: Any], email: String) -> AcctStoredAccount? {
        guard let profileObject = raw["profile"] as? [String: Any] else { return nil }
        var profile = decodeProfile(profileObject)
        let guest = AcctLocalRegistryJSON.bool(raw["guest"]) == true
            || RewStorageScope.isGuestEmail(email)
        let createdAt = AcctLocalRegistryJSON.double(raw["createdAt"])
        let validCreatedAt = createdAt.map { $0.isFinite && $0 > 0 } ?? false
        let rawDisplayName = raw["displayName"] as? String
        let fallback = profile.displayName.isEmpty ? email : profile.displayName
        // L'adresse du profil rejoint celle du compte ; plus de compte privé.
        profile.email = (profileObject["email"] as? String) ?? email
        profile.isPublic = true

        return AcctStoredAccount(
            id: RewStorageScope.storedUserAccountId(raw["id"] as? String, email: email),
            email: email,
            displayName: rawDisplayName ?? fallback,
            role: .user,
            passwordHash: raw["passwordHash"] as? String,
            googleSubject: trimmed(raw["googleSubject"]),
            appleSubject: trimmed(raw["appleSubject"]),
            biometricEnabled: AcctLocalRegistryJSON.bool(raw["biometricEnabled"]) == true,
            requiresPasswordSetup: false,
            recoveryCodeHash: nil,
            createdAt: validCreatedAt ? createdAt : Date().timeIntervalSince1970 * 1000,
            guest: guest,
            profile: profile
        )
    }

    /// `googleSubject`/`appleSubject` : une chaîne vide ou d'espaces vaut `nil`.
    private static func trimmed(_ value: Any?) -> String? {
        guard let string = value as? String else { return nil }
        let result = string.trimmingCharacters(in: .whitespacesAndNewlines)
        return result.isEmpty ? nil : result
    }

    /// Décode le profil brut en réutilisant la lecture tolérante de `UserProfile`.
    private static func decodeProfile(_ object: [String: Any]) -> UserProfile {
        guard let data = try? JSONSerialization.data(withJSONObject: object),
              let profile = try? JSONDecoder().decode(UserProfile.self, from: data) else {
            return UserProfile()
        }
        return profile
    }
}
