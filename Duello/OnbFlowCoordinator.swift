//
//  OnbFlowCoordinator.swift
//  Duello
//
//  LOT 12-B — déroulé de l'inscription : la machine à états du parcours.
//
//  Fichier source Expo porté : `src/screens/OnboardingScreen.tsx`
//  (état `useState` de l'écran, `chooseYear`, `chooseOnboardingLevel`,
//  `chooseCurrentTrack`, `chooseOrigin`, `chooseLyceeSpecialty`,
//  `setAcademicPath`, `advance`/`continueOnboarding` pour la partie navigation,
//  `goBack`, `updateProfile`).
//
//  Monde lycée (lot « onb-lycee-rn », 2026-09-23) : `isLyceeFlow`, `yearChoices`,
//  `lyceeSpecialtyChoices`, `asksForMathOption` et `asksForOrigin` reproduisent
//  les dérivés de l'écran (lignes 253-286).
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
    /// Session serveur ouverte par le fournisseur pendant le parcours.
    ///
    /// Absente de la source, qui laisse l'application ouvrir le compte
    /// (`onGoogleAuthenticated` → `authenticateWithGoogle`, `App.tsx`) : ici la
    /// session est rendue avec l'identité par le bouton, puis mémorisée.
    @Published var providerSession: DuelloAPI.SessionPayload?

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
        OnbDataSteps.resolve(
            asksForMathOption: asksForMathOption,
            asksForOrigin: asksForOrigin,
            isLyceeTrack: isLyceeFlow,
            mode: mode
        )
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

    /// `isLyceeFlow` : le parcours lycée remplace filière/option par niveau
    /// puis spécialité (`isLyceeTrack(academicPath.currentTrack)`).
    var isLyceeFlow: Bool { OnbFlowAcademic.isLyceeTrack(path.currentTrack) }

    /// `onboardingSpecialtyChoices(profile.year)` : choix de la page
    /// « TA SPÉCIALITÉ » (vide en 2de, où la page n'existe pas).
    var lyceeSpecialtyChoices: [OnbFlowOption] {
        OnbFlowAcademic.lyceeSpecialtyChoices(year: profile.year)
    }

    /// `asksForMathOption` : la prépa n'a pas de page niveau, son drapeau
    /// d'option reste celui de la filière ; le lycée demande une spécialité dès
    /// que le niveau en propose une.
    var asksForMathOption: Bool {
        isLyceeFlow ? !lyceeSpecialtyChoices.isEmpty : !mathOptions.isEmpty
    }

    /// `asksForOrigin` : un PSI vient de quatre filières de 1re année
    /// possibles, son parcours précédent est demandé sur une page dédiée.
    var asksForOrigin: Bool { !isLyceeFlow && path.currentTrack == "PSI" }

    /// `yearChoices` : la page « TON ANNÉE » ne montre que les années du monde
    /// choisi sur « TON NIVEAU ».
    var yearChoices: [String] {
        isLyceeFlow ? OnbFlowAcademic.lyceeYears : OnbUiConstants.years
    }

    /// `onboardingCurrentTrackChoices(profile.year)` : filières proposées à
    /// l'étape « filière actuelle » — toutes celles de l'année.
    ///
    /// Correction de fidélité (lot « onb-lycee-rn », 2026-09-23) : le port ne
    /// proposait que `ECG`, au motif de « lignes 1087-1108 » de la source qui
    /// ne rendraient cliquables que les filières ECG. Vérifié sur la source
    /// courante (`OnboardingScreen.tsx:1189`) : la page liste
    /// `onboardingCurrentTrackChoices(profile.year)` **sans filtre** — MPSI,
    /// MP2I, PCSI, PTSI, BCPST, B/L, ECG en 1re année, MP, MPI, PC, PT, PSI,
    /// BCPST, B/L, ECG en 2e. Sans cette correction, la page « origine » d'un
    /// PSI (2e année) restait inatteignable.
    var currentTrackChoices: [String] {
        OnbFlowAcademic.currentTrackChoices(year: profile.year)
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

    /// `programSelectionComplete` : les choix de programme sont figés
    /// (`lastProgramSelectionStep` : filière, origine, spécialité ou option).
    var programSelectionComplete: Bool {
        let list = steps
        let last = max(
            max(
                list.firstIndex(of: .currentTrack) ?? -1,
                list.firstIndex(of: .origin) ?? -1
            ),
            max(
                list.firstIndex(of: .specialty) ?? -1,
                list.firstIndex(of: .options) ?? -1
            )
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
            asksForMathOption: asksForMathOption,
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

    /// `chooseOnboardingLevel` : le monde choisi sur « TON NIVEAU » repart d'une
    /// année par défaut propre — la dernière du lycée (Terminale), la première
    /// de prépa (1re année).
    func chooseOnboardingLevel(_ level: String) {
        chooseYear(level == "Lycée" ? "Terminale" : "1re année")
    }

    /// `chooseYear` : change d'année et abandonne une filière devenue invalide.
    /// Un changement de monde (lycée <-> prépa) repart du monde choisi ; au
    /// lycée, une spécialité absente du nouveau niveau est vidée (une paire de
    /// 1re n'est pas une option de terminale).
    func chooseYear(_ year: String) {
        let choices = OnbFlowAcademic.currentTrackChoices(year: year)
        let kept = choices.contains(path.currentTrack) ? path.currentTrack : nil
        let currentTrack = kept ?? OnbFlowAcademic.fallbackTrack(year: year, previous: path.currentTrack)
        let options = OnbFlowAcademic.trackOptions[currentTrack] ?? []
        let chosenOption = options.contains(path.currentOption) ? path.currentOption : ""
        let currentOption =
            OnbFlowAcademic.isLyceeYear(year)
                && !OnbFlowAcademic.lyceeSpecialtyChoices(year: year)
                    .contains { $0.value == chosenOption }
            ? ""
            : chosenOption
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

    /// `chooseLyceeSpecialty` : la spécialité pilote directement le programme
    /// lycée — elle occupe les deux emplacements d'option du parcours.
    func chooseLyceeSpecialty(_ specialty: String) {
        var next = path
        next.currentOption = specialty
        next.firstYearOption = specialty
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
