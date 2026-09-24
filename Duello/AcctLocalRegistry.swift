//
//  AcctLocalRegistry.swift
//  Duello
//
//  Port de src/utils/auth.ts (RN) — registre local multi-comptes : lecture,
//  écriture et retrait des comptes stockés sur l'appareil, normalisation des
//  enregistrements hérités et déduplication.
//
//  Fichiers source Expo portés (constantes et clés reprises mot pour mot) :
//    - src/utils/auth.ts
//        `AccountRole`, `AccountBase`, `AdminAccount`, `UserAccount`,
//        `StoredAccount`, `isAdminAccount`, `isUserAccount`, `isGuestAccount`,
//        `createInitialAdminAccount`, `normalizeStoredAccount`,
//        `parseAccountArray`, `parseSingleAccount`, `uniqueUsers`,
//        `loadAccounts`, `loadAccount`, `saveAccount`, `removeUserAccount`,
//        `findAccountByEmail`, `verifyCredentials`, les clés
//        `LEGACY_ACCOUNT_STORAGE_KEY` / `LEGACY_ACCOUNTS_STORAGE_KEY` /
//        `USER_ACCOUNTS_STORAGE_KEY` / `ADMIN_ACCOUNT_STORAGE_KEY`.
//    - src/utils/accountIdentity.ts (`normalizeEmail`, `ADMIN_ACCOUNT_EMAIL`,
//        `isAdminEmail`) et `src/utils/storageScope.ts`
//        (`storedUserAccountId`, `isGuestEmail`) — déjà portés ailleurs, réutilisés.
//
//  Seam honnête : le stockage clé/valeur est derrière `AcctLocalRegistryStorage`
//  (implémentation par défaut : `UserDefaults`, équivalent iOS d'`AsyncStorage`).
//  La source est asynchrone (`Promise`) ; la lecture `UserDefaults` étant
//  synchrone, l'API Swift l'est aussi — sémantique identique.
//
//  Découpage (24/09/2026) : ce fichier porte les clés, le stockage, le modèle et
//  l'identité du registre ; les autres responsabilités vivent dans des
//  extensions dédiées — `AcctLocalRegistry+JSON.swift` (lecture JSON tolérante),
//  `AcctLocalRegistry+Normalization.swift` (normalisation des enregistrements),
//  `AcctLocalRegistry+Parsing.swift` (analyse du registre),
//  `AcctLocalRegistry+Persistence.swift` (lecture/écriture),
//  `AcctLocalRegistry+Serialization.swift` (encodage JSON) et
//  `AcctLocalRegistryMigrations.swift` (détecteurs de migration, porté du même
//  fichier source).
//
//  Limites assumées (24/09/2026) : `hashPassword` réutilise
//  `LoginScrCredential.hashPassword` (déjà porté, format `fnv1a$…$longueur`).
//  L'empreinte du mot de passe reste locale, comme dans la source (« devra être
//  remplacée par l'authentification serveur »).
//
//  Cible : iOS 16, aucune dépendance externe.
//
import Foundation

// MARK: - Clés et stockage

/// Clés de stockage du registre local (`src/utils/auth.ts`).
enum AcctLocalRegistryKeys {
    /// `LEGACY_ACCOUNT_STORAGE_KEY` : ancien compte unique.
    static let legacyAccount = "@prepapp/account-v1"
    /// `LEGACY_ACCOUNTS_STORAGE_KEY` : ancien registre multi-comptes.
    static let legacyAccounts = "@prepapp/accounts-v2"
    /// `USER_ACCOUNTS_STORAGE_KEY` : registre des comptes utilisateur.
    static let userAccounts = "@prepapp/user-accounts-v3"
    /// `ADMIN_ACCOUNT_STORAGE_KEY` : registre admin, séparé (même clé que
    /// `AdmAccountRegistry.accountStorageKey`).
    static let adminAccount = AdmAccountRegistry.accountStorageKey
}

/// Stockage clé/valeur minimal du registre (équivalent iOS d'`AsyncStorage`).
protocol AcctLocalRegistryStorage {
    func getItem(_ key: String) -> String?
    func setItem(_ key: String, _ value: String)
}

/// Implémentation par défaut adossée à `UserDefaults`.
struct AcctUserDefaultsRegistryStorage: AcctLocalRegistryStorage {
    func getItem(_ key: String) -> String? {
        UserDefaults.standard.string(forKey: key)
    }

    func setItem(_ key: String, _ value: String) {
        UserDefaults.standard.set(value, forKey: key)
    }
}

// MARK: - Compte stocké

/// `StoredAccount` (`AdminAccount | UserAccount`) de `src/utils/auth.ts`,
/// unifié en une seule structure : les champs admin (`recoveryCodeHash`) et les
/// champs utilisateur (`createdAt`, `guest`, profil) coexistent, comme le fait
/// la source lors d'une migration.
struct AcctStoredAccount: Identifiable, Codable, Equatable {
    var id: String
    var email: String
    var displayName: String
    var role: AcctSecAccountRole
    /// `passwordHash` : empreinte locale du mot de passe.
    var passwordHash: String?
    var googleSubject: String?
    var appleSubject: String?
    var biometricEnabled: Bool
    var requiresPasswordSetup: Bool
    /// `recoveryCodeHash` : réservé à l'administrateur.
    var recoveryCodeHash: String?
    /// `createdAt` : instant d'inscription (comptes utilisateur).
    var createdAt: Double?
    /// `guest` : compte local sans identifiants visibles.
    var guest: Bool
    var profile: UserProfile

    var isAdmin: Bool { role == .admin }
    var isUser: Bool { role == .user }
    var isGuest: Bool { role == .user && guest }
}

// MARK: - Registre

/// `auth.ts` : règles et persistance du registre local multi-comptes.
enum AcctLocalRegistry {
    /// `ADMIN_ACCOUNT_EMAIL` de `accountIdentity.ts`.
    static let adminAccountEmail = "bg.fsg.invest@gmail.com"
    /// `ADMIN_EMAILS`.
    static let adminEmails: [String] = [adminAccountEmail]
    /// `ADMIN_ACCOUNT_DISPLAY_NAME` de `auth.ts`.
    static let adminAccountDisplayName = "Admin Duello"
    /// Identifiant fixe du compte admin (`id: 'admin'`).
    static let adminIdentifier = "admin"

    /// `normalizeEmail` : espaces retirés, casse abaissée.
    static func normalizeEmail(_ email: String) -> String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    /// `isAdminEmail` : l'adresse appartient-elle au registre admin ?
    static func isAdminEmail(_ email: String?) -> Bool {
        guard let email else { return false }
        return adminEmails.contains(normalizeEmail(email))
    }

    /// `createInitialAdminAccount` : compte admin canonique, identité fixée par
    /// le produit.
    static func createInitialAdminAccount() -> AcctStoredAccount {
        var profile = UserProfile()
        profile.displayName = adminAccountDisplayName
        profile.email = adminAccountEmail
        return AcctStoredAccount(
            id: adminIdentifier,
            email: adminAccountEmail,
            displayName: adminAccountDisplayName,
            role: .admin,
            passwordHash: nil,
            googleSubject: nil,
            appleSubject: nil,
            biometricEnabled: false,
            requiresPasswordSetup: true,
            recoveryCodeHash: nil,
            createdAt: nil,
            guest: false,
            profile: profile
        )
    }
}
