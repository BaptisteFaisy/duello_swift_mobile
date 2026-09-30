//
//  OnbFlowSteps.swift
//  Duello
//
//  LOT 12-B — déroulé de l'inscription : les règles pures des étapes.
//
//  Fichiers source Expo portés :
//    - src/screens/OnboardingScreen.tsx (`validateStep`, `stepAdvanceBlocked`,
//      `continueButtonText`, `progressTrack` /
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

//  Écart assumé / à raccorder (29/09/2026, écart 05 #4) : le recentrage du
//  champ après fermeture d'une alerte (`focusPseudoInput` / `focusEmailInput`,
//  `OnboardingScreen.tsx:691-696,765,773,781,790`). Ce module porte la **cible
//  de focus** (`OnbFlowAlertAction.FocusTarget`) et le champ `focus` de
//  `OnbFlowAlertAction` ; le câblage du `@FocusState` (`OnbUiFields.swift`,
//  `OnbFlowView.perform`) et des alertes (`OnbFlowSteps+Alerts.swift`) reste à
//  raccorder — ces fichiers sont hors lot (voir rapport).

/// Bouton d'une alerte d'écran (`Alert.alert` de la source). Le titre porte
/// l'action, le genre dit quoi exécuter.
struct OnbFlowAlertAction: Identifiable, Equatable {
    enum Kind: Equatable {
        /// Ferme l'alerte (bouton « Compris » / « Plus tard »).
        case dismiss
        /// Relance la vérification de pré-vol (« Réessayer »).
        case retry
        /// Quitte le parcours (« Revenir à l'accueil »).
        case backToWelcome
        /// Ouvre les réglages système de l'app (« Ouvrir les réglages »).
        case openSettings
    }

    /// Champ à recentrer après la fermeture de l'alerte (`focusPseudoInput` /
    /// `focusEmailInput`). Lu par `OnbFlowView.perform` une fois le focus
    /// exposé par `OnbUiFieldProps`.
    enum FocusTarget: Equatable {
        case pseudo
        case email
    }

    let title: String
    var kind: Kind = .dismiss
    /// Bouton de style « annuler » (`style: 'cancel'` de la source).
    var isCancel: Bool = false
    /// Champ à recentrer à la fermeture (`focusPseudoInput`/`focusEmailInput`) :
    /// `nil` pour un bouton qui ne touche pas au focus.
    var focus: FocusTarget? = nil
    var id: String { title }
}

/// Message d'alerte de l'écran (`Alert.alert` de la source) : titre + corps.
struct OnbFlowAlert: Identifiable, Equatable {
    let title: String
    let message: String
    /// Boutons de l'alerte. Vide ⇒ un unique « OK » (défaut `Alert.alert`).
    var actions: [OnbFlowAlertAction] = []
    var id: String { "\(title)|\(message)" }
}

/// État lu par les règles de blocage d'avance (`stepAdvanceBlocked`).
///
/// Le précontrôle d'inscription (`ensureAccountRegistrationAvailable`) n'y
/// figure **plus** : depuis `871083903`, il tourne en tâche de fond et ne
/// verrouille jamais la navigation (`OnboardingScreen.tsx:384-393`).
struct OnbFlowGateState {
    var isCompleting = false
    var isCheckingRegistrationDetails = false
    var isCheckingUsername = false
    /// L'étape « TON NIVEAU » attend un choix explicite (`levelChoicePending`).
    var levelChoicePending = false
    /// L'étape « TON ANNÉE » attend un choix explicite (`yearChoicePending`).
    var yearChoicePending = false
    var trackChoicePending = false
    /// L'étape « TON PARCOURS » (PSI) attend un choix explicite (`originChoicePending`).
    var originChoicePending = false
    /// L'étape « option » attend un choix de niveau de maths (`mathOptionChoicePending`).
    var mathOptionChoicePending = false
    var premiumGiftOpenPending = false
}

/// État lu par la validation d'étape (`validateStep`).
struct OnbFlowValidationState {
    var step: OnbDataSteps.Step = .year
    var levelChoicePending = false
    var yearChoicePending = false
    var trackChoicePending = false
    var originChoicePending = false
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
    /// Titre de l'alerte de pré-vol d'inscription, dérivé du statut HTTP
    /// (`accountRegistrationAlertTitle(error)`, `utils/authHttpError.ts`) :
    /// 409 → « Création du compte impossible », sinon « Vérification de
    /// l'inscription impossible ».
    static func registrationAlertTitle(status: Int?) -> String {
        status == 409
            ? "Création du compte impossible"
            : "Vérification de l’inscription impossible"
    }

    /// Bouton « Compris » d'une alerte qui recentre un champ à sa fermeture
    /// (`focusPseudoInput` / `focusEmailInput`, `OnboardingScreen.tsx:765,773,
    /// 781,790`). À raccorder dans `OnbFlowSteps+Alerts.swift`.
    static func comprisAction(focus: OnbFlowAlertAction.FocusTarget) -> OnbFlowAlertAction {
        OnbFlowAlertAction(title: "Compris", focus: focus)
    }

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
    ///
    /// « Vérification… » n'est réservé qu'aux contrôles de l'étape courante
    /// (pseudo, inscription) : le précontrôle du montage, non bloquant, ne le
    /// déclenche plus (`OnboardingScreen.tsx:1704-1705`).
    static func continueLabel(step: Int, total: Int, gate: OnbFlowGateState) -> String {
        if gate.isCheckingRegistrationDetails || gate.isCheckingUsername {
            return "Vérification…"
        }
        if gate.isCompleting { return "Ouverture…" }
        if step >= total - 1 { return "Accéder à Duello" }
        if gate.premiumGiftOpenPending { return "Ouvre le cadeau" }
        if gate.trackChoicePending { return "Choisis ta filière" }
        if gate.mathOptionChoicePending { return "Choisis ton option" }
        return "Continuer"
    }

    /// `stepAdvanceBlocked` : l'avance est verrouillée tant qu'une vérification
    /// ou la création de compte est en cours, qu'un choix de programme
    /// (niveau, année, filière, parcours, option) n'est pas fait, ou que le
    /// cadeau n'est pas ouvert. Le précontrôle d'inscription, non bloquant, est
    /// **hors** de ce verrou (`OnboardingScreen.tsx:384-393`).
    static func advanceBlocked(_ state: OnbFlowGateState) -> Bool {
        state.isCompleting
            || state.isCheckingRegistrationDetails
            || state.isCheckingUsername
            || state.levelChoicePending
            || state.yearChoicePending
            || state.trackChoicePending
            || state.originChoicePending
            || state.mathOptionChoicePending
            || state.premiumGiftOpenPending
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

    /// `ensureAccountRegistrationAvailable` : pré-vol de création de compte.
    ///
    /// Deux appels dans la source, avec des arguments **différents** :
    ///  - au montage, **sans adresse** (`OnboardingScreen.tsx:331`
    ///    `ensureAccountRegistrationAvailable()`) ;
    ///  - à l'étape `auth-method`, avec l'adresse saisie
    ///    (`OnboardingScreen.tsx:913` `ensureAccountRegistrationAvailable(profile.email)`).
    ///
    /// Les boutons d'alerte diffèrent aussi : `Réessayer` (+ `Revenir à
    /// l'accueil` quand un `onCancel` existe) au montage, `Compris` à
    /// `auth-method` — d'où le paramètre `actions`.
    ///
    /// `nil` quand l'inscription reste possible (y compris verdict indécis,
    /// cf. `DevReg`).
    static func checkRegistrationPreflight(
        email: String?,
        actions: [OnbFlowAlertAction] = [OnbFlowAlertAction(title: "Compris")]
    ) async -> OnbFlowAlert? {
        do {
            _ = try await DevReg.registrationPreflight(
                deviceId: DevReg.registrationDeviceId(),
                email: email
            )
            return nil
        } catch {
            let status = (error as? DevRegPreflightError)?.status
            return OnbFlowAlert(
                title: registrationAlertTitle(status: status),
                message: (error as? LocalizedError)?.errorDescription
                    ?? "La création de compte est momentanément indisponible.",
                actions: actions
            )
        }
    }
}
