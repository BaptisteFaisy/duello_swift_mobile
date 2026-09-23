//
//  OnbFlowCredentials.swift
//  Duello
//
//  LOT 12-B — déroulé de l'inscription : la création de compte.
//
//  Fichiers source Expo portés :
//    - src/screens/OnboardingScreen.tsx (`prepareOnboarding`, `validateStep`
//      pour les contrôles d'e-mail, `authenticateWithBiometrics`,
//      `requestOnboardingNotifications`, `offerLegacyAndroidNotifications`,
//      `pushNotificationsCanStayEnabled`)
//    - src/utils/auth.ts (`isAdminEmail`, `ADMIN_ACCOUNT_EMAIL`)
//    - shared/new-password-policy.mjs (`validNewPassword`) — réutilisé via
//      `AdmPasswordPolicy`, déjà porté
//
//  Réutilise sans le redéfinir `OnbUiCredentials` (`OnboardingCredentials`, lot
//  `OnbUi`).
//
//  La biométrie et les notifications sont natives côté Expo
//  (`expo-local-authentication`, `utils/pushNotifications`). Sur iOS elles
//  passent par `LocalAuthentication` et `UserNotifications` : les issues de la
//  source (validé / annulé / verrouillé, activé / refusé / indécis) sont
//  conservées, mais l'app ne prépare plus l'APNs côté serveur — la demande se
//  limite à l'autorisation système.
//
//  Cible : iOS 16. Aucune dépendance externe.
//
import Foundation
import LocalAuthentication
import UIKit
import UserNotifications

/// Finalisation du profil et des identifiants (`prepareOnboarding`).
enum OnbFlowCredentialsBuilder {
    /// Motif d'e-mail de la source : `/^\S+@\S+\.\S+$/`.
    static func isValidEmail(_ value: String) -> Bool {
        let email = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !email.isEmpty else { return false }
        return email.range(
            of: #"^\S+@\S+\.\S+$"#,
            options: [.regularExpression]
        ) != nil
    }

    /// `isAdminEmail` : adresse réservée au compte administrateur.
    ///
    /// La source lit `ADMIN_EMAILS` (`utils/accountIdentity.ts`) ; la même
    /// liste est déjà portée par `AppleAuthAccountResolver.adminEmails`.
    static let reservedAddresses: Set<String> = Set(AppleAuthAccountResolver.adminEmails)

    static func isReservedEmail(_ value: String) -> Bool {
        let email = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return reservedAddresses.contains(email)
    }

    /// `prepareOnboarding` : profil final. Hors invité, le pseudo est normalisé,
    /// l'e-mail mis en minuscules et les champs libres élagués.
    static func finalizedProfile(_ profile: UserProfile, mode: OnbDataSteps.Mode) -> UserProfile {
        guard mode != .guest else { return profile }
        var result = profile
        let username = AcctSecUsernameAvailability.normalize(profile.displayName)
        result.displayName = username
        result.firstName = username
        result.lastName = ""
        result.email = profile.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        result.targetSchool = profile.targetSchool.trimmingCharacters(in: .whitespacesAndNewlines)
        result.personalGoal = profile.personalGoal.trimmingCharacters(in: .whitespacesAndNewlines)
        return result
    }

    /// Construit les identifiants (`OnbUiCredentials` du lot `OnbUi`). Un
    /// fournisseur (Google / Apple) dispense de mot de passe et de biométrie,
    /// comme dans la source.
    static func credentials(
        password: String,
        biometricVerified: Bool,
        pushEnabled: Bool,
        google: GoogleIdentity?,
        apple: AppleAuthIdentity?,
        providerSession: DuelloAPI.SessionPayload? = nil
    ) -> OnbUiCredentials {
        let hasProvider = google != nil || apple != nil
        return OnbUiCredentials(
            password: hasProvider ? "" : password,
            biometricEnabled: hasProvider ? false : biometricVerified,
            pushNotificationsEnabled: pushEnabled,
            googleIdentity: google,
            appleIdentity: apple,
            providerSession: hasProvider ? providerSession : nil
        )
    }
}

/// `authenticateWithBiometrics` : vérification biométrique locale.
enum OnbFlowBiometric {
    /// Issue d'une tentative (`result.success`, `user_cancel`, `lockout`…).
    enum Outcome: Equatable {
        case verified
        case cancelled
        case failed
        case unavailable
    }

    /// `hasHardwareAsync` + `isEnrolledAsync` : la biométrie est-elle utilisable ?
    static func isAvailable() -> Bool {
        var error: NSError?
        let context = LAContext()
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }

    /// `authenticateAsync` : confirme l'identité, sans repli sur le code.
    static func verify(reason: String) async -> Outcome {
        let context = LAContext()
        context.localizedCancelTitle = "Annuler"
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return .unavailable
        }
        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )
            return success ? .verified : .failed
        } catch let laError as LAError {
            switch laError.code {
            case .userCancel, .systemCancel, .appCancel:
                return .cancelled
            case .biometryLockout, .biometryNotAvailable, .biometryNotEnrolled:
                return .unavailable
            default:
                return .failed
            }
        } catch {
            return .failed
        }
    }

    /// Message d'alerte associé à une issue, ou `nil` si rien ne doit s'afficher.
    static func alert(for outcome: Outcome) -> OnbFlowAlert? {
        switch outcome {
        case .verified, .cancelled:
            return nil
        case .unavailable:
            return OnbFlowAlert(
                title: "Biométrie indisponible",
                message: "Aucune empreinte ni reconnaissance faciale n’est configurée "
                    + "sur cet appareil. Tu peux utiliser le mot de passe de ton choix."
            )
        case .failed:
            return OnbFlowAlert(
                title: "Vérification biométrique impossible",
                message: "L’identité biométrique n’a pas pu être vérifiée. "
                    + "Réessaie ou choisis un mot de passe."
            )
        }
    }
}

/// `requestOnboardingNotifications` : autorisation de notification système.
enum OnbFlowPushNotifications {
    enum Status: Equatable {
        case enabled
        case denied
        case undetermined
    }

    /// Demande l'autorisation (popup système), une seule fois par parcours.
    static func request() async -> Status {
        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .badge, .sound])) ?? false
        return granted ? .enabled : .denied
    }

    /// État courant de l'autorisation, sans nouvelle demande.
    static func current() async -> Status {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return .enabled
        case .denied:
            return .denied
        default:
            return .undetermined
        }
    }

    /// Ouvre les réglages système de l'app (`openAppNotificationSettings`).
    @MainActor
    static func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
