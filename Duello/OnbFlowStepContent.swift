//
//  OnbFlowStepContent.swift
//  Duello
//
//  LOT 12-B — déroulé de l'inscription : le contenu de chaque étape.
//
//  Fichier source Expo porté : `src/screens/OnboardingScreen.tsx` (JSX des
//  étapes `year`, `current-track`, `origin`, `options`, `ready`, `premium-gift`,
//  `target`, `identity`, `auth-method`, `credentials`, lignes 1051-1428).
//
//  Réutilise sans les redéfinir :
//    - lot `OnbUi` : `OnbUiChoiceSection`, `OnbUiChoiceChip`, `OnbUiField`
//      (+ `OnbUiFieldProps`), `OnbUiProviderAccountSummary` ;
//    - lot cadeau : `OnbGiftMathProgressChart`, `OnbGiftStepView`,
//      `OnbGiftLegalNotice` ;
//    - kit partagé / données : `OnbUiConstants.years`, `OnbDataTargetSchools`,
//      `GoogleAuthService`, `AppleAuthView`, `OnbDataProviderAuth`.
//
//  ⚠️ Écarts assumés :
//   - la source force `usesDarkOnboardingAppearance = true` ; l'app Swift est
//     claire, le contenu reprend donc le thème clair (`dark` laissé à faux) ;
//   - `GoogleAuthButton` (Swift) ouvre la session : l'étape passe par
//     `GoogleAuthService` pour rendre la main au parcours.
//
//  Cible : iOS 16. Aucune dépendance externe.
//
import SwiftUI

/// Contenu de l'étape courante, aiguillé sur `OnbFlowCoordinator.currentStep`.
struct OnbFlowStepContent: View {
    @ObservedObject var coordinator: OnbFlowCoordinator
    var onGoogle: (GoogleIdentity) -> Void
    var onApple: (AppleAuthIdentity) -> Void
    var onBiometric: () -> Void

    var body: some View {
        Group {
            switch coordinator.currentStep {
            case .year: yearStep
            case .currentTrack: currentTrackStep
            case .origin: originStep
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

    /// `year` : l'année de prépa (`YEARS`).
    private var yearStep: some View {
        OnbUiChoiceSection {
            ForEach(OnbUiConstants.years, id: \.self) { year in
                OnbUiChoiceChip(
                    label: year,
                    isSelected: coordinator.profile.year == year
                ) {
                    coordinator.chooseYear(year)
                }
            }
        }
    }

    /// `current-track` : la filière actuelle (filtre « ECG seulement »).
    private var currentTrackStep: some View {
        OnbUiChoiceSection {
            ForEach(coordinator.visibleCurrentTracks, id: \.self) { track in
                OnbUiChoiceChip(
                    label: track,
                    isSelected: coordinator.path.currentTrack == track,
                    action: { coordinator.chooseCurrentTrack(track) },
                    wide: true
                )
            }
        }
    }

    /// `origin` : la filière de 1re année (`originChoices`).
    private var originStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Nous gardons cette information pour tes révisions et tes prérequis de concours.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.inkSoft)
            OnbUiChoiceSection(label: "Quelle filière suivais-tu en 1re année ?") {
                ForEach(coordinator.originChoices, id: \.self) { track in
                    OnbUiChoiceChip(
                        label: track,
                        isSelected: coordinator.path.firstYearTrack == track,
                        action: { coordinator.chooseOrigin(track) },
                        wide: true
                    )
                }
            }
        }
    }

    /// `options` : le niveau de mathématiques (`onboardingMathOptionChoices`).
    private var optionsStep: some View {
        OnbUiChoiceSection {
            ForEach(coordinator.mathOptions) { option in
                OnbUiChoiceChip(
                    label: option.label,
                    isSelected: coordinator.path.currentOption.hasPrefix(option.label),
                    action: { coordinator.chooseOption(option) },
                    wide: true
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
                icon: "school"
            ))
            if coordinator.schoolSuggestionsVisible, !coordinator.schoolSuggestions.isEmpty {
                OnbFlowSchoolSuggestions(schools: coordinator.schoolSuggestions) { school in
                    coordinator.profile.targetSchool = school
                    coordinator.schoolSuggestionsVisible = false
                }
            }
            Text("Tu peux aussi conserver le nom saisi s’il n’apparaît pas dans la liste.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.inkSoft)
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
                autoCapitalize: .none
            ))
            Text("Ton pseudo sera visible dans l’app et doit être unique.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.inkSoft)
        }
    }

    /// `auth-method` : e-mail, ou récapitulatif du fournisseur déjà connecté.
    private var authMethodStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let email = coordinator.providerEmail {
                OnbUiProviderAccountSummary(
                    email: email,
                    provider: coordinator.providerName == "Apple" ? .apple : .google
                )
            } else {
                OnbUiField(props: OnbUiFieldProps(
                    label: "ADRESSE E-MAIL",
                    value: coordinator.profile.email,
                    onChangeText: { coordinator.profile.email = $0 },
                    placeholder: "camille@email.fr",
                    icon: "mail",
                    keyboardType: .emailAddress,
                    autoCapitalize: .none
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
                    provider: coordinator.providerName == "Apple" ? .apple : .google
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
                        whiteBorder: false
                    )
                ) {
                    Button {
                        coordinator.showPassword.toggle()
                    } label: {
                        Image(systemName: coordinator.showPassword ? "eye.slash" : "eye")
                            .font(.system(size: 18))
                            .foregroundStyle(Theme.inkSoft)
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
