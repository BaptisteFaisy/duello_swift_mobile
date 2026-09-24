//
//  OnbFlowView.swift
//  Duello
//
//  LOT 12-B — déroulé de l'inscription : le conteneur du parcours.
//
//  Fichier source Expo porté : `src/screens/OnboardingScreen.tsx` (la coquille
//  de l'écran : `SafeAreaView`, barre de progression, `OnboardingStepTransition`,
//  `ScrollView` des étapes, `footer` avec retour + bouton principal, et
//  l'orchestration de `continueOnboarding` : préchauffage, halo, préparation du
//  compte).
//
//  Découpe : ce fichier ne porte que la coquille et l'enchaînement ; l'état est
//  dans `OnbFlowCoordinator`, le contenu dans `OnbFlowStepContent`, la passation
//  dans `OnbFlowHandoff`.
//
//  Cible : iOS 16. Aucune dépendance externe.
//
import SwiftUI

/// Parcours d'inscription complet : étapes, transitions et passation vers
/// l'entraînement. Remplace, sans le modifier, `OnboardingView` (qui ne couvre
/// que les étapes de programme en thème clair).
struct OnbFlowView: View {
    let mode: OnbDataSteps.Mode
    /// Appelée à la complétion, avec le profil final et les identifiants
    /// (`OnbUiCredentials`, lot `OnbUi`).
    var onComplete: (UserProfile, OnbUiCredentials) async -> Void
    /// Appelée dès que les choix de programme sont figés (`onProgramSelected`).
    var onProgramSelected: (UserProfile) -> Void
    /// Appelée quand la surface d'entraînement peut être évaluée.
    var onTrainingSurfaceReady: () -> Void
    /// `onCancel` : retour à l'accueil depuis la première étape.
    var onCancel: (() -> Void)?

    @EnvironmentObject private var session: SessionStore
    @StateObject private var coordinator: OnbFlowCoordinator
    @StateObject private var handoff = OnbFlowHandoffDriver()

    init(
        mode: OnbDataSteps.Mode,
        initialProfile: UserProfile,
        onComplete: @escaping (UserProfile, OnbUiCredentials) async -> Void,
        onProgramSelected: @escaping (UserProfile) -> Void = { _ in },
        onTrainingSurfaceReady: @escaping () -> Void = {},
        onCancel: (() -> Void)? = nil
    ) {
        self.mode = mode
        self.onComplete = onComplete
        self.onProgramSelected = onProgramSelected
        self.onTrainingSurfaceReady = onTrainingSurfaceReady
        self.onCancel = onCancel
        _coordinator = StateObject(
            wrappedValue: OnbFlowCoordinator(mode: mode, initialProfile: initialProfile)
        )
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // La source **remplace** tout l'écran dès que la surface
            // d'entraînement devient visible (`if (trainingHandoffVisible)`) :
            // le parcours disparaît derrière elle.
            if !handoff.isSurfaceVisible {
                VStack(spacing: 0) {
                    topBar
                    progressBar
                    stepTransition
                    footer
                }
                .background(OnbFlowPalette.background)
            }

            if handoff.isActive {
                bloomLayer
                if handoff.isSurfaceVisible {
                    OnbFlowTrainingHandoffView(
                        programYear: EvEventAudienceFilter.programYear(of: coordinator.profile.year),
                        revealProgress: handoff.revealProgress
                    )
                    .transition(.opacity)
                }
            }
        }
        // Fond hors zone sûre : noir pendant le parcours (`guestSafeArea`),
        // blanc pendant la passation (`trainingHandoffSafeArea`,
        // `colors.background`) — le fond noir du parcours ne couvrait pas la
        // barre d'état, faute de `ignoresSafeArea`.
        .background(
            (handoff.isSurfaceVisible ? Theme.background : OnbFlowPalette.background)
                .ignoresSafeArea()
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Parcours de bienvenue")
        .onAppear {
            Task { @MainActor in await runPreflight() }
        }
        .onChange(of: coordinator.programSelectionComplete) { complete in
            if complete { onProgramSelected(coordinator.profile) }
        }
        // La source présente **toutes** ses alertes par la fenêtre commune
        // (`AppAlert`, montée une fois à la racine via `.appAlertHost()`) —
        // jamais par `.alert` natif (`import { AppAlert as Alert }`).
        // `OnbFlowCoordinator.pendingAlert` porte le contenu ; on le relaie à la
        // file partagée puis on vide l'état, pour que la même alerte puisse être
        // rejouée (même relais que `LoginScrLayout`).
        .onChange(of: coordinator.pendingAlert) { alert in
            guard let alert else { return }
            coordinator.pendingAlert = nil
            present(alert)
        }
    }

    // MARK: Coquille

    /// `progressTrack` / `progressFill`, variante `guest*` : rail `#242424`,
    /// remplissage blanc (`OnboardingScreen.tsx:1858-1859`).
    private var progressBar: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Rectangle().fill(OnbFlowPalette.progressTrack)
                RoundedRectangle(cornerRadius: 2)
                    .fill(OnbFlowPalette.progressFill)
                    .frame(
                        width: proxy.size.width
                            * OnbFlowSteps.progressFraction(
                                step: coordinator.stepIndex,
                                total: coordinator.steps.count
                            )
                    )
            }
        }
        .frame(height: 4)
    }

    /// `OnboardingStepTransition` : balayage horizontal entre les étapes.
    private var stepTransition: some View {
        OnbGiftStepTransition(
            step: coordinator.stepIndex,
            onSwipeForward: canSwipeForward ? { Task { @MainActor in await advance() } } : nil,
            onSwipeBackward: canSwipeBackward ? { back() } : nil
        ) {
            GeometryReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        eyebrow
                        OnbFlowStepContent(
                            coordinator: coordinator,
                            onGoogle: handleGoogle,
                            onApple: handleApple,
                            onBiometric: handleBiometric
                        )
                        .padding(.top, stepTopInset)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 30)
                    // `scrollContent` centre verticalement le bloc ; l'étape
                    // `target` recentrée sur la saisie le colle en haut
                    // (`schoolSearchScrollContent` : `justifyContent:
                    // 'flex-start'`).
                    .frame(
                        minHeight: proxy.size.height,
                        alignment: coordinator.currentStep == .target && coordinator.schoolSearchFocused
                            ? .top
                            : .center
                    )
                    .padding(
                        .bottom,
                        coordinator.currentStep == .target && coordinator.schoolSearchFocused ? 280 : 0
                    )
                }
                .scrollDismissesKeyboard(
                    coordinator.schoolSearchFocused || coordinator.currentStep == .target
                        ? .never
                        : .interactively
                )
            }
        }
    }

    /// Surtitre de l'étape (`STEP_COPY`).
    @ViewBuilder
    private var eyebrow: some View {
        if let text = OnbFlowSteps.eyebrow(for: coordinator.currentStep) {
            Text(text)
                .font(.system(size: 11, weight: .black))
                .tracking(1.5)
                .textCase(.uppercase)
                .foregroundStyle(OnbFlowPalette.onDark)
        }
    }

    /// Marge haute du formulaire d'étape (`styles.form.marginTop: 24`).
    ///
    /// Toutes les étapes enveloppées dans un formulaire portent cette marge ;
    /// `ready` et `premium-gift` n'en ont pas (la source ne les enveloppe pas).
    /// Le contenu étant centré verticalement, la marge décale le bloc de
    /// `24 / 2 = 12` pt vers le bas. Quand l'étape a un surtitre, l'écart de
    /// 24 pt est déjà porté par le `VStack` : la marge ne s'ajoute pas.
    private var stepTopInset: CGFloat {
        switch coordinator.currentStep {
        case .ready, .premiumGift:
            return 0
        default:
            return OnbFlowSteps.eyebrow(for: coordinator.currentStep) == nil ? 24 : 0
        }
    }

    /// `footer` : bouton principal seul.
    private var footer: some View {
        Group {
            // `{!premiumGiftOpenPending && (…)}` : sur l'étape cadeau, le bouton
            // principal n'est pas rendu tant que le cadeau n'est pas ouvert.
            if !coordinator.premiumGiftOpenPending {
                Button {
                    Task { @MainActor in await advance() }
                } label: {
                    HStack(spacing: 9) {
                        Text(coordinator.continueLabel)
                        Image(systemName: coordinator.isLastStep ? "checkmark" : "arrow.right")
                            .font(.system(size: 20))
                    }
                    .frame(maxWidth: .infinity, minHeight: 54)
                }
                // `continueButton` : rayon 18 (`radii.large`), libellé 15/900 —
                // le défaut de graisse de `DuelloPrimaryButton` est déjà `.black`
                // (900) ; seul le rayon (14 par défaut) doit être passé.
                .buttonStyle(DuelloPrimaryButton(onDark: true, radius: 18))
                .disabled(coordinator.advanceBlocked)
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 13)
        .padding(.bottom, OnbUiConstants.onboardingFooterBottomPadding)
        .background(OnbFlowPalette.background)
    }

    /// `topBar` : retour en haut à gauche (`guestTopBackButton`).
    ///
    /// En thème sombre, la source **retire le retour du pied de page** et le
    /// place ici (`{!usesDarkOnboardingAppearance && (step > 0 || onCancel)}`,
    /// `OnboardingScreen.tsx:1544-1555`) : c'est le seul retour du parcours.
    private var topBar: some View {
        HStack(spacing: 0) {
            // Retour : composant partagé `DuelloBackButton` (`BackButton.tsx`) —
            // chevron 24 blanc, boîte 40×40 et `translateX(-4)` portés par le
            // composant. Le style d'écran n'ajoute que la marge
            // `guestTopBackButton` (`marginLeft: -8`), pour un décalage total
            // de −12 comme la source.
            DuelloBackButton(
                iconColor: OnbFlowPalette.onDark,
                iconSize: 24,
                isDisabled: coordinator.isCompleting,
                accessibilityLabel: coordinator.stepIndex > 0
                    ? "Étape précédente"
                    : "Revenir à l’accueil",
                action: back
            )
            .padding(.leading, -8)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 22)
        .padding(.top, 0)
        .padding(.bottom, 12)
    }

    /// Le halo de passation, centré sur le bouton principal.
    private var bloomLayer: some View {
        GeometryReader { proxy in
            let bottomInset = proxy.safeAreaInsets.bottom
            OnbFlowTrainingBloom(
                progress: handoff.bloomProgress,
                fullScale: OnbFlowHandoff.bloomScale(
                    viewport: proxy.size,
                    bottomSafeArea: bottomInset
                ),
                centerFromBottom: OnbFlowHandoff.centerFromBottom(bottomSafeArea: bottomInset)
            )
        }
        .ignoresSafeArea()
    }

    // MARK: Navigation

    private var canSwipeForward: Bool {
        coordinator.stepIndex < coordinator.steps.count - 1 && !coordinator.advanceBlocked
    }

    private var canSwipeBackward: Bool {
        coordinator.stepIndex > 0 && !coordinator.isCompleting
    }

    /// `AppAlert.alert` : traduit l'alerte d'étape (modèle `OnbFlowAlert`) en
    /// boutons de la fenêtre commune. Sans action, la file pose le bouton unique
    /// « Compris » (`AppAlertCenter`, défaut `AppAlert.alert`), comme la source ;
    /// `style: 'cancel'` devient `.cancel`, tout le reste `.default`.
    private func present(_ alert: OnbFlowAlert) {
        let buttons = alert.actions.map { action in
            AppAlertButton(action.title, style: action.isCancel ? .cancel : .default) {
                perform(action)
            }
        }
        AppAlert.alert(alert.title, alert.message, buttons.isEmpty ? nil : buttons)
    }

    /// Exécute l'action choisie. La fenêtre commune s'est déjà refermée
    /// (`AppAlertCenter`) ; on garantit seulement que l'état local est vide.
    private func perform(_ action: OnbFlowAlertAction) {
        coordinator.pendingAlert = nil
        switch action.kind {
        case .retry:
            Task { @MainActor in await runPreflight() }
        case .backToWelcome:
            onCancel?()
        case .openSettings:
            OnbFlowPushNotifications.openSettings()
        case .dismiss:
            break
        }
    }

    /// `continueOnboarding` : avance d'une étape, ou clôt le parcours.
    private func advance() async {
        if coordinator.isLastStep {
            await complete()
        } else {
            await coordinator.advance(token: session.token)
        }
    }

    /// `goBack`, ou `onCancel` depuis la première étape.
    private func back() {
        if coordinator.stepIndex > 0 {
            coordinator.goBack()
        } else {
            onCancel?()
        }
    }

    // MARK: Vérifications et complétion

    /// `ensureAccountRegistrationAvailable` au montage (`registrationPreflightState`).
    private func runPreflight() async {
        guard coordinator.requiresRegistrationPreflight else {
            coordinator.preflightState = .ready
            return
        }
        coordinator.preflightState = .checking
        if let alert = await OnbFlowSteps.checkRegistrationPreflight(email: coordinator.profile.email) {
            coordinator.preflightState = .blocked
            coordinator.pendingAlert = alert
        } else {
            coordinator.preflightState = .ready
        }
    }

    /// Dernier « Continuer » : préchauffage, halo, préparation du compte.
    private func complete() async {
        guard !coordinator.isCompleting else { return }
        coordinator.isCompleting = true

        // La popup système part avec la transition et ne bloque pas la complétion.
        Task { @MainActor in
            let status = await OnbFlowPushNotifications.request()
            coordinator.pushNotificationsEnabled = status != .denied
            // Alerte de rattrapage quand l'autorisation est refusée.
            if status == .denied {
                coordinator.pendingAlert = OnbFlowAlert(
                    title: "Notifications désactivées",
                    message: "Ton téléphone les refuse actuellement. Autorise-les dans les "
                        + "réglages, puis reviens dans Duello.",
                    actions: [
                        OnbFlowAlertAction(title: "Plus tard", isCancel: true),
                        OnbFlowAlertAction(title: "Ouvrir les réglages", kind: .openSettings),
                    ]
                )
            }
        }

        // Le module Entraînement s'évalue derrière le halo, en parallèle de la
        // préparation du compte.
        async let surface: Void = handoff.start()
        let profile = OnbFlowCredentialsBuilder.finalizedProfile(coordinator.profile, mode: mode)
        let credentials = OnbFlowCredentialsBuilder.credentials(
            password: coordinator.password,
            biometricVerified: coordinator.biometricVerified,
            pushEnabled: coordinator.pushNotificationsEnabled,
            google: coordinator.googleIdentity,
            apple: coordinator.appleIdentity,
            providerSession: coordinator.providerSession
        )
        await surface
        onTrainingSurfaceReady()
        await onComplete(profile, credentials)
    }

    // MARK: Fournisseurs et biométrie

    /// `authenticateWithGoogle` : fusionne l'identité et passe l'étape.
    private func handleGoogle(_ identity: GoogleIdentity, payload: DuelloAPI.SessionPayload) {
        coordinator.profile = OnbDataProviderAuth.googleProfile(
            coordinator.profile, identity: identity, mode: mode
        )
        coordinator.path = OnbFlowAcademic.normalizePath(coordinator.profile)
        coordinator.googleIdentity = identity
        coordinator.appleIdentity = nil
        coordinator.providerEmail = identity.email
        coordinator.providerName = "Google"
        coordinator.providerSession = payload
        coordinator.password = ""
        coordinator.biometricVerified = false
        advanceAfterProvider()
    }

    /// `authenticateWithApple` : symétrique de `handleGoogle`.
    private func handleApple(_ identity: AppleAuthIdentity, payload: DuelloAPI.SessionPayload) {
        coordinator.profile = OnbDataProviderAuth.appleProfile(
            coordinator.profile, identity: identity, mode: mode
        )
        coordinator.path = OnbFlowAcademic.normalizePath(coordinator.profile)
        coordinator.appleIdentity = identity
        coordinator.googleIdentity = nil
        coordinator.providerEmail = identity.email
        coordinator.providerName = "Apple"
        coordinator.providerSession = payload
        coordinator.password = ""
        coordinator.biometricVerified = false
        advanceAfterProvider()
    }

    /// Une connexion fournisseur fait avancer sans second appui (source).
    private func advanceAfterProvider() {
        withAnimation(.easeInOut(duration: 0.2)) {
            coordinator.stepIndex = min(coordinator.stepIndex + 1, coordinator.steps.count - 1)
        }
    }

    /// `authenticateWithBiometrics` : validé ⇒ avance, sinon alerte.
    private func handleBiometric() {
        Task { @MainActor in
            let outcome = await OnbFlowBiometric.verify(reason: "Créer mon compte Duello")
            if outcome == .verified {
                coordinator.biometricVerified = true
                coordinator.password = ""
                await advance()
            } else if let alert = OnbFlowBiometric.alert(for: outcome) {
                coordinator.pendingAlert = alert
            }
        }
    }
}

/// Palette du parcours d'inscription.
///
/// La source force le thème sombre (`usesDarkOnboardingAppearance = true`,
/// `OnboardingScreen.tsx:251`, en dur) : ce sont les styles `guest*` qui
/// s'appliquent — fond noir, rail `#242424`, remplissage et surtitre blancs,
/// bouton principal blanc sur texte noir.
enum OnbFlowPalette {
    /// `guestSafeArea` / `guestScrollContent` / `guestFooter` : `#000000`.
    static let background = Color.black
    /// `guestProgressTrack` : `#242424`.
    static let progressTrack = Color(hex: 0x242424)
    /// `guestProgressFill` : blanc.
    static let progressFill = Color.white
    /// `guestEyebrow` : blanc.
    static let onDark = Color.white
    /// `guestHelperText` : `#B8B8B8`.
    static let helper = Color(hex: 0xB8B8B8)
    /// `guestAuthDividerLine` : `#343434`.
    static let divider = Color(hex: 0x343434)
    /// `guestAuthDividerText` : `#8A8A8A`.
    static let dividerText = Color(hex: 0x8A8A8A)
    /// `guestFieldShell` : bordure `#3A3A3A`, fond `#111111`.
    static let fieldBorder = Color(hex: 0x3A3A3A)
    static let fieldSurface = Color(hex: 0x111111)
}
