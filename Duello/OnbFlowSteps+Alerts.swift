import Foundation

// Alertes bloquantes des étapes d'onboarding (`validateStep` de
// `OnboardingScreen.tsx`). Scindé depuis `OnbFlowSteps.swift`
// (ratchet : ≤ 10 fonctions/fichier).

extension OnbFlowSteps {
    /// `validateStep` : l'alerte bloquante de l'étape courante, ou `nil`.
    static func validationAlert(_ state: OnbFlowValidationState) -> OnbFlowAlert? {
        switch state.step {
        case .level, .year, .origin:
            return programChoiceAlert(state)
        case .currentTrack:
            return currentTrackAlert(state)
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
                    message: "Choisis un pseudo unique de 1 à 24 caractères, sans espace, "
                        + "avec au moins une lettre ou un chiffre. Ponctuation autorisée : "
                        + ". _ - ! ( ) + , ; = ~ ^ $ et apostrophe.",
                    actions: [OnbFlowSteps.comprisAction(focus: .pseudo)]
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

    /// Étapes « TON NIVEAU », « TON ANNÉE » et « TON PARCOURS » : le choix
    /// explicite doit avoir été fait. Miroir de `validateStep`
    /// (`OnboardingScreen.tsx:710-731`) : « Niveau manquant », « Année
    /// manquante », « Parcours manquant ».
    private static func programChoiceAlert(_ state: OnbFlowValidationState) -> OnbFlowAlert? {
        switch state.step {
        case .level:
            guard state.levelChoicePending else { return nil }
            return OnbFlowAlert(
                title: "Niveau manquant",
                message: "Choisis ton niveau pour créer ton compte."
            )
        case .year:
            guard state.yearChoicePending else { return nil }
            return OnbFlowAlert(
                title: "Année manquante",
                message: "Choisis ton année pour créer ton compte."
            )
        case .origin:
            guard state.originChoicePending else { return nil }
            return OnbFlowAlert(
                title: "Parcours manquant",
                message: "Choisis ta filière de 1re année pour créer ton compte."
            )
        default:
            return nil
        }
    }

    /// Étape « TA FILIÈRE ACTUELLE » : une filière doit être choisie, le repli
    /// technique du profil ne valant jamais un choix.
    private static func currentTrackAlert(_ state: OnbFlowValidationState) -> OnbFlowAlert? {
        guard state.trackChoicePending else { return nil }
        return OnbFlowAlert(
            title: "Filière manquante",
            message: "Choisis ta filière pour créer ton compte."
        )
    }

    /// Contrôles d'e-mail de l'étape `auth-method`.
    private static func emailAlert(_ state: OnbFlowValidationState) -> OnbFlowAlert? {
        let email = state.email.trimmingCharacters(in: .whitespacesAndNewlines)
        if !OnbFlowCredentialsBuilder.isValidEmail(email) {
            return OnbFlowAlert(
                title: "E-mail invalide",
                message: "Saisis une adresse e-mail valide.",
                actions: [OnbFlowSteps.comprisAction(focus: .email)]
            )
        }
        if OnbFlowCredentialsBuilder.isReservedEmail(email) {
            return OnbFlowAlert(
                title: "Adresse réservée",
                message: "Cette adresse appartient au compte administrateur. "
                    + "Utilise l’écran de connexion.",
                actions: [OnbFlowSteps.comprisAction(focus: .email)]
            )
        }
        if let provider = state.providerEmail,
           provider.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() != email.lowercased() {
            return OnbFlowAlert(
                title: "Compte externe incohérent",
                message: "Recommence la connexion avec ton fournisseur afin de confirmer "
                    + "ton adresse e-mail.",
                actions: [OnbFlowSteps.comprisAction(focus: .email)]
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
}
