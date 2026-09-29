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
//  `dark` des briques `OnbUi` (`guest*` de la source) — sauf l'étape `origin`
//  et l'étape `target`, laissées claires par la source.
//
//  Écarts assumés (2026-09-29, écart 05#1) :
//   - `GoogleAuthButton` (Swift) ouvre la session : l'étape passe par
//     `GoogleAuthService` pour rendre la main au parcours ;
//   - le choix **explicite** de niveau/année/parcours de 1re année
//     (`onboardingRequiresExplicitChoice`, `OnboardingScreen.tsx:347-349`) est
//     porté **dans cette vue** : le coordinateur (`OnbFlowCoordinator.swift`)
//     est hors lot et ne peut recevoir ses propriétés stockées
//     `chosenLevel`/`chosenYear`/`chosenOrigin`. Les puces ne se cochent donc
//     qu'après un appui (aucune présélection sur build de développement), mais
//     le **verrou de l'étape** (`levelChoicePending`/`yearChoicePending`/
//     `originChoicePending` dans `OnbFlowGateState`/`advanceBlocked`) et les
//     **alertes** « Niveau/Année/Parcours manquant » restent à raccorder au
//     coordinateur (hunks décrits au rapport).
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

    /// `chosenLevel`/`chosenYear`/`chosenOrigin` (`OnboardingScreen.tsx:260-262`) :
    /// choix explicite, `nil` tant qu'aucune puce n'a été touchée. Portés ici
    /// faute de pouvoir les stocker dans le coordinateur (hors lot) ; ils sont
    /// réinitialisés quand le monde/l'année change, comme les helpers
    /// `chosenOnboarding*` (`academicPath.ts:368-405`).
    @State private var chosenLevel: String?
    @State private var chosenYear: String?
    @State private var chosenOrigin: String?

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

    // MARK: Choix explicite de programme (`onboardingRequiresExplicitChoice`)

    /// `onboardingRequiresExplicitChoice` (`OnboardingScreen.tsx:347-349`) : sur
    /// un build natif de développement (`Platform.OS !== 'web' && isDevelopmentBuild()`),
    /// aucun bouton de niveau/année/parcours n'est présélectionné. La production
    /// iOS garde le repli historique.
    private var onboardingRequiresExplicitChoice: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }

    /// `onboardingLevel` : le monde déduit du parcours.
    private var onboardingLevel: String { coordinator.isLyceeFlow ? "Lycée" : "Prépa" }

    /// `selectedOnboardingLevel` (`chosenOnboardingLevel`) : `nil` tant que le
    /// choix explicite ne correspond pas au monde courant.
    private var selectedOnboardingLevel: String? {
        guard let chosenLevel, chosenLevel == onboardingLevel else { return nil }
        return chosenLevel
    }

    /// `selectedOnboardingYear` (`chosenOnboardingYear`).
    private var selectedOnboardingYear: String? {
        guard let chosenYear, chosenYear == coordinator.profile.year else { return nil }
        return chosenYear
    }

    /// `selectedOnboardingOrigin` (`chosenOnboardingOrigin`).
    private var selectedOnboardingOrigin: String? {
        guard let chosenOrigin, chosenOrigin == coordinator.path.firstYearTrack else { return nil }
        return chosenOrigin
    }

    private func levelChipSelected(_ level: String) -> Bool {
        guard onboardingRequiresExplicitChoice else { return legacyLevelSelected(level) }
        return selectedOnboardingLevel == level
    }

    /// Repli historique (navigateur / production) : le monde du profil coche la puce.
    private func legacyLevelSelected(_ level: String) -> Bool {
        (level == "Lycée") == coordinator.isLyceeFlow
            && (coordinator.isLyceeFlow
                || OnbUiConstants.years.contains(coordinator.profile.year)
                || OnbFlowAcademic.lyceeYears.contains(coordinator.profile.year))
    }

    private func yearChipSelected(_ year: String) -> Bool {
        onboardingRequiresExplicitChoice
            ? selectedOnboardingYear == year
            : coordinator.profile.year == year
    }

    private func originChipSelected(_ track: String) -> Bool {
        onboardingRequiresExplicitChoice
            ? selectedOnboardingOrigin == track
            : coordinator.path.firstYearTrack == track
    }

    // MARK: Étapes de programme

    /// `level` : le monde scolaire (`ONBOARDING_LEVELS`), qui précède l'année.
    /// Sur un build de développement, aucune puce n'est présélectionnée
    /// (`onboardingRequiresExplicitChoice`) ; sinon la puce reste sélectionnée
    /// tant que l'année appartient au monde choisi
    /// (`(level === 'Lycée') === isLyceeFlow` et année connue de ce monde).
    /// Pastilles compactes côte à côte (pas pleine largeur) : la source ne
    /// passe pas `wide` (`OnboardingScreen.tsx:1196-1210`).
    private var levelStep: some View {
        // `choiceGrid` de la source : `flexDirection: 'row', flexWrap: 'wrap',
        // gap: 9` — comme les années, les mondes s'affichent côte à côte.
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 110))],
            alignment: .leading,
            spacing: 9
        ) {
            ForEach(OnbUiConstants.onboardingLevels, id: \.self) { level in
                OnbUiChoiceChip(
                    label: level,
                    isSelected: levelChipSelected(level),
                    action: {
                        chosenLevel = level
                        coordinator.chooseOnboardingLevel(level)
                    },
                    dark: true
                )
            }
        }
    }

    /// `year` : l'année du monde choisi sur « TON NIVEAU » (`yearChoices` :
    /// `LYCEE_YEARS` au lycée, `YEARS` en prépa).
    private var yearStep: some View {
        // `choiceGrid` de la source : `flexDirection: 'row', flexWrap: 'wrap',
        // gap: 9` — les années s'affichent côte à côte et passent à la ligne
        // au besoin (les puces `wide` des autres étapes restent en colonne).
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 110))],
            alignment: .leading,
            spacing: 9
        ) {
            ForEach(coordinator.yearChoices, id: \.self) { year in
                OnbUiChoiceChip(
                    label: year,
                    isSelected: yearChipSelected(year),
                    action: {
                        chosenYear = year
                        coordinator.chooseYear(year)
                    },
                    dark: true
                )
            }
        }
    }

    /// `current-track` : la filière actuelle (`onboardingCurrentTrackRows`).
    /// Les puces sont regroupées en lignes explicites (`ONBOARDING_CURRENT_TRACK_
    /// ROW_LAYOUT`), côte à côte comme les années — plus d'empilement pleine
    /// largeur.
    private var currentTrackStep: some View {
        OnbUiChoiceSection(dark: true) {
            // Filières indexées par position (robuste à tout doublon) ; la
            // source n'en renvoie plus depuis le retrait du doublon « PT »
            // (`V1`, écart 05#5). Seule la filière réellement choisie est
            // active : le repli du profil ne vaut pas un choix.
            VStack(alignment: .leading, spacing: 9) {
                ForEach(Array(coordinator.currentTrackRows.enumerated()), id: \.offset) { _, row in
                    HStack(spacing: 9) {
                        ForEach(Array(row.enumerated()), id: \.offset) { _, track in
                            OnbUiChoiceChip(
                                label: track,
                                isSelected: coordinator.selectedOnboardingTrack == track,
                                action: { coordinator.chooseCurrentTrack(track) },
                                dark: true
                            )
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    /// `origin` : la filière de 1re année (`originChoices`).
    private var originStep: some View {
        VStack(alignment: .leading, spacing: 19) {
            Text("Nous gardons cette information pour tes révisions et tes prérequis de concours.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.inkSoft)
            OnbUiChoiceSection(label: "Quelle filière suivais-tu en 1re année ?") {
                ForEach(coordinator.originChoices, id: \.self) { track in
                    OnbUiChoiceChip(
                        label: track,
                        isSelected: originChipSelected(track),
                        action: {
                            chosenOrigin = track
                            coordinator.chooseOrigin(track)
                        },
                        wide: true
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
    /// Pastilles compactes côte à côte : la source ne passe pas `wide` à cette
    /// étape (`OnboardingScreen.tsx:1279-1300`).
    private var optionsStep: some View {
        OnbUiChoiceSection(dark: true) {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 110))],
                alignment: .leading,
                spacing: 9
            ) {
                ForEach(coordinator.mathOptions) { option in
                    OnbUiChoiceChip(
                        label: option.label,
                        isSelected: coordinator.path.currentOption.hasPrefix(option.label),
                        action: { coordinator.chooseOption(option) },
                        dark: true
                    )
                }
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
        VStack(alignment: .leading, spacing: 19) {
            OnbFlowGoalIllustration()
            OnbUiField(props: OnbUiFieldProps(
                value: coordinator.profile.targetSchool,
                onChangeText: { value in
                    coordinator.profile.targetSchool = value
                    coordinator.schoolSuggestionsVisible =
                        !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                },
                placeholder: "Ex. HEC Paris, CentraleSupélec…",
                icon: "school-outline",
                onFocus: { coordinator.schoolSearchFocused = true },
                onBlur: { coordinator.schoolSearchFocused = false },
                dark: false
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
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
    }

    /// `identity` : le pseudo (`displayName`), unique dans l'app.
    private var identityStep: some View {
        VStack(alignment: .leading, spacing: 19) {
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
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
    }

    /// `auth-method` : e-mail, ou récapitulatif du fournisseur déjà connecté.
    private var authMethodStep: some View {
        VStack(alignment: .leading, spacing: 19) {
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
                    icon: "mail-outline",
                    keyboardType: .emailAddress,
                    autoCapitalize: .none,
                    dark: true,
                    whiteBorder: true
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
        VStack(alignment: .leading, spacing: 19) {
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
                        icon: "key-outline",
                        isSecure: !coordinator.showPassword,
                        dark: true,
                        whiteBorder: true
                    )
                ) {
                    Button {
                        coordinator.showPassword.toggle()
                    } label: {
                        IonIcon(
                            name: coordinator.showPassword ? "eye-off-outline" : "eye-outline",
                            size: 21,
                            color: .white
                        )
                        .frame(width: 36, height: 36)
                        .background(Color(hex: 0x262626))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
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
