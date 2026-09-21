//
//  AppleAuthModels.swift
//  Duello
//
//  Modèles de la connexion « Se connecter avec Apple », portés depuis l'app
//  Expo. Fichiers source :
//    - src/utils/appleIdentity.ts  (`AppleIdentity`, `AppleAuthenticationError`,
//                                  `parseAppleIdentity`)
//    - src/utils/appleAuth.ts      (`AppleCredentialProof`)
//    - src/components/AppleAuthButton.tsx (`appleErrorMessage`)
//
//  Le client ne décode JAMAIS le jeton d'identité Apple : le serveur Duello
//  contrôle signature, émetteur, expiration et e-mail certifié avant qu'une
//  session puisse être ouverte. `parseAppleIdentity` ne fait que relire
//  strictement l'identité déjà nettoyée par le serveur.
//
//  Cible : iOS 16. Aucune dépendance externe.
//

import Foundation

// MARK: - Identité serveur

/// `AppleIdentity` de `src/utils/appleIdentity.ts` : identité nettoyée par le
/// serveur, seule source de vérité sur les claims signés d'Apple.
struct AppleAuthIdentity: Equatable {
    /// Identifiant Apple immuable (`sub` du jeton OpenID Connect).
    var subject: String
    var email: String
    var displayName: String
    var firstName: String
    var lastName: String

    /// Relit strictement l'identité nettoyée par le serveur
    /// (`parseAppleIdentity`), jamais le JWT local.
    static func parse(_ envelope: AppleAuthIdentityEnvelope) throws -> AppleAuthIdentity {
        let subject = (envelope.subject ?? "").trimmingCharacters(in: .whitespaces)
        let email = (envelope.email ?? "").trimmingCharacters(in: .whitespaces).lowercased()
        let displayName = (envelope.displayName ?? "").trimmingCharacters(in: .whitespaces)
        let firstName = (envelope.firstName ?? "").trimmingCharacters(in: .whitespaces)
        let lastName = (envelope.lastName ?? "").trimmingCharacters(in: .whitespaces)

        guard !subject.isEmpty,
              email.range(of: #"^\S+@\S+\.\S+$"#, options: .regularExpression) != nil,
              !displayName.isEmpty
        else {
            throw AppleAuthError.invalidIdentity("Apple n’a pas renvoyé une identité exploitable.")
        }

        return AppleAuthIdentity(
            subject: subject,
            email: email,
            displayName: displayName,
            firstName: firstName,
            lastName: lastName
        )
    }
}

/// Identité telle que renvoyée par le serveur dans `POST /auth/apple`, avant
/// la revalidation stricte de `AppleAuthIdentity.parse` (miroir de la forme
/// non typée lue par `parseAppleIdentity`).
struct AppleAuthIdentityEnvelope: Decodable {
    var subject: String?
    var email: String?
    var displayName: String?
    var firstName: String?
    var lastName: String?
}

// MARK: - Preuve native

/// `AppleCredentialProof` de `src/utils/appleAuth.ts` : preuve produite par le
/// SDK Apple (`authorizationCode`, `identityToken`, `nonce`), échangée contre
/// une session Duello via `POST /auth/apple`. `firstName`/`lastName` ne sont
/// fournis par Apple qu'à la toute première autorisation.
struct AppleAuthCredential: Equatable {
    var authorizationCode: String
    var identityToken: String
    var nonce: String
    var firstName: String?
    var lastName: String?
}

// MARK: - Erreurs

/// Erreurs de la connexion Apple, alignées sur `AppleAuthenticationError` de
/// `src/utils/appleIdentity.ts`.
enum AppleAuthError: LocalizedError, Equatable {
    /// Identité ou preuve inexploitable.
    case invalidIdentity(String)
    /// Réponse du serveur Duello, avec le statut HTTP.
    case server(String, status: Int?)
    /// Réseau ou délai dépassé.
    case network(String)
    /// Brique native absente (authentification Apple indisponible sur la
    /// plateforme de compilation).
    case unavailable(String)
    /// Autre échec natif, message brut du système.
    case failed(String)
    /// Autorisation annulée par l'élève : à ne pas afficher.
    case cancelled

    var errorDescription: String? {
        switch self {
        case .cancelled:
            return nil
        case .invalidIdentity(let message),
             .network(let message),
             .unavailable(let message),
             .failed(let message):
            return message
        case .server(let message, _):
            return message
        }
    }

    /// Traduit une erreur native du SDK Apple. Le domaine et le code
    /// d'annulation (`ASAuthorizationError.canceled`, code 1001) sont gardés
    /// littéraux pour ne pas importer `AuthenticationServices` dans le modèle.
    static func from(_ error: Error) -> AppleAuthError {
        let nsError = error as NSError
        if nsError.domain == "com.apple.AuthenticationServices.AuthorizationError", nsError.code == 1001 {
            return .cancelled
        }
        if nsError.domain == NSCocoaErrorDomain, nsError.code == CocoaError.Code.userCancelled.rawValue {
            return .cancelled
        }
        let message = nsError.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        return .failed(message.isEmpty ? "La connexion Apple est momentanément indisponible." : message)
    }
}

/// Messages alignés sur `appleErrorMessage` de `AppleAuthButton.tsx`. Une
/// annulation volontaire renvoie `nil` : ce n'est pas une erreur à afficher.
func appleAuthErrorMessage(_ error: Error) -> String? {
    if let authError = error as? AppleAuthError {
        return authError.errorDescription
    }
    let nsError = error as NSError
    if nsError.domain == "com.apple.AuthenticationServices.AuthorizationError", nsError.code == 1001 {
        return nil
    }
    if nsError.domain == NSCocoaErrorDomain, nsError.code == CocoaError.Code.userCancelled.rawValue {
        return nil
    }
    let message = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
    return message.isEmpty ? "La connexion Apple est momentanément indisponible." : message
}
