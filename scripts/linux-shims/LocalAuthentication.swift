// Shim de vérification Linux — NE FAIT PAS PARTIE DE L'APP.
//
// `LocalAuthentication` n'existe pas sous Linux. Couvre les deux appelants
// (`OnbFlowCredentials.swift`, `AcctSecBiometricPolicy.swift`) : `LAContext`,
// `LAPolicy`, `LABiometryType` et `LAError.Code`.
import Foundation

public enum LAPolicy: Int, Sendable {
    case deviceOwnerAuthenticationWithBiometrics = 1
    case deviceOwnerAuthentication = 2
}

public enum LABiometryType: Int, Sendable {
    case none = 0
    case touchID = 1
    case faceID = 2
    case opticID = 4
}

/// `LAError` : vrai type ponté `NSError` ; ici une erreur Swift portant le code.
public struct LAError: Error {
    public struct Code: RawRepresentable, Equatable, Sendable {
        public let rawValue: Int
        public init(rawValue: Int) { self.rawValue = rawValue }

        public static let authenticationFailed = Code(rawValue: -1)
        public static let userCancel = Code(rawValue: -2)
        public static let userFallback = Code(rawValue: -3)
        public static let systemCancel = Code(rawValue: -4)
        public static let passcodeNotSet = Code(rawValue: -5)
        public static let biometryNotAvailable = Code(rawValue: -6)
        public static let biometryNotEnrolled = Code(rawValue: -7)
        public static let biometryLockout = Code(rawValue: -8)
        public static let appCancel = Code(rawValue: -9)
        public static let invalidContext = Code(rawValue: -10)
        public static let notInteractive = Code(rawValue: -1004)
    }

    public let code: Code
    public init(code: Code) { self.code = code }
}

open class LAContext: NSObject {
    public var localizedCancelTitle: String?
    public var localizedFallbackTitle: String?
    public var localizedReason: String?
    public var biometryType: LABiometryType = .none

    // `NSErrorPointer` (= `AutoreleasingUnsafeMutablePointer<NSError?>?`) n'est
    // pas exporté par Foundation sous Linux : on accepte un pointeur inout
    // ordinaire, ce qui laisse `&error` (avec `var error: NSError?`) fonctionner.
    public func canEvaluatePolicy(
        _ policy: LAPolicy,
        error: UnsafeMutablePointer<NSError?>?
    ) -> Bool { false }

    public func evaluatePolicy(_ policy: LAPolicy, localizedReason: String) async throws -> Bool {
        false
    }
}
