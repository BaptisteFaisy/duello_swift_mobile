//
//  OnbFlowStepContent.swift
//  Duello
//
//  LOT 12-B — déroulé de l'inscription : le contenu de chaque étape.
//
//  Fichier source Expo porté : `src/screens/OnboardingScreen.tsx` (JSX des
//  étapes `level`, `year`, `current-track`, `origin`, `specialty`, `options`,
//  `ready`, `premium-gift`, `target`, `identity`, `auth-method`, `credentials`,
//  lignes 1051-1428).
//
//  Réutilise sans les redéfinir :
//    - lot `OnbUi` : `OnbUiChoiceSection`, `OnbUiChoiceChip`, `OnbUiField`
//      (+ `OnbUiFieldProps`), `OnbUiProviderAccountSummary` ;
//    - lot cadeau : `OnbGiftMathProgressChart`, `OnbGiftStepView`,
//      `OnbGiftLegalNotice` ;
//    - kit partagé / données : `OnbUiConstants.years`, `OnbDataTargetSchools`,
//      `GoogleAuthService`, `AppleAuthView`, `OnbDataProviderAuth`.
//
//  Thème : la source force `usesDarkOnboardingAppearance = true`
//  (`OnboardingScreen.tsx:251`) ; le contenu reprend donc les variantes
//  `dark` des briques `OnbUi` (`guest*` de la source).
//
//  ⚠️ Écart assumé :
//   - `GoogleAuthButton` (Swift) ouvre la session : l'étape passe par
//     `GoogleAuthService` pour rendre la main au parcours.
//
//  Cible : iOS 16. Aucune dépendance externe.
//
import SwiftUI

/// Contenu de l'étape courante, aiguillé sur `OnbFlowCoordinator.currentStep`.
struct OnbFlowStepContent: View {
    @ObservedObject var coordinator: OnbFlowCoordinator
    var onGoogle: (GoogleIdentity, DuelloAPI.SessionPayload) -> Void
    var onApple: (AppleAuthIdentity, DuelloAPI.SessionPayload) -> Void
    var onBiometric: () -> Void

    var body: some View {
        Group {
            switch coordinator.currentStep {
            case .level: levelStep
            case .year: yearStep
            case .currentTrack: currentTrackStep
            case .origin: originStep
            case .specialty: specialtyStep
            case .options: optionsStep
            case .ready: OnbGiftMathProgressChart()
            case .premiumGift: premiumGiftStep
            case .target: targetStep
            case .identity: identityStep
            case .authMethod: authMethodStep
            case .credentials: credentialsStep
            }
        }
    }

    // MARK: Étapes de programme

    /// `level` : le monde scolaire (`ONBOARDING_LEVELS`), qui précède l'année.
    /// La puce reste sélectionnée tant que l'année appartient au monde choisi
    /// (`(level === 'Lycée') === isLyceeFlow` et année connue de ce monde).
    private var levelStep: some View {
        OnbUiChoiceSection(dark: true) {
            ForEach(OnbUiConstants.onboardingLevels, id: \.self) { level in
                OnbUiChoiceChip(
                    label: level,
                    isSelected: (level == "Lycée") == coordinator.isLyceeFlow
                        && (coordinator.isLyceeFlow
                            || OnbUiConstants.years.contains(coordinator.profile.year)
                            || OnbFlowAcademic.lyceeYears.contains(coordinator.profile.year)),
                    action: { coordinator.chooseOnboardingLevel(level) },
                    wide: true,
                    dark: true
                )
            }
        }
    }

    /// `year` : l'année du monde choisi sur « TON NIVEAU » (`yearChoices` :
    /// `LYCEE_YEARS` au lycée, `YEARS` en prépa).
    private var yearStep: some View {
        OnbUiChoiceSection(dark: true) {
            ForEach(coordinator.yearChoices, id: \.self) { year in
                OnbUiChoiceChip(
                    label: year,
                    isSelected: coordinator.profile.year == year,
                    action: { coordinator.chooseYear(year) },
                    dark: true
                )
            }
        }
    }

    /// `current-track` : la filière actuelle (`onboardingCurrentTrackChoices`).
    private var currentTrackStep: some View {
        OnbUiChoiceSection(dark: true) {
            ForEach(coordinator.currentTrackChoices, id: \.self) { track in
                OnbUiChoiceChip(
                    label: track,
                    isSelected: coordinator.path.currentTrack == track,
                    action: { coordinator.chooseCurrentTrack(track) },
                    wide: true,
                    dark: true
                )
            }
        }
    }

    /// `origin` : la filière de 1re année (`originChoices`).
    private var originStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Nous gardons cette information pour tes révisions et tes prérequis de concours.")
                .font(.system(size: 13))
                .foregroundStyle(OnbFlowPalette.helper)
            OnbUiChoiceSection(label: "Quelle filière suivais-tu en 1re année ?", dark: true) {
                ForEach(coordinator.originChoices, id: \.self) { track in
                    OnbUiChoiceChip(
                        label: track,
                        isSelected: coordinator.path.firstYearTrack == track,
                        action: { coordinator.chooseOrigin(track) },
                        wide: true,
                        dark: true
                    )
                }
            }
        }
    }

    /// `specialty` : la spécialité du lycée (`onboardingSpecialtyChoices`) —
    /// paire de spécialités en 1re, option de mathématiques en terminale. La
    /// page n'existe pas en 2de (aucun choix).
    private var specialtyStep: some View {
        OnbUiChoiceSection(dark: true) {
            ForEach(coordinator.lyceeSpecialtyChoices) { choice in
                OnbUiChoiceChip(
                    label: choice.label,
                    isSelected: coordinator.path.currentOption == choice.value,
                    action: { coordinator.chooseLyceeSpecialty(choice.value) },
                    wide: true,
                    dark: true
                )
            }
        }
    }

    /// `options` : le niveau de mathématiques (`onboardingMathOptionChoices`).
    private var optionsStep: some View {
        OnbUiChoiceSection(dark: true) {
            ForEach(coordinator.mathOptions) { option in
                OnbUiChoiceChip(
                    label: option.label,
                    isSelected: coordinator.path.currentOption.hasPrefix(option.label),
                    action: { coordinator.chooseOption(option) },
                    wide: true,
                    dark: true
                )
            }
        }
    }

    /// `premium-gift` : le cadeau Premium, qui doit être ouvert pour avancer.
    private var premiumGiftStep: some View {
        OnbGiftStepView(opened: coordinator.premiumGiftOpened) {
            coordinator.premiumGiftOpened = true
        }
    }

    // MARK: Étapes de compte

    /// `target` : l'école visée, avec suggestions (`TARGET_SCHOOLS`).
    private var targetStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            OnbFlowGoalIllustration()
            OnbUiField(props: OnbUiFieldProps(
                value: coordinator.profile.targetSchool,
                onChangeText: { value in
                    coordinator.profile.targetSchool = value
                    coordinator.schoolSuggestionsVisible =
                        !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                },
                placeholder: "Ex. HEC Paris, CentraleSupélec…",
                icon: "school",
                dark: true
            ))
            if coordinator.schoolSuggestionsVisible, !coordinator.schoolSuggestions.isEmpty {
                OnbFlowSchoolSuggestions(schools: coordinator.schoolSuggestions) { school in
                    coordinator.profile.targetSchool = school
                    coordinator.schoolSuggestionsVisible = false
                }
            }
            Text("Tu peux aussi conserver le nom saisi s’il n’apparaît pas dans la liste.")
                .font(.system(size: 12))
                .foregroundStyle(OnbFlowPalette.helper)
        }
    }

    /// `identity` : le pseudo (`displayName`), unique dans l'app.
    private var identityStep: some View {
        VStack(alignment: .leading, spacing: 8) {
            OnbUiField(props: OnbUiFieldProps(
                label: "PSEUDO",
                value: coordinator.profile.displayName,
                onChangeText: { value in
                    coordinator.profile.displayName = value
                    coordinator.profile.firstName = value
                    coordinator.profile.lastName = ""
                },
                placeholder: "Ex. Camille75",
                autoCapitalize: .none,
                dark: true
            ))
            Text("Ton pseudo sera visible dans l’app et doit être unique.")
                .font(.system(size: 12))
                .foregroundStyle(OnbFlowPalette.helper)
        }
    }

    /// `auth-method` : e-mail, ou récapitulatif du fournisseur déjà connecté.
    private var authMethodStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let email = coordinator.providerEmail {
                OnbUiProviderAccountSummary(
                    email: email,
                    provider: coordinator.providerName == "Apple" ? .apple : .google,
                    dark: true
                )
            } else {
                OnbUiField(props: OnbUiFieldProps(
                    label: "ADRESSE E-MAIL",
                    value: coordinator.profile.email,
                    onChangeText: { coordinator.profile.email = $0 },
                    placeholder: "camille@email.fr",
                    icon: "mail",
                    keyboardType: .emailAddress,
                    autoCapitalize: .none,
                    dark: true
                ))
            }
            OnbFlowProviderButtons(
                username: coordinator.usernameHint,
                onGoogle: onGoogle,
                onApple: onApple
            )
        }
    }

    /// `credentials` : mot de passe ou biométrie, puis mentions légales.
    private var credentialsStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let email = coordinator.providerEmail {
                OnbUiProviderAccountSummary(
                    email: email,
                    provider: coordinator.providerName == "Apple" ? .apple : .google,
                    dark: true
                )
            } else {
                OnbUiField(
                    props: OnbUiFieldProps(
                        label: "MOT DE PASSE",
                        value: coordinator.password,
                        onChangeText: { value in
                            coordinator.password = value
                            // Une saisie annule une biométrie déjà validée (source).
                            if !value.isEmpty { coordinator.biometricVerified = false }
                        },
                        placeholder: "",
                        icon: "key",
                        isSecure: !coordinator.showPassword,
                        dark: true,
                        whiteBorder: false
                    )
                ) {
                    Button {
                        coordinator.showPassword.toggle()
                    } label: {
                        Image(systemName: coordinator.showPassword ? "eye.slash" : "eye")
                            .font(.system(size: 18))
                            .foregroundStyle(OnbFlowPalette.helper)
                            .frame(width: 36, height: 36)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(
                        coordinator.showPassword ? "Masquer le mot de passe" : "Afficher le mot de passe"
                    )
                }
                OnbFlowDivider()
                OnbFlowBiometricButton(
                    verified: coordinator.biometricVerified,
                    action: onBiometric
                )
            }
            OnbGiftLegalNotice()
        }
    }
}
