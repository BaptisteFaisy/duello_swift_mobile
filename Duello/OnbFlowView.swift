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
            VStack(spacing: 0) {
                progressBar
                stepTransition
                footer
            }
            .background(Theme.background)

            if handoff.isActive {
                bloomLayer
                if handoff.isSurfaceVisible {
                    OnbFlowTrainingHandoffView(
                        programYear: EvEventAudience.programYear(of: coordinator.profile.year),
                        revealProgress: handoff.revealProgress
                    )
                    .transition(.opacity)
                }
            }
        }
        .onAppear {
            Task { @MainActor in await runPreflight() }
        }
        .onChange(of: coordinator.programSelectionComplete) { complete in
            if complete { onProgramSelected(coordinator.profile) }
        }
        .alert(
            coordinator.pendingAlert?.title ?? "",
            isPresented: alertPresented,
            presenting: coordinator.pendingAlert
        ) { _ in
            Button("OK", role: .cancel) {}
        } message: { alert in
            Text(alert.message)
        }
    }

    // MARK: Coquille

    /// `progressTrack` / `progressFill` : rail gris, remplissage vert.
    private var progressBar: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Rectangle().fill(Theme.surfaceMuted)
                Rectangle()
                    .fill(Theme.progress)
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
        .accessibilityElement()
        .accessibilityLabel("Progression")
        .accessibilityValue(Text("Étape \(coordinator.stepIndex + 1) sur \(coordinator.steps.count)"))
    }

    /// `OnboardingStepTransition` : balayage horizontal entre les étapes.
    private var stepTransition: some View {
        OnbGiftStepTransition(
            step: coordinator.stepIndex,
            onSwipeForward: canSwipeForward ? { Task { @MainActor in await advance() } } : nil,
            onSwipeBackward: canSwipeBackward ? { back() } : nil
        ) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    eyebrow
                    OnbFlowStepContent(
                        coordinator: coordinator,
                        onGoogle: handleGoogle,
                        onApple: handleApple,
                        onBiometric: handleBiometric
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 22)
                .padding(.vertical, 30)
            }
            .scrollDismissesKeyboard(coordinator.currentStep == .target ? .never : .interactively)
        }
    }

    /// Surtitre de l'étape (`STEP_COPY`).
    @ViewBuilder
    private var eyebrow: some View {
        if let text = OnbFlowSteps.eyebrow(for: coordinator.currentStep) {
            Text(text)
                .font(.system(size: 11, weight: .heavy))
                .tracking(1.5)
                .textCase(.uppercase)
                .foregroundStyle(Theme.ink)
        }
    }

    /// `footer` : retour discret + bouton principal.
    private var footer: some View {
        HStack(spacing: 11) {
            if coordinator.stepIndex > 0 || onCancel != nil {
                Button(action: back) {
                    HStack(spacing: 5) {
                        Image(systemName: "chevron.left")
                        Text("Retour")
                    }
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(Theme.inkSoft)
                    .frame(minHeight: 54)
                    .padding(.horizontal, 6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(coordinator.isCompleting)
                .accessibilityLabel(
                    coordinator.stepIndex > 0 ? "Étape précédente" : "Revenir à l’accueil"
                )
            }

            Button {
                Task { @MainActor in await advance() }
            } label: {
                HStack(spacing: 9) {
                    Text(coordinator.continueLabel)
                    Image(systemName: coordinator.isLastStep ? "checkmark" : "arrow.right")
                }
                .frame(maxWidth: .infinity, minHeight: 54)
            }
            .buttonStyle(DuelloPrimaryButton())
            .disabled(coordinator.advanceBlocked)
            .opacity(coordinator.advanceBlocked ? 0.45 : 1)
        }
        .padding(.horizontal, 22)
        .padding(.top, 13)
        .padding(.bottom, OnbUiConstants.onboardingFooterBottomPadding)
        .background(Theme.background)
        .overlay(alignment: .top) {
            Rectangle().fill(Theme.border).frame(height: 1)
        }
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

    private var alertPresented: Binding<Bool> {
        Binding(
            get: { coordinator.pendingAlert != nil },
            set: { if !$0 { coordinator.pendingAlert = nil } }
        )
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
            apple: coordinator.appleIdentity
        )
        await surface
        onTrainingSurfaceReady()
        await onComplete(profile, credentials)
    }

    // MARK: Fournisseurs et biométrie

    /// `authenticateWithGoogle` : fusionne l'identité et passe l'étape.
    private func handleGoogle(_ identity: GoogleIdentity) {
        coordinator.profile = OnbDataProviderAuth.googleProfile(
            coordinator.profile, identity: identity, mode: mode
        )
        coordinator.path = OnbFlowAcademic.normalizePath(coordinator.profile)
        coordinator.googleIdentity = identity
        coordinator.appleIdentity = nil
        coordinator.providerEmail = identity.email
        coordinator.providerName = "Google"
        coordinator.password = ""
        coordinator.biometricVerified = false
        advanceAfterProvider()
    }

    /// `authenticateWithApple` : symétrique de `handleGoogle`.
    private func handleApple(_ identity: AppleAuthIdentity) {
        coordinator.profile = OnbDataProviderAuth.appleProfile(
            coordinator.profile, identity: identity, mode: mode
        )
        coordinator.path = OnbFlowAcademic.normalizePath(coordinator.profile)
        coordinator.appleIdentity = identity
        coordinator.googleIdentity = nil
        coordinator.providerEmail = identity.email
        coordinator.providerName = "Apple"
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
