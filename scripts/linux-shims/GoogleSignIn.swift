// Shim de vérification Linux — NE FAIT PAS PARTIE DE L'APP.
//
// Le SDK GoogleSignIn (paquet externe Apple) n'existe pas sous Linux. Ce shim
// déclare le strict minimum utilisé par `Duello/GoogleAuth.swift` afin de
// pouvoir contrôler les types avec `swiftc`. Aucune méthode n'est exécutée.
import Foundation
import UIKit

public class GIDConfiguration: NSObject {
    public init(clientID: String, serverClientID: String) {
        super.init()
    }
}

public class GIDToken: NSObject {
    public var tokenString: String?
}

public class GIDGoogleUser: NSObject {
    public var idToken: GIDToken?
}

public class GIDSignInResult: NSObject {
    public var user: GIDGoogleUser = GIDGoogleUser()
}

public class GIDSignIn: NSObject {
    public static let sharedInstance = GIDSignIn()

    public var configuration: GIDConfiguration?
    public var currentUser: GIDGoogleUser?

    @discardableResult
    public func handle(_ url: URL) -> Bool { true }

    public func signIn(
        withPresenting presenting: UIViewController,
        completion: @escaping (GIDSignInResult?, Error?) -> Void
    ) {}

    public func restorePreviousSignIn(
        completion: @escaping (GIDGoogleUser?, Error?) -> Void
    ) {}
}
