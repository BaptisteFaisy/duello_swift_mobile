import Foundation
import GoogleSignIn
import UIKit

// MARK: - Identité Google

/// Identité nettoyée par le serveur (`GoogleIdentity` de
/// `utils/googleIdentity.ts`). Le client ne lit jamais le JWT local :
/// signature, audience, émetteur, expiration et e-mail vérifié sont
/// contrôlés côté serveur avant qu'une session puisse être ouverte.
struct GoogleIdentity: Equatable {
    /// Identifiant Google immuable (`sub` du jeton OpenID Connect).
    var subject: String
    var email: String
    var displayName: String
    var firstName: String
    var lastName: String
    var photoUrl: String?

    /// Relit strictement l'identité nettoyée par le serveur
    /// (`parseGoogleIdentity` de `utils/googleIdentity.ts`).
    static func parse(_ envelope: DuelloAPI.GoogleIdentityEnvelope) throws -> GoogleIdentity {
        let subject = (envelope.subject ?? "").trimmingCharacters(in: .whitespaces)
        let email = (envelope.email ?? "").trimmingCharacters(in: .whitespaces).lowercased()
        let displayName = (envelope.displayName ?? "").trimmingCharacters(in: .whitespaces)
        let firstName = (envelope.firstName ?? "").trimmingCharacters(in: .whitespaces)
        let lastName = (envelope.lastName ?? "").trimmingCharacters(in: .whitespaces)
        let photoUrl = (envelope.photoUrl ?? "").trimmingCharacters(in: .whitespaces)

        guard !subject.isEmpty,
              email.range(of: #"^\S+@\S+\.\S+$"#, options: .regularExpression) != nil,
              !displayName.isEmpty
        else {
            throw GoogleAuthError.invalidIdentity("Google n'a pas renvoyé une identité exploitable.")
        }

        return GoogleIdentity(
            subject: subject,
            email: email,
            displayName: displayName,
            firstName: firstName,
            lastName: lastName,
            photoUrl: photoUrl.hasPrefix("https://") ? photoUrl : nil
        )
    }
}

// MARK: - Erreurs

/// Erreurs de la connexion Google, alignées sur `GoogleAuthenticationError`.
enum GoogleAuthError: LocalizedError {
    /// Identité ou preuve inexploitable.
    case invalidIdentity(String)
    /// Réponse du serveur Duello, avec le statut HTTP.
    case server(String, status: Int?)
    /// Réseau ou délai dépassé.
    case network(String)
    /// SDK absent ou mal configuré.
    case sdk(String)

    var errorDescription: String? {
        switch self {
        case .invalidIdentity(let message),
             .network(let message),
             .sdk(let message):
            return message
        case .server(let message, _):
            return message
        }
    }
}

/// Messages alignés sur `googleErrorMessage` de `GoogleAuthButton.native.tsx`.
/// Une annulation volontaire renvoie nil : ce n'est pas une erreur à afficher.
func googleAuthErrorMessage(_ error: Error) -> String? {
    if let authError = error as? GoogleAuthError {
        return authError.errorDescription
    }
    let nsError = error as NSError
    // Domaine et code d'annulation du SDK (`GIDSignInErrorDomain`,
    // `GIDSignInErrorCanceled`), gardés littéraux pour ne pas dépendre du
    // pont Swift exact du SDK.
    if nsError.domain == "com.google.GIDSignIn", nsError.code == -3 {
        return nil
    }
    // Annulation au niveau Cocoa (`NSUserCancelledError`, code 3072 du domaine
    // `NSCocoaErrorDomain`). Le domaine est testé explicitement : le code 3072
    // seul provoquerait un faux positif pour une erreur étrangère.
    if nsError.domain == NSCocoaErrorDomain, nsError.code == CocoaError.Code.userCancelled.rawValue {
        return nil
    }
    let message = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
    return message.isEmpty ? "La connexion Google a échoué." : message
}

// MARK: - Configuration

/// Identifiants OAuth Google (`src/config/googleAuth.ts` de l'app Expo).
/// Les deux clients figurent dans les audiences acceptées par le serveur
/// (`GOOGLE_CLIENT_IDS` de `social-server.mjs`).
enum GoogleClientIds {
    /// Client iOS natif — ouvre la session sur l'appareil.
    static let ios = "283336474401-hbo36u49j767lqknahakr2937mfa6amn"
    /// Client web — audience serveur, comme `webClientId` dans
    /// `GoogleOneTapSignIn.configure` côté Expo.
    static let web = "283336474401-vnrbe290uqqr308drg290f6p86kji6b4"

    /// Équivalent de `GOOGLE_NATIVE_AUTH_CONFIGURED`.
    static var isConfigured: Bool { !ios.isEmpty && !web.isEmpty }
}

// MARK: - Service

/// Connexion Google native (`GoogleAuthButton.native.tsx` +
/// `utils/googleAuth.ts`). Le SDK GoogleSignIn fournit la preuve, le
/// serveur Duello la transforme en session : le jeton part à
/// `POST /auth/google` et seul le serveur décide de l'identité.
@MainActor
final class GoogleAuthService: NSObject {
    static let shared = GoogleAuthService()

    /// Délai serveur, comme `GOOGLE_AUTH_TIMEOUT_MS` (10 s) côté Expo.
    private static let timeout: TimeInterval = 10

    private var isConfigured = false

    /// Équivalent du `GoogleOneTapSignIn.configure` de l'effet de montage
    /// du bouton Expo, exécuté une seule fois au lancement.
    func configure() {
        guard !isConfigured else { return }
        isConfigured = true
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(
            clientID: GoogleClientIds.ios,
            serverClientID: GoogleClientIds.web
        )
    }

    /// Retour d'application depuis le navigateur Google (schéma
    /// `com.googleusercontent.apps.…`).
    func handle(_ url: URL) {
        configure()
        _ = GIDSignIn.sharedInstance.handle(url)
    }

    /// Parcours du bouton : session déjà accordée rouverte en silence
    /// d'abord (comportement iOS de `signIn()` dans l'Expo), boîte de
    /// dialogue interactive ensuite, puis vérification serveur.
    func authenticate(
        username: String? = nil
    ) async throws -> (identity: GoogleIdentity, session: DuelloAPI.SessionPayload) {
        guard GoogleClientIds.isConfigured else {
            throw GoogleAuthError.sdk("Ajoute les identifiants OAuth Google au build pour activer ce bouton.")
        }
        configure()

        let idToken = try await requestIdToken()
        return try await DuelloAPI.googleAuth(
            idToken: idToken,
            deviceId: SessionStore.deviceId(),
            username: username
        )
    }

    // MARK: SDK

    private func requestIdToken() async throws -> String {
        // Session déjà ouverte dans le process : réutilisée telle quelle.
        if let current = GIDSignIn.sharedInstance.currentUser,
           let token = current.idToken?.tokenString, !token.isEmpty {
            return token
        }
        // Rouverture en silence d'une session déjà accordée (comportement
        // iOS de `signIn()` dans l'Expo), boîte de dialogue interactive ensuite.
        if let restored = try? await restorePreviousUser(),
           let token = restored.idToken?.tokenString, !token.isEmpty {
            return token
        }

        guard let presenting = Self.topViewController() else {
            throw GoogleAuthError.sdk("La connexion Google est momentanément indisponible.")
        }
        let result = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<GIDSignInResult, Error>) in
            GIDSignIn.sharedInstance.signIn(withPresenting: presenting) { result, error in
                if let result {
                    continuation.resume(returning: result)
                } else {
                    continuation.resume(throwing: error ?? GoogleAuthError.sdk("Google n'a pas renvoyé de compte."))
                }
            }
        }
        guard let token = result.user.idToken?.tokenString, !token.isEmpty else {
            throw GoogleAuthError.sdk("Google n'a pas renvoyé de compte.")
        }
        return token
    }

    private func restorePreviousUser() async throws -> GIDGoogleUser {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<GIDGoogleUser, Error>) in
            GIDSignIn.sharedInstance.restorePreviousSignIn { user, error in
                if let user {
                    continuation.resume(returning: user)
                } else {
                    continuation.resume(throwing: error ?? GoogleAuthError.sdk("Aucune session Google enregistrée."))
                }
            }
        }
    }

    /// Fenêtre la plus haute pour présenter la feuille de connexion.
    private static func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        var top = scenes
            .flatMap(\.windows)
            .filter(\.isKeyWindow)
            .first?
            .rootViewController
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }
}
