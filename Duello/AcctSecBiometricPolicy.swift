import Foundation
#if canImport(LocalAuthentication)
import LocalAuthentication
#endif

// Politique biométrique — portée depuis `src/utils/biometricPolicy.ts`
// (`canUseBiometricLogin`, `canOfferBiometricLogin`) et des appels à
// `expo-local-authentication` de `src/screens/LoginScreen.tsx`,
// `src/screens/AccountScreen.tsx` et `src/screens/OnboardingScreen.tsx`.
//
// L'accès à `LocalAuthentication` est isolé derrière `#if canImport(...)` :
// le module n'existe pas hors d'iOS, et les règles pures restent vérifiables
// partout. `disableDeviceFallback: true` côté Expo correspond ici au choix de
// la politique `.deviceOwnerAuthenticationWithBiometrics`, qui n'accepte
// jamais le code de déverrouillage de l'appareil.

/// Résultat d'un test de disponibilité biométrique, là où Expo distingue
/// `hasHardwareAsync()` et `isEnrolledAsync()`.
enum AcctSecBiometricAvailability: Equatable {
    case available
    case noHardware
    case notEnrolled
}

/// Résultat d'une demande d'authentification biométrique.
enum AcctSecBiometricOutcome: Equatable {
    case success
    case cancelled
    case lockout
    case failed
}

/// Règles d'accès biométrique : gardes pures d'un côté, accès isolé au module
/// natif de l'autre.
enum AcctSecBiometricPolicy {
    /// Message d'invitation de la connexion (voir `LoginScreen.tsx`).
    static let loginPrompt = "Se connecter à Duello"
    /// Message d'invitation de l'activation (voir `AccountScreen.tsx`).
    static let activationPrompt = "Activer la connexion biométrique"
    /// Sous-titre commun des deux feuilles système.
    static let promptSubtitle = "Confirme ton identité"
    /// Libellé du bouton d'annulation.
    static let cancelLabel = "Annuler"

    /// La biométrie ne doit jamais ouvrir la surface d'administration.
    static func canUseBiometricLogin(_ account: AcctSecAccount?) -> Bool {
        guard let account else { return false }
        return account.role == .user && account.biometricEnabled
    }

    /// Les quatre conditions communes aux deux pages de connexion, pour
    /// qu'aucune ne propose la biométrie à un compte administrateur ou en
    /// cours de réinitialisation.
    static func canOfferBiometricLogin(
        _ account: AcctSecAccount?,
        isResetting: Bool,
        isAdminActivation: Bool,
        isSelectedAdmin: Bool
    ) -> Bool {
        !isResetting && !isAdminActivation && !isSelectedAdmin && canUseBiometricLogin(account)
    }

    /// La biométrie est-elle utilisable sur cet appareil ?
    static func availability() -> AcctSecBiometricAvailability {
        #if canImport(LocalAuthentication)
        let context = LAContext()
        var error: NSError?
        let canEvaluate = context.canEvaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            error: &error
        )
        _ = error
        if context.biometryType == .none { return .noHardware }
        return canEvaluate ? .available : .notEnrolled
        #else
        // Hors d'iOS, aucun module natif : la biométrie reste indisponible.
        return .noHardware
        #endif
    }

    /// Demande une vérification biométrique. Le repli sur le code de
    /// l'appareil est désactivé, comme `disableDeviceFallback: true` côté Expo.
    static func authenticate(prompt: String) async -> AcctSecBiometricOutcome {
        #if canImport(LocalAuthentication)
        let context = LAContext()
        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: prompt
            )
            return success ? .success : .failed
        } catch {
            return outcome(for: error)
        }
        #else
        _ = prompt
        return .failed
        #endif
    }

    #if canImport(LocalAuthentication)
    /// Traduit `LAError` en issue exploitable, en ignorant les annulations :
    /// aucune erreur n'est affichée quand l'utilisateur renonce, comme dans
    /// `LoginScreen.tsx` (`user_cancel`, `system_cancel`, `app_cancel`).
    private static func outcome(for error: Error) -> AcctSecBiometricOutcome {
        guard let laError = error as? LAError else { return .failed }
        switch laError.code {
        case .userCancel, .systemCancel, .appCancel:
            return .cancelled
        case .biometryLockout:
            return .lockout
        default:
            return .failed
        }
    }
    #endif
}
