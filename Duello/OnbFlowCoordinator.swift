//
//  OnbFlowCoordinator.swift
//  Duello
//
//  LOT 12-B — déroulé de l'inscription : la machine à états du parcours.
//
//  Fichier source Expo porté : `src/screens/OnboardingScreen.tsx`
//  (état `useState` de l'écran, `chooseYear`, `chooseCurrentTrack`,
//  `chooseOrigin`, `setAcademicPath`, `advance`/`continueOnboarding` pour la
//  partie navigation, `goBack`, `updateProfile`).
//
//  Équivalent `ObservableObject` de l'écran à hooks, compatible iOS 16 (pas de
//  `@Observable`). La logique d'affichage reste dans `OnbFlowStepContent`, les
//  règles pures dans `OnbFlowSteps`, la passation dans `OnbFlowHandoff`.
//
//  Cible : iOS 16. Aucune dépendance externe.
//
import SwiftUI
import Combine

/// Avancement du pré-vol d'inscription (`registrationPreflightState`).
enum OnbFlowPreflightState: Equatable {
    case checking
    case ready
    case blocked
}

/// État et transitions du parcours d'inscription.
final class OnbFlowCoordinator: ObservableObject {
    let mode: OnbDataSteps.Mode
    /// `requiresRegistrationPreflight` : un vrai compte (hors invité) vérifie
    /// que l'inscription reste possible avant de proposer les identifiants.
    let requiresRegistrationPreflight: Bool

    @Published var stepIndex = 0
    @Published var profile: UserProfile
    @Published var path: OnbFlowAcademicPath
    @Published var password = ""
    @Published var showPassword = false
    @Published var biometricVerified = false
    @Published var premiumGiftOpened = false
    @Published var isCompleting = false
    @Published var isCheckingUsername = false
    @Published var isCheckingRegistrationDetails = false
    @Published var preflightState: OnbFlowPreflightState
    /// Vrai tant que les notifications ne sont pas explicitement refusées.
    @Published var pushNotificationsEnabled = true
    @Published var schoolSuggestionsVisible = false
    @Published var schoolSearchFocused = false
    @Published var pendingAlert: OnbFlowAlert?

    /// Identité de fournisseur retenue (Google ou Apple), si une connexion a eu
    /// lieu pendant le parcours.
    @Published var googleIdentity: GoogleIdentity?
    @Published var appleIdentity: AppleAuthIdentity?
    /// E-mail et nom du fournisseur, pour le bandeau de récapitulatif.
    @Published var providerEmail: String?
    @Published var providerName: String?

    init(mode: OnbDataSteps.Mode, initialProfile: UserProfile) {
        self.mode = mode
        self.requiresRegistrationPreflight = mode != .guest
        self.preflightState = mode != .guest ? .checking : .ready
        let path = OnbFlowAcademic.normalizePath(initialProfile)
        self.path = path
        self.profile = OnbFlowAcademic.synchronizedProfile(initialProfile, path: path)
    }

    // MARK: Dérivés

    /// Étapes réellement parcourues (`resolveOnboardingSteps`).
    var steps: [OnbDataSteps.Step] {
        OnbDataSteps.resolve(asksForMathOption: !mathOptions.isEmpty, mode: mode)
    }

    /// Étape courante, bornée comme la source (`steps[step] ?? last`).
    var currentStep: OnbDataSteps.Step {
        let list = steps
        guard !list.isEmpty else { return .ready }
        return list[min(stepIndex, list.count - 1)]
    }

    /// Options de maths de la filière courante (`onboardingMathOptionChoices`).
    var mathOptions: [OnbFlowOption] {
        OnbFlowAcademic.mathOptionChoices(currentTrack: path.currentTrack)
    }

    /// Filières proposées à l'étape « filière actuelle ». La source ne rend
    /// cliquables que les filières ECG pendant les essais d'onboarding
    /// (lignes 1087-1108) : le filtre est conservé ici.
    var visibleCurrentTracks: [String] {
        OnbFlowAcademic.currentTrackChoices(year: profile.year).filter { $0 == "ECG" }
    }

    /// `originChoices` de la filière courante.
    var originChoices: [String] {
        OnbFlowAcademic.originChoices(currentTrack: path.currentTrack)
    }

    /// Suggestions d'écoles (`schoolSuggestions`, `TARGET_SCHOOLS`).
    var schoolSuggestions: [String] {
        OnbDataTargetSchools.suggestions(
            for: path.currentTrack,
            query: profile.targetSchool
        )
    }

    /// Pseudo transmis aux boutons de fournisseur (`username`).
    var usernameHint: String? {
        AcctSecUsernameAvailability.isValid(profile.displayName)
            ? AcctSecUsernameAvailability.normalize(profile.displayName)
            : nil
    }

    /// `programSelectionComplete` : les choix de programme sont figés.
    var programSelectionComplete: Bool {
        let list = steps
        let last = max(
            list.firstIndex(of: .currentTrack) ?? -1,
            list.firstIndex(of: .options) ?? -1
        )
        return last < 0 || stepIndex > last
    }

    var isLastStep: Bool { stepIndex >= steps.count - 1 }

    var hasProviderIdentity: Bool { googleIdentity != nil || appleIdentity != nil }

    /// `premiumGiftOpenPending` : le cadeau doit être ouvert pour avancer.
    var premiumGiftOpenPending: Bool { currentStep == .premiumGift && !premiumGiftOpened }

    var gateState: OnbFlowGateState {
        OnbFlowGateState(
            isCompleting: isCompleting,
            isCheckingRegistrationDetails: isCheckingRegistrationDetails,
            isCheckingUsername: isCheckingUsername,
            premiumGiftOpenPending: premiumGiftOpenPending,
            preflightReady: preflightState == .ready,
            isCheckingPreflight: preflightState == .checking
        )
    }

    var validationState: OnbFlowValidationState {
        OnbFlowValidationState(
            step: currentStep,
            asksForMathOption: !mathOptions.isEmpty,
            currentOption: path.currentOption,
            targetSchool: profile.targetSchool,
            displayName: profile.displayName,
            email: profile.email,
            providerEmail: providerEmail,
            hasProviderIdentity: hasProviderIdentity,
            biometricVerified: biometricVerified,
            password: password
        )
    }

    var continueLabel: String {
        OnbFlowSteps.continueLabel(step: stepIndex, total: steps.count, gate: gateState)
    }

    var advanceBlocked: Bool { OnbFlowSteps.advanceBlocked(gateState) }

    // MARK: Transitions

    /// `setAcademicPath` : écrit le chemin puis reporte les champs historiques.
    func applyPath(_ next: OnbFlowAcademicPath) {
        path = next
        profile = OnbFlowAcademic.synchronizedProfile(profile, path: next)
    }

    /// `chooseYear` : change d'année et abandonne une filière devenue invalide.
    func chooseYear(_ year: String) {
        let choices = OnbFlowAcademic.currentTrackChoices(year: year)
        let kept = choices.contains(path.currentTrack) ? path.currentTrack : nil
        let currentTrack = kept ?? OnbFlowAcademic.fallbackTrack(year: year, previous: path.currentTrack)
        let options = OnbFlowAcademic.trackOptions[currentTrack] ?? []
        let currentOption = options.contains(path.currentOption) ? path.currentOption : ""
        profile.year = year
        profile.track = OnbFlowAcademic.programTrackFor(currentTrack)
        profile.specialty = currentOption
        applyPath(OnbFlowAcademic.normalizePath(profile))
    }

    /// `chooseCurrentTrack` : repart de l'origine et de l'option par défaut de
    /// la filière choisie.
    func chooseCurrentTrack(_ currentTrack: String) {
        let origins = OnbFlowAcademic.originChoices(currentTrack: currentTrack)
        let firstYearTrack = origins.contains(path.firstYearTrack)
            ? path.firstYearTrack
            : (origins.first ?? "")
        let currentOptions = OnbFlowAcademic.trackOptions[currentTrack] ?? []
        let firstYearOptions = OnbFlowAcademic.firstYearOptions[firstYearTrack] ?? []
        let currentOption = currentOptions.contains(path.currentOption)
            ? path.currentOption
            : (currentOptions.count == 1 ? currentOptions[0] : "")
        let firstYearOption = firstYearOptions.contains(path.firstYearOption)
            ? path.firstYearOption
            : (firstYearOptions.count == 1 ? firstYearOptions[0] : "")
        applyPath(OnbFlowAcademicPath(
            currentTrack: currentTrack,
            firstYearTrack: firstYearTrack,
            currentOption: currentOption,
            firstYearOption: firstYearOption
        ))
    }

    /// `chooseOrigin` : change l'origine en conservant une option valide.
    func chooseOrigin(_ firstYearTrack: String) {
        let options = OnbFlowAcademic.firstYearOptions[firstYearTrack] ?? []
        let firstYearOption = options.contains(path.firstYearOption)
            ? path.firstYearOption
            : (options.count == 1 ? options[0] : "")
        var next = path
        next.firstYearTrack = firstYearTrack
        next.firstYearOption = firstYearOption
        applyPath(next)
    }

    /// Étape « option » : l'option de maths (ECG). Elle complète aussi l'option
    /// de 1re année quand la filière est la même les deux années.
    func chooseOption(_ option: OnbFlowOption) {
        var next = path
        next.currentOption = option.value
        if profile.year == "1re année" || path.currentTrack == "ECG" {
            next.firstYearOption = option.value
        }
        applyPath(next)
    }

    /// `validateStep` : renvoie l'alerte bloquante, ou `nil` si l'étape passe.
    func validate() -> OnbFlowAlert? {
        if premiumGiftOpenPending {
            return OnbFlowAlert(
                title: "Cadeau non ouvert",
                message: "Touche le cadeau pour recevoir tes jours Premium offerts !"
            )
        }
        return OnbFlowSteps.validationAlert(validationState)
    }

    /// `continueOnboarding` : valide l'étape, lance les vérifications réseau
    /// propres à l'étape, puis avance. Ne fait rien sur la dernière étape : la
    /// complétion est orchestrée par la vue (`OnbFlowView`).
    func advance(token: String?) async {
        guard !advanceBlocked else { return }
        if let alert = validate() {
            pendingAlert = alert
            return
        }
        guard !isLastStep else { return }

        if currentStep == .identity, mode != .guest {
            isCheckingUsername = true
            let alert = await OnbFlowSteps.checkUsername(profile.displayName, token: token)
            isCheckingUsername = false
            if let alert {
                pendingAlert = alert
                return
            }
        }
        if currentStep == .authMethod, !hasProviderIdentity {
            isCheckingRegistrationDetails = true
            let alert = await OnbFlowSteps.checkRegistrationPreflight(email: profile.email)
            isCheckingRegistrationDetails = false
            if let alert {
                pendingAlert = alert
                return
            }
        }
        withAnimation(.easeInOut(duration: 0.2)) { stepIndex += 1 }
    }

    /// `goBack` : étape précédente, bloquée pendant la complétion.
    func goBack() {
        guard !isCompleting, stepIndex > 0 else { return }
        withAnimation(.easeInOut(duration: 0.2)) { stepIndex -= 1 }
    }
}
