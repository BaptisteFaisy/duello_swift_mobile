//
//  AppleAuthAccount.swift
//  Duello
//
//  Résolution du compte Apple, portée depuis l'app Expo. Fichiers source :
//    - src/utils/appleAccount.ts    (`resolveAppleAccount`,
//                                    `profileWithAppleIdentity`,
//                                    `withoutRemoteProviderPhoto`,
//                                    `accountForAppleSubject`,
//                                    `resolvedLoginAccount`)
//    - src/utils/accountIdentity.ts (`normalizeEmail`, `ADMIN_EMAILS`,
//                                    `isAdminEmail`)
//
//  Fonctions PURES : aucun stockage, aucun réseau. Elles n'arbitrent jamais
//  une connexion — elles ne font qu'appliquer la décision déjà prise par le
//  serveur dans `POST /auth/apple` (409 en cas de vrai conflit).
//
//  Le registre local complet (`StoredAccount`, `UserAccount` de `utils/auth.ts`)
//  n'est pas encore porté : `AppleAuthAccount` n'en est qu'un instantané
//  minimal, limité aux champs lus par la résolution.
//
//  Cible : iOS 16. Aucune dépendance externe.
//

import Foundation

/// Instantané minimal d'un compte local pour la résolution Apple.
struct AppleAuthAccount: Equatable {
    var id: String
    var email: String
    /// `"user"` ou `"admin"` (`AccountRole` de `utils/auth.ts`).
    var role: String
    var appleSubject: String?
    var profile: UserProfile

    var isUser: Bool { role == "user" }
    var isAdmin: Bool { role == "admin" }
}

/// `AppleAccountResolution` de `src/utils/appleAccount.ts`.
enum AppleAuthAccountResolution: Equatable {
    case login(account: AppleAuthAccount, linkedNow: Bool)
    case signup(profile: UserProfile)
    case rejected(message: String)
}

/// Décisions pures de la connexion Apple.
enum AppleAuthAccountResolver {
    /// `ADMIN_EMAILS` de `utils/accountIdentity.ts` (adresses normalisées).
    static let adminEmails: [String] = ["bg.fsg.invest@gmail.com"]

    /// Message d'arbitrage unique (`resolveAppleAccount`), réutilisé pour
    /// l'adresse admin et pour le compte admin trouvé par e-mail.
    static let adminRejection = "Le compte administrateur ne peut pas utiliser Apple dans l’espace élève."

    /// `isAdminEmail` : l'adresse appartient-elle au registre admin ?
    static func isAdminEmail(_ email: String?) -> Bool {
        guard let email else { return false }
        return adminEmails.contains(normalize(email))
    }

    /// `profileWithAppleIdentity` : prénom en affichage, e-mail normalisé,
    /// profil public, sans photo distante héritée d'un autre fournisseur.
    static func profileWithIdentity(_ profile: UserProfile, identity: AppleAuthIdentity) -> UserProfile {
        var result = withoutRemoteProviderPhoto(profile)
        let words = identity.displayName.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        let firstName = identity.firstName.isEmpty ? (words.first ?? "") : identity.firstName
        let lastName = identity.lastName.isEmpty ? words.dropFirst().joined(separator: " ") : identity.lastName

        result.displayName = firstName.isEmpty ? identity.displayName : firstName
        result.firstName = firstName
        result.lastName = lastName
        result.email = normalize(identity.email)
        result.isPublic = true
        return result
    }

    /// `resolveAppleAccount` : résout par `sub` Apple, puis par e-mail, sans
    /// jamais rejeter une connexion que le serveur a déjà validée.
    static func resolve(
        accounts: [AppleAuthAccount],
        identity: AppleAuthIdentity,
        initialProfile: UserProfile
    ) -> AppleAuthAccountResolution {
        let email = normalize(identity.email)
        if isAdminEmail(email) { return .rejected(message: adminRejection) }

        let subjectAccount = accounts.first { $0.isUser && $0.appleSubject == identity.subject }
        let emailAccount = accounts.first { normalize($0.email) == email }

        if let subjectAccount {
            return .login(account: realigned(subjectAccount, subject: identity.subject), linkedNow: false)
        }
        if let emailAccount, emailAccount.isAdmin {
            return .rejected(message: adminRejection)
        }
        if let emailAccount, emailAccount.isUser {
            // Le serveur a déjà tranché : on suit sa décision et on réaligne le
            // registre local sur l'identité certifiée plutôt que de rejeter.
            return .login(account: realigned(emailAccount, subject: identity.subject), linkedNow: true)
        }
        return .signup(profile: profileWithIdentity(initialProfile, identity: identity))
    }

    // MARK: Helpers privés

    /// `normalizeEmail` de `utils/accountIdentity.ts`.
    private static func normalize(_ email: String) -> String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    /// `withoutRemoteProviderPhoto` : aucune photo distante n'est recopiée
    /// d'un fournisseur à l'autre.
    private static func withoutRemoteProviderPhoto(_ profile: UserProfile) -> UserProfile {
        var result = profile
        if let photo = result.photoUri,
           photo.range(of: #"^https?://"#, options: [.regularExpression, .caseInsensitive]) != nil {
            result.photoUri = nil
        }
        return result
    }

    /// `resolvedLoginAccount` : lie le `sub` Apple et rend le profil public.
    private static func realigned(_ account: AppleAuthAccount, subject: String) -> AppleAuthAccount {
        var result = account
        result.appleSubject = subject
        result.profile = withoutRemoteProviderPhoto(account.profile)
        result.profile.isPublic = true
        return result
    }
}
