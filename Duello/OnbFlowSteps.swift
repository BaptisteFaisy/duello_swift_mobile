//
//  OnbFlowSteps.swift
//  Duello
//
//  LOT 12-B — déroulé de l'inscription : les règles pures des étapes.
//
//  Fichiers source Expo portés :
//    - src/screens/OnboardingScreen.tsx (`validateStep`, `stepAdvanceBlocked`,
//      `registrationPreflightState`, `continueButtonText`, `progressTrack` /
//      `progressFill`, `ensureUsernameAvailable` + `usernameAvailabilityAlertTitle`,
//      `ensureAccountRegistrationAvailable` + `accountRegistrationAlertTitle`)
//    - src/utils/onboardingSteps.ts (`STEP_COPY`, via `OnbDataSteps`)
//
//  Ce module ne garde que des règles sans état ; l'état vit dans
//  `OnbFlowCoordinator`, l'affichage dans `OnbFlowStepContent`.
//
//  Cible : iOS 16. Aucune dépendance externe.
//
import Foundation

/// Message d'alerte de l'écran (`Alert.alert` de la source) : titre + corps.
struct OnbFlowAlert: Identifiable, Equatable {
    let title: String
    let message: String
    var id: String { "\(title)|\(message)" }
}

/// État lu par les règles de blocage d'avance (`stepAdvanceBlocked`).
struct OnbFlowGateState {
    var isCompleting = false
    var isCheckingRegistrationDetails = false
    var isCheckingUsername = false
    var premiumGiftOpenPending = false
    var preflightReady = true
    var isCheckingPreflight = false
}

/// État lu par la validation d'étape (`validateStep`).
struct OnbFlowValidationState {
    var step: OnbDataSteps.Step = .year
    var asksForMathOption = false
    var currentOption = ""
    var targetSchool = ""
    var displayName = ""
    var email = ""
    var providerEmail: String? = nil
    var hasProviderIdentity = false
    var biometricVerified = false
    var password = ""
    /// Vrai dans l'app de bureau téléchargée (`isDownloadedDesktopApp`) : la
    /// politique de mot de passe y est réduite à un caractère. Faux sur iOS.
    var isDesktopApp = false
}

/// Règles pures des étapes d'inscription (`OnboardingScreen.tsx`).
enum OnbFlowSteps {
    /// Titre de l'alerte de pré-vol d'inscription. La source le dérive de
    /// `accountRegistrationAlertTitle(error)` (`utils/accountRegistration.ts`) :
    /// ce helper n'est pas porté côté Swift, le titre est donc fixé ici.
    static let registrationAlertTitle = "Création de compte indisponible"

    /// Surtitre d'étape (`STEP_COPY`), délégué au module d'étapes déjà porté.
    static func eyebrow(for step: OnbDataSteps.Step) -> String? {
        OnbDataSteps.eyebrow(for: step)
    }

    /// Part remplie de la barre de progression : `(step + 1) / steps.length`.
    static func progressFraction(step: Int, total: Int) -> Double {
        guard total > 0 else { return 0 }
        return Double(min(max(step, 0), total - 1) + 1) / Double(total)
    }

    /// Libellé du bouton principal (`continueButtonText`).
    static func continueLabel(step: Int, total: Int, gate: OnbFlowGateState) -> String {
        if gate.isCheckingRegistrationDetails || gate.isCheckingUsername || gate.isCheckingPreflight {
            return "Vérification…"
        }
        if gate.isCompleting { return "Ouverture…" }
        if step >= total - 1 { return "Accéder à Duello" }
        if gate.premiumGiftOpenPending { return "Ouvre le cadeau" }
        return "Continuer"
    }

    /// `stepAdvanceBlocked` : l'avance est verrouillée tant qu'une vérification
    /// ou la création de compte est en cours, ou que le cadeau n'est pas ouvert.
    static func advanceBlocked(_ state: OnbFlowGateState) -> Bool {
        state.isCompleting
            || state.isCheckingRegistrationDetails
            || state.isCheckingUsername
            || state.premiumGiftOpenPending
            || !state.preflightReady
    }

    /// `validateStep` : l'alerte bloquante de l'étape courante, ou `nil`.
    static func validationAlert(_ state: OnbFlowValidationState) -> OnbFlowAlert? {
        switch state.step {
        case .specialty:
            // Étape du monde lycée : la spécialité (ou l'option de terminale)
            // est obligatoire, indépendamment du drapeau d'option de la source.
            if state.currentOption.isEmpty {
                return OnbFlowAlert(
                    title: "Spécialité manquante",
                    message: "Choisis la spécialité que tu suis."
                )
            }
        case .options:
            if state.asksForMathOption && state.currentOption.isEmpty {
                return OnbFlowAlert(
                    title: "Option manquante",
                    message: "Choisis l’option que tu suis actuellement."
                )
            }
        case .target:
            if state.targetSchool.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return OnbFlowAlert(
                    title: "École manquante",
                    message: "Indique l’école que tu souhaites intégrer."
                )
            }
        case .identity:
            if !AcctSecUsernameAvailability.isValid(state.displayName) {
                return OnbFlowAlert(
                    title: "Pseudo invalide",
                    message: "Choisis un pseudo unique de 3 à 24 caractères, sans espace. "
                        + "Tu peux utiliser des lettres, des chiffres, des points, des tirets "
                        + "et des tirets bas."
                )
            }
        case .authMethod:
            return emailAlert(state)
        case .credentials:
            return credentialsAlert(state)
        default:
            break
        }
        return nil
    }

    /// Contrôles d'e-mail de l'étape `auth-method`.
    private static func emailAlert(_ state: OnbFlowValidationState) -> OnbFlowAlert? {
        let email = state.email.trimmingCharacters(in: .whitespacesAndNewlines)
        if !OnbFlowCredentialsBuilder.isValidEmail(email) {
            return OnbFlowAlert(title: "E-mail invalide", message: "Saisis une adresse e-mail valide.")
        }
        if OnbFlowCredentialsBuilder.isReservedEmail(email) {
            return OnbFlowAlert(
                title: "Adresse réservée",
                message: "Cette adresse appartient au compte administrateur. "
                    + "Utilise l’écran de connexion."
            )
        }
        if let provider = state.providerEmail,
           provider.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() != email.lowercased() {
            return OnbFlowAlert(
                title: "Compte externe incohérent",
                message: "Recommence la connexion avec ton fournisseur afin de confirmer "
                    + "ton adresse e-mail."
            )
        }
        return nil
    }

    /// Contrôle de mot de passe de l'étape `credentials` : un fournisseur ou la
    /// biométrie dispense de mot de passe.
    private static func credentialsAlert(_ state: OnbFlowValidationState) -> OnbFlowAlert? {
        if state.hasProviderIdentity || state.biometricVerified { return nil }
        let valid = state.isDesktopApp
            ? !state.password.isEmpty
            : AdmPasswordPolicy.isValid(state.password)
        guard !valid else { return nil }
        let message = state.isDesktopApp
            ? "Choisis un mot de passe d’au moins un caractère."
            : "\(AdmPasswordPolicy.message) Tu peux aussi utiliser la biométrie."
        return OnbFlowAlert(title: "Mot de passe invalide", message: message)
    }

    /// `ensureUsernameAvailable` : vérifie qu'un pseudo est libre avant de
    /// quitter l'étape `identity`. `nil` quand le pseudo est disponible.
    static func checkUsername(_ displayName: String, token: String?) async -> OnbFlowAlert? {
        do {
            _ = try await AcctSecUsernameAvailability.ensureAvailable(displayName, token: token)
            return nil
        } catch {
            return OnbFlowAlert(
                title: AcctSecUsernameAvailability.alertTitle(for: error),
                message: (error as? LocalizedError)?.errorDescription
                    ?? "Impossible de vérifier ce pseudo pour le moment."
            )
        }
    }

    /// `ensureAccountRegistrationAvailable` : pré-vol de création de compte
    /// avant de quitter l'étape `auth-method`. `nil` quand l'inscription reste
    /// possible (y compris verdict indécis, cf. `DevReg`).
    static func checkRegistrationPreflight(email: String) async -> OnbFlowAlert? {
        do {
            _ = try await DevReg.registrationPreflight(
                deviceId: DevReg.registrationDeviceId(),
                email: email
            )
            return nil
        } catch {
            return OnbFlowAlert(
                title: registrationAlertTitle,
                message: (error as? LocalizedError)?.errorDescription
                    ?? "La création de compte est momentanément indisponible."
            )
        }
    }
}
