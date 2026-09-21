//
//  AppleAuthProvider.swift
//  Duello
//
//  Pont natif vers l'authentification Apple, porté depuis l'app Expo.
//  Fichiers source :
//    - src/components/AppleAuthButton.tsx (`AppleAuthentication.signInAsync`,
//                                        `requestedScopes` FULL_NAME + EMAIL,
//                                        `Crypto.randomUUID()` pour le nonce)
//
//  Toute la brique `AuthenticationServices` est confinée sous
//  `#if canImport(AuthenticationServices)`. Hors Apple (compilation Linux), ce
//  fichier ne produit aucun code : `AppleAuthService.signIn()` renvoie alors
//  une `AppleAuthError.unavailable` documentée.
//
//  Cible : iOS 16. Aucune dépendance externe.
//

#if canImport(AuthenticationServices)
import Foundation
import AuthenticationServices
import UIKit

/// Adaptateur de la boîte de dialogue « Se connecter avec Apple ». Équivalent
/// de `AppleAuthentication.signInAsync` : prépare la requête (nom + e-mail),
/// porte le nonce aléatoire et renvoie la preuve brute, sans jamais décoder le
/// jeton d'identité.
enum AppleAuthProvider {
    /// Produit la preuve Apple (`authorizationCode`, `identityToken`, `nonce`).
    static func requestCredential() async throws -> AppleAuthCredential {
        let nonce = UUID().uuidString
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = nonce

        let controller = ASAuthorizationController(authorizationRequests: [request])
        let coordinator = AppleAuthCoordinator()
        controller.delegate = coordinator
        controller.presentationContextProvider = coordinator
        return try await coordinator.run(controller: controller, nonce: nonce)
    }
}

/// Déclenche la requête et relaie le résultat par continuation. Retenu par la
/// trame `async` pendant toute la durée de la boîte de dialogue, comme
/// `GoogleAuthService` côté Google.
final class AppleAuthCoordinator: NSObject, ASAuthorizationControllerDelegate,
                                  ASAuthorizationControllerPresentationContextProviding {
    private var continuation: CheckedContinuation<AppleAuthCredential, Error>?
    private var controller: ASAuthorizationController?
    private var nonce = ""

    /// Lance `performRequests()` et suspend jusqu'au rappel du délégué.
    func run(controller: ASAuthorizationController, nonce: String) async throws -> AppleAuthCredential {
        self.controller = controller
        self.nonce = nonce
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            controller.performRequests()
        }
    }

    /// Fenêtre de présentation : la fenêtre clé de la scène active.
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return scenes.compactMap(\.keyWindow).first ?? UIWindow()
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let codeData = credential.authorizationCode,
              let tokenData = credential.identityToken,
              let code = String(data: codeData, encoding: .utf8),
              let token = String(data: tokenData, encoding: .utf8)
        else {
            finish(.failure(AppleAuthError.invalidIdentity("Apple n’a pas fourni de preuve de connexion.")))
            return
        }
        finish(.success(AppleAuthCredential(
            authorizationCode: code,
            identityToken: token,
            nonce: nonce,
            firstName: credential.fullName?.givenName,
            lastName: credential.fullName?.familyName
        )))
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        finish(.failure(AppleAuthError.from(error)))
    }

    /// Reprend la continuation une seule fois puis libère les références.
    private func finish(_ result: Result<AppleAuthCredential, Error>) {
        continuation?.resume(with: result)
        continuation = nil
        controller = nil
    }
}
#endif
