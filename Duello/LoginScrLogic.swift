//
//  LoginScrLogic.swift
//  Duello
//
//  Modèles et règles pures de l'écran de connexion, portés de
//  `src/screens/LoginScreen.tsx` et de ses dépendances :
//    - `src/utils/auth.ts`          (`StoredAccount`, `UserAccount`,
//                                    `AdminAccount`, `findAccountByEmail`,
//                                    `isUserAccount`, `verifyCredentials`)
//    - `src/utils/credentials.ts`   (`hashPassword`, empreinte FNV-1a)
//    - `src/utils/accountIdentity.ts` (`normalizeEmail`)
//
//  Le registre local complet (`utils/auth.ts` : stockage, `saveAccount`,
//  `loadAccounts`) n'est PAS porté — `AppleAuthAccount.swift` le documente
//  déjà. `LoginScrAccount` n'en est qu'un instantané minimal, limité aux
//  champs que l'écran lit ; la persistance passe par `LoginScrProps`.
//
//  Aucun accès au stockage ni au réseau : module vérifiable hors application,
//  comme `biometricPolicy.ts` / `credentials.ts`.
//
//  Cible : iOS 16. Aucune dépendance externe.
//

import Foundation

// MARK: - Compte

/// Instantané d'un compte stocké, suffisant pour l'écran de connexion.
///
/// Reprend les champs lus par `LoginScreen.tsx` sur `StoredAccount`
/// (`src/utils/auth.ts`) : `passwordHash`, `googleSubject`, `appleSubject`,
/// `biometricEnabled`, `requiresPasswordSetup` (admin), `recoveryCodeHash`
/// (admin) et `guest` (utilisateur).
struct LoginScrAccount: Identifiable, Equatable {
    let id: String
    var email: String
    var displayName: String
    /// Rôle réutilisé de `AcctSecAccountRole` (admin | user), déjà porté.
    var role: AcctSecAccountRole
    var passwordHash: String?
    var googleSubject: String?
    var appleSubject: String?
    var biometricEnabled: Bool = false
    var requiresPasswordSetup: Bool = false
    /// Réservé à l'administrateur, comme dans `AdminAccount`.
    var recoveryCodeHash: String?
    /// Compte local sans identifiants visibles (`guest` de `UserAccount`).
    var isGuest: Bool = false
}

/// Code de secours fraîchement délivré, en attente d'accusé de réception.
///
/// Même précaution que la source : le compte rouvert est **retenu** tant que
/// le code n'a pas été lu, sinon l'ouvrir ferait disparaître le code avec
/// l'écran.
struct LoginScrIssuedCode: Equatable {
    var account: LoginScrAccount
    var code: String
}

/// Les deux étapes de l'écran (`step` de `LoginScreen.tsx`).
enum LoginScrStep: Equatable {
    case identity
    case credentials
}

// MARK: - Règles de compte

/// Règles de lecture d'un compte stocké (`utils/auth.ts`).
enum LoginScrAccountBook {
    /// `findAccountByEmail` : correspondance sur l'adresse normalisée.
    static func find(_ accounts: [LoginScrAccount], email: String) -> LoginScrAccount? {
        let normalized = LoginScrCredential.normalize(email)
        return accounts.first { LoginScrCredential.normalize($0.email) == normalized }
    }

    /// `isUserAccount` : le compte est-il un compte utilisateur ?
    static func isUser(_ account: LoginScrAccount) -> Bool {
        account.role == .user
    }

    /// `isAdminActivation` : compte administrateur pas encore activé
    /// (`requiresPasswordSetup`).
    static func isAdminActivation(_ account: LoginScrAccount?) -> Bool {
        guard let account else { return false }
        return account.role == .admin && account.requiresPasswordSetup
    }

    /// `canResetPassword` : un administrateur déjà activé peut être réinitialisé
    /// par code ; une activation choisit déjà son mot de passe.
    static func canResetPassword(_ account: LoginScrAccount?) -> Bool {
        guard let account, account.role == .admin else { return false }
        return !isAdminActivation(account)
    }

    /// Vue minimale lue par les politiques de sécurité déjà portées
    /// (`AcctSecAccount` de `AcctSecRecoveryCodePolicy.swift`).
    static func security(_ account: LoginScrAccount) -> AcctSecAccount {
        AcctSecAccount(
            role: account.role,
            biometricEnabled: account.biometricEnabled,
            recoveryCodeHash: account.recoveryCodeHash
        )
    }
}

// MARK: - Identifiants

/// Vérification locale des identifiants (`credentials.ts`, `accountIdentity.ts`).
enum LoginScrCredential {
    /// `normalizeEmail` : espaces retirés, casse abaissée.
    static func normalize(_ email: String) -> String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    /// Test d'adresse repris mot pour mot de la source (`/^\S+@\S+\.\S+$/`).
    static func isValidEmail(_ value: String) -> Bool {
        value.range(of: #"^\S+@\S+\.\S+$"#, options: .regularExpression) != nil
    }

    /// `hashPassword` de `credentials.ts` : `fnv1a$<empreinte>$<longueur>`.
    static func hashPassword(_ password: String) -> String {
        "fnv1a$\(fingerprint(password))$\(password.count)"
    }

    /// `verifyCredentials` : adresse identique **et** empreinte concordante.
    /// Une empreinte absente ne vaut jamais acceptation.
    static func verifyCredentials(_ account: LoginScrAccount, email: String, password: String) -> Bool {
        guard normalize(email) == normalize(account.email), let stored = account.passwordHash else {
            return false
        }
        return hashPassword(password) == stored
    }

    /// Empreinte FNV-1a 32 bits sur les unités UTF-16, alignée sur
    /// `fingerprint` de `credentials.ts` (qui hache `charCodeAt`).
    private static func fingerprint(_ value: String) -> String {
        var hash: UInt32 = 0x811c9dc5
        for unit in value.utf16 {
            hash ^= UInt32(unit)
            hash = hash &* 0x01000193
        }
        return String(hash, radix: 16)
    }
}

// MARK: - Textes

/// Libellés et messages de l'écran, repris **mot pour mot** de
/// `src/screens/LoginScreen.tsx`. Regroupés ici pour qu'aucune vue n'ait à
/// coder un message en dur.
enum LoginScrCopy {
    // Champs
    static let emailLabel = "ADRESSE E-MAIL"
    static let emailPlaceholder = "camille@email.fr"
    static let recoveryCodeLabel = "CODE DE SECOURS"
    static let passwordLabel = "MOT DE PASSE"
    static let newPasswordLabel = "NOUVEAU MOT DE PASSE"
    static let adminNewPasswordLabel = "NOUVEAU MOT DE PASSE ADMINISTRATEUR"
    static let passwordPlaceholder = "Ton mot de passe"
    static let newPasswordPlaceholder = "Le mot de passe de ton choix"
    static let confirmLabel = "CONFIRMER LE MOT DE PASSE"
    static let confirmPlaceholder = "Répète le mot de passe"

    // Liens
    static let forgotPassword = "J’ai oublié mon mot de passe"
    static let backToLogin = "Revenir à la connexion"
    static let continueTitle = "Continuer"

    // En-tête
    static let resetEyebrow = "MOT DE PASSE OUBLIÉ"
    static let adminEyebrow = "ADMINISTRATION"
    static let resetTitle = "Choisir un nouveau mot de passe"
    static let adminTitle = "Activer le compte administrateur"
    static let resetSubtitle = "Saisis le code de secours administrateur, puis choisis le nouveau mot de passe."
    static let adminSubtitle = "Choisis le mot de passe définitif de ce compte. Cette étape ne sera demandée qu’une fois sur cet appareil."

    // Bouton de pied
    static let submitReset = "Réinitialiser le mot de passe"
    static let submitActivation = "Activer et se connecter"
    static let submitting = "Connexion…"
    static let submit = "Se connecter"

    // Erreurs de validation
    static let invalidEmail = "Saisis une adresse e-mail valide."
    static let invalidResetEmail = "Saisis l’adresse e-mail du compte à récupérer."
    static let recoveryAdminOnly = "La récupération par code est réservée au compte administrateur."
    static let noRecoveryCode = "Aucun code de secours n’a encore été délivré pour ce compte administrateur."
    static let recoveryMismatch = "Ce code de secours ne correspond pas à ce compte."
    static let passwordMismatch = "Les deux mots de passe ne correspondent pas."
    static let enterPassword = "Saisis ton mot de passe."
    static let enterPasswordOrGoogle = "Saisis ton mot de passe ou choisis « Continuer avec Google »."
    static let enterPasswordOrApple = "Saisis ton mot de passe ou choisis « Continuer avec Apple »."
    static let useBiometrics = "Ce compte a été créé avec la biométrie : utilise le bouton « Continuer avec la biométrie »."
    static let useGoogle = "Ce compte utilise Google : choisis « Continuer avec Google »."
    static let useApple = "Ce compte utilise Apple : choisis « Continuer avec Apple »."
    static let badCredentials = "E-mail ou mot de passe incorrect."
    static let unavailable = "Connexion indisponible."

    // Erreurs biométriques
    static let biometricEmailFirst = "Saisis d’abord l’adresse e-mail du compte à déverrouiller."
    static let biometricUnknownAccount = "Ce compte n’est pas enregistré sur cet appareil. Crée-le ou connecte-toi d’abord avec son mot de passe."
    static let biometricUsersOnly = "La connexion biométrique est réservée aux comptes utilisateurs."
    static let biometricNotEnabled = "La connexion biométrique n’est pas activée pour ce compte."
    static let biometricSetupWithPassword = "Configure une empreinte ou la reconnaissance faciale dans les réglages du téléphone, puis réessaie. Tu peux aussi utiliser ton mot de passe."
    static let biometricSetup = "Configure une empreinte ou la reconnaissance faciale dans les réglages du téléphone, puis réessaie."
    static let biometricLockout = "La biométrie est temporairement verrouillée. Utilise ton mot de passe."
    static let biometricFailed = "L’identité biométrique n’a pas pu être vérifiée."
}
