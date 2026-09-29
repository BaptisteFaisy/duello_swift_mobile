//
//  OnboardingView.swift
//  Duello
//
//  LOT 19 — intégration de l'inscription.
//
//  `OnboardingView` devient l'hôte du parcours d'inscription complet porté au
//  lot 12-B (`OnbFlowView`) : coquille, transitions et enchaînement des étapes
//  `origin`, `target`, `identity`, `auth-method`, `credentials`, `premium-gift`
//  — auparavant absentes (la vue ne couvrait que année / filière / option /
//  prêt).
//
//  Fichier source Expo porté : `src/screens/OnboardingScreen.tsx` (2 051 l.),
//  via la machine à états `OnbFlow*` (coordonnateur, étapes, contenu,
//  commandes, identifiants, passation) et les briques `OnbUi*` / `OnbGift*` /
//  `OnbData*`. Aucun de ces modules n'est modifié : cette vue ne fait que les
//  brancher.
//
//  Contrat préservé : `OnboardingView { onFinish }` reste instanciable à
//  l'identique (`Duello/DuelloApp.swift:41`). `onFinish` demeure le dernier
//  paramètre ; `mode` est un réglage **optionnel** (défaut `.account`, la
//  valeur par défaut de l'écran Expo).
//
//  ⚠️ Écarts / limites assumés (aucune correction possible dans ce lot, les
//  fichiers concernés étant hors périmètre) :
//   - la filière « actuelle » expose toutes celles de l'année
//     (`OnbFlowCoordinator.currentTrackChoices`), comme la source ; le lycée
//     passe par les pages « niveau » puis « spécialité » ;
//   - le pré-vol d'inscription (`OnbFlowSteps.checkRegistrationPreflight`)
//     n'est joué que pour un parcours **sans session** (`SignupFlowView`) : il
//     est désactivé quand la session est déjà ouverte, puisque ce parcours
//     complète un profil sans créer de compte (sinon le serveur répond 409
//     « Un compte existe déjà avec cette adresse e-mail » et l'avance reste
//     bloquée) ;
//   - les identifiants collectés (mot de passe, biométrie, fournisseur) ne sont
//     pas transmis au serveur ici : seul le profil local est écrit à la
//     complétion.
//
//  V2 (29/09/2026, parité RN dev) : les deux hôtes fournissent à `OnbFlowView`
//  `onProgramSelected` (`prepareOnboardingProgram`, `App.tsx:763`),
//  `onTrainingSurfaceReady` et les identités fournisseur initiales
//  (`App.tsx:2508-2521`). Écart assumé iOS : `onTrainingSurfaceReady`
//  (`loadTrainingScreenAfterFirstPaint`) ne fait rien — il ne servait qu'à
//  charger à la demande le module Entraînement, sans équivalent natif.
//
//  R02 (29/09/2026) : l'identité fournisseur retenue par `LoginIntAssembly`
//  (`LoginIntPendingProviderSignup`) porte désormais ses libellés de nom et la
//  session serveur — `SignupFlowView` amorce donc de vraies identités et
//  `OnbFlowCoordinator` sème le profil/l'e-mail du fournisseur au montage.
//
//  Cible : iOS 16. Aucune dépendance externe.
//
import SwiftUI

/// Hôte du parcours d'inscription : enveloppe `OnbFlowView` et raccorde sa
/// complétion à la session locale, sans changer la signature attendue par
/// `DuelloApp`.
struct OnboardingView: View {
    /// Appelée une fois le parcours terminé et le profil écrit.
    let onFinish: () -> Void

    /// Appelée depuis la **première** étape (« Revenir à l'accueil »).
    /// `nil` = aucun retour (le bouton n'apparaît pas). Le RN câble toujours
    /// `onCancel` (`OnboardingScreen.tsx:883`) : sans lui, le parcours ouvert à
    /// la racine (session ouverte + profil vide) n'a **aucune sortie**.
    let onCancel: (() -> Void)?

    /// Mode d'entrée du parcours (`OnboardingMode`). Défaut `.account`, comme
    /// la source. Passer `.guest` pour ne garder que les étapes de programme
    /// (année, filière, option, prêt), sans détails de compte ni cadeau.
    private let mode: OnbDataSteps.Mode

    /// Identités fournisseur déjà connues à l'ouverture (`initialGoogleIdentity`
    /// / `initialAppleIdentity`, `OnboardingScreen.tsx:111-112`) : le parcours
    /// peut démarrer sur une identité certifiée plutôt qu'un formulaire vierge.
    private let initialGoogleIdentity: GoogleIdentity?
    private let initialAppleIdentity: AppleAuthIdentity?

    @EnvironmentObject private var session: SessionStore

    init(
        mode: OnbDataSteps.Mode = .account,
        initialGoogleIdentity: GoogleIdentity? = nil,
        initialAppleIdentity: AppleAuthIdentity? = nil,
        onCancel: (() -> Void)? = nil,
        onFinish: @escaping () -> Void
    ) {
        self.mode = mode
        self.initialGoogleIdentity = initialGoogleIdentity
        self.initialAppleIdentity = initialAppleIdentity
        self.onCancel = onCancel
        self.onFinish = onFinish
    }

    var body: some View {
        OnbFlowView(
            mode: mode,
            initialProfile: session.profile,
            // Session déjà ouverte : ce parcours complète un profil, il ne crée
            // aucun compte. Le pré-vol d'inscription n'a donc rien à vérifier —
            // et il répondait 409 « Un compte existe déjà avec cette adresse
            // e-mail » sur l'adresse de l'utilisateur, ce qui bloquait l'avance
            // définitivement (« Continuer » désactivé, sans reprise possible).
            requiresRegistrationPreflight: !session.isSignedIn,
            initialGoogleIdentity: initialGoogleIdentity,
            initialAppleIdentity: initialAppleIdentity,
            onComplete: { profile, _ in commit(profile) },
            onProgramSelected: prepareOnboardingProgram,
            onTrainingSurfaceReady: {},
            onCancel: onCancel
        )
    }

    /// Écrit le profil final puis rend la main (équivalent de `finish` de
    /// l'ancienne vue).
    ///
    /// `session.profile` est publié : dès que l'année et la filière sont
    /// renseignées, `RootView` bascule sur `MainTabView`. Le profil n'est donc
    /// écrit **qu'à la complétion**, jamais pendant les étapes de programme —
    /// sinon le parcours serait interrompu avant ses dernières étapes.
    private func commit(_ profile: UserProfile) {
        session.profile = profile
        session.persistProfile()
        onFinish()
    }
}

/// Inscription depuis l'accueil (`onCreateAccount` de `WelcomeScreen.tsx`).
///
/// La source joue le parcours d'onboarding **avant** toute session
/// (`authStage === 'signup'` → `OnboardingScreen`, `App.tsx:2486`), puis ouvre
/// le compte (`completeOnboarding`, `App.tsx:1734`). C'est l'inverse du chemin
/// historique de l'app, où « Créer un compte » ouvrait un formulaire clair
/// hérité (`LoginView(mode: .register)`) et où `RootView` ne jouait
/// l'onboarding qu'**après** connexion.
struct SignupFlowView: View {
    /// Appelée quand le compte est ouvert, ou le parcours abandonné.
    var onFinish: () -> Void

    @EnvironmentObject private var session: SessionStore
    /// Branche `signup` du fournisseur (`App.tsx:2115-2123`) : identité retenue
    /// par `LoginIntAssembly` quand la connexion ne correspond à aucun compte
    /// local ; elle amorce le parcours (`initialGoogleIdentity` / `:2155-2162`).
    @ObservedObject private var providerSignup = LoginIntProviderSignupRouter.shared
    @State private var errorMessage: String?
    /// Réouverture de compte fournisseur en attente de décision (U13 §2).
    @State private var pendingReuse: LoginIntProviderReuseAlert?

    var body: some View {
        OnbFlowView(
            mode: .account,
            initialProfile: session.profile,
            initialGoogleIdentity: initialGoogleIdentity,
            initialAppleIdentity: initialAppleIdentity,
            onComplete: { profile, credentials in
                await openAccount(profile: profile, credentials: credentials)
            },
            onProgramSelected: prepareOnboardingProgram,
            onTrainingSurfaceReady: {},
            onCancel: onFinish
        )
        .alert("Création du compte impossible", isPresented: errorPresented) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .alert(pendingReuse?.title ?? "", isPresented: isReusePresented) {
            Button("Ouvrir mon compte") {
                let alert = pendingReuse
                pendingReuse = nil
                alert?.proceed()
            }
            Button("Continuer la création", role: .cancel) { pendingReuse = nil }
        } message: {
            Text(pendingReuse?.message ?? "")
        }
    }

    /// `initialGoogleIdentity` (`OnboardingScreen.tsx:111-112`) : identité Google
    /// **complète** retenue par la branche `signup` du fournisseur
    /// (`LoginIntPendingProviderSignup`), libellés du nom compris — le parcours
    /// amorce le profil comme la source (`OnboardingScreen.tsx:229-247`).
    private var initialGoogleIdentity: GoogleIdentity? {
        guard let pending = providerSignup.pending, pending.provider == .google else { return nil }
        return GoogleIdentity(
            subject: pending.subject,
            email: pending.email,
            displayName: pending.displayName,
            firstName: pending.firstName,
            lastName: pending.lastName,
            photoUrl: nil
        )
    }

    /// `initialAppleIdentity` (`OnboardingScreen.tsx:111-112`) : symétrique de
    /// `initialGoogleIdentity`.
    private var initialAppleIdentity: AppleAuthIdentity? {
        guard let pending = providerSignup.pending, pending.provider == .apple else { return nil }
        return AppleAuthIdentity(
            subject: pending.subject,
            email: pending.email,
            displayName: pending.displayName,
            firstName: pending.firstName,
            lastName: pending.lastName
        )
    }

    /// `completeOnboarding` : ouvre le compte construit par le parcours.
    ///
    /// Un mot de passe crée le compte serveur (`registerServerPassword`) ; un
    /// fournisseur pose la session déjà validée pendant le parcours (le
    /// `claimServerUsername` de la source n'a pas d'équivalent ici).
    ///
    /// U13 §2 : avant d'ouvrir la session fournisseur, la garde de réouverture
    /// (`shouldConfirmProviderLogin`, `authStage = "signup"`) est interrogée —
    /// rouvrir un compte existant abandonnerait le parcours en cours.
    /// « Continuer la création » n'ouvre rien : `ProviderAuthFollowUp.declined`.
    /// La confirmation déjà obtenue au bouton Google
    /// (`OnbFlowProviderButtons.signInWithGoogle`) est consommée ici.
    ///
    /// La session fournisseur vient du parcours de connexion qui a routé vers
    /// l'inscription (`LoginIntPendingProviderSignup.session`) : le coordinateur
    /// ne la porte pas pour une identité **initiale** (seul un appui en cours de
    /// parcours la lui pose), d'où le repli.
    @MainActor
    private func openAccount(profile: UserProfile, credentials: OnbUiCredentials) async {
        let pendingSession = providerSignup.pending?.session
        if let google = credentials.googleIdentity,
           let payload = credentials.providerSession ?? pendingSession {
            pendingReuse = loginIntProviderReuseAlert(
                provider: .google,
                subject: google.subject,
                email: google.email,
                subjectKeyPath: \AcctStoredAccount.googleSubject,
                authStage: "signup",
                upgradingGuest: false,
                hasActiveSession: session.isSignedIn,
                consumingConfirmation: true,
                proceed: { openGoogleAccount(profile: profile, google: google, payload: payload) }
            )
        } else if let apple = credentials.appleIdentity,
                  let payload = credentials.providerSession ?? pendingSession {
            pendingReuse = loginIntProviderReuseAlert(
                provider: .apple,
                subject: apple.subject,
                email: apple.email,
                subjectKeyPath: \AcctStoredAccount.appleSubject,
                authStage: "signup",
                upgradingGuest: false,
                hasActiveSession: session.isSignedIn,
                consumingConfirmation: true,
                proceed: { openAppleAccount(profile: profile, apple: apple, payload: payload) }
            )
        } else if !credentials.password.isEmpty {
            do {
                try await session.signUp(
                    email: profile.email,
                    password: credentials.password,
                    displayName: profile.displayName
                )
                finishAccount(profile)
            } catch {
                errorMessage = error.localizedDescription
            }
        } else {
            errorMessage = "Aucun moyen de connexion n’a été choisi."
        }
    }

    /// Ouvre la session Google, écrit le profil et rend la main.
    @MainActor
    private func openGoogleAccount(
        profile: UserProfile,
        google: GoogleIdentity,
        payload: DuelloAPI.SessionPayload
    ) {
        do {
            try session.signInWithGoogle(identity: google, payload: payload)
            finishAccount(profile)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Ouvre la session Apple, écrit le profil et rend la main.
    @MainActor
    private func openAppleAccount(
        profile: UserProfile,
        apple: AppleAuthIdentity,
        payload: DuelloAPI.SessionPayload
    ) {
        do {
            try LoginIntSession.openAppleSession(session: session, identity: apple, payload: payload)
            finishAccount(profile)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Écrit le profil final et rend la main (`finish` de la source).
    private func finishAccount(_ profile: UserProfile) {
        session.profile = profile
        session.persistProfile()
        onFinish()
    }

    /// `errorMessage != nil` ⇔ alerte d'échec de création de compte présentée.
    private var errorPresented: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { presented in if !presented { errorMessage = nil } }
        )
    }

    /// `pendingReuse != nil` ⇔ alerte de réouverture de compte présentée.
    private var isReusePresented: Binding<Bool> {
        Binding(
            get: { pendingReuse != nil },
            set: { presented in if !presented { pendingReuse = nil } }
        )
    }
}

// MARK: - Préparation du programme (`onProgramSelected`)

/// `prepareOnboardingExerciseContent` (`App.tsx:763`) : dès que les choix de
/// programme sont figés, la source enfile les énoncés du profil puis démarre le
/// préchargement reprenable. Le port déclenche la même passe par `OfflBootstrap`
/// (téléchargement du contenu du profil). Écart assumé : le contrôleur
/// `OfflExercisePrefetchController` reste hors câblage — son énumération de
/// **tous** les énoncés publiés (`allExerciseStatementContentBundleIds`,
/// `contentStartup.ts:215`) n'est pas portée ; seul le périmètre du profil est
/// préchargé.
private func prepareOnboardingProgram(_ profile: UserProfile) {
    let ids = TrainContent.profileBundleIds(
        track: profile.track,
        specialty: profile.specialty,
        year: TrainContent.programYear(from: profile.year)
    ).compactMap(OfflContentBundleId.init(rawValue:))
    guard !ids.isEmpty else { return }
    OfflBootstrap.scheduleContentRefresh(ids: ids)
}
