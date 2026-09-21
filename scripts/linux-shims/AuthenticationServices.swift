// Shim de vérification Linux — NE FAIT PAS PARTIE DE L'APP.
//
// `AuthenticationServices` n'existe pas sous Linux. Un seul appelant,
// `AppleAuthProvider.swift` (tout son corps est sous
// `#if canImport(AuthenticationServices)`, donc ACTIF dès que ce shim existe) :
// `ASAuthorizationAppleIDProvider`, `ASAuthorizationController`, ses deux
// protocoles de délégation, et `ASAuthorizationAppleIDCredential`.
//
// `ASPresentationAnchor` est bien `UIWindow` sur iOS : le typealias est réel.
import Foundation
import UIKit

public typealias ASPresentationAnchor = UIWindow

// MARK: - Portées demandées

public struct ASAuthorizationScope: Hashable, RawRepresentable, Sendable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }

    public static let fullName = ASAuthorizationScope(rawValue: "fullName")
    public static let email = ASAuthorizationScope(rawValue: "email")
}

// MARK: - Requêtes

open class ASAuthorizationRequest: NSObject {}

open class ASAuthorizationAppleIDRequest: ASAuthorizationRequest {
    public var requestedScopes: [ASAuthorizationScope] = []
    public var nonce: String?
    public var state: String?
}

open class ASAuthorizationAppleIDProvider: NSObject {
    public enum CredentialState: Int, Sendable {
        case authorized, revoked, notFound, transferred
    }

    public func createRequest() -> ASAuthorizationAppleIDRequest { ASAuthorizationAppleIDRequest() }
}

// MARK: - Résultat

public protocol ASAuthorizationCredential: NSObjectProtocol {}

open class ASAuthorizationAppleIDCredential: NSObject, ASAuthorizationCredential {
    public var authorizationCode: Data?
    public var identityToken: Data?
    public var fullName: PersonNameComponents?
    public var email: String?
    public var state: String?
    public var user: String = ""
}

open class ASAuthorization: NSObject {
    private final class _ShimCredential: NSObject, ASAuthorizationCredential {}

    public var credential: ASAuthorizationCredential { _ShimCredential() }
}

// MARK: - Contrôleur

public protocol ASAuthorizationControllerDelegate: NSObjectProtocol {
    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    )
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error)
}

public protocol ASAuthorizationControllerPresentationContextProviding: NSObjectProtocol {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor
}

open class ASAuthorizationController: NSObject {
    public init(authorizationRequests: [ASAuthorizationRequest]) { super.init() }

    public weak var delegate: ASAuthorizationControllerDelegate?
    public weak var presentationContextProvider: ASAuthorizationControllerPresentationContextProviding?

    public func performRequests() {}
}
