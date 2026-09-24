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
//   - en mode `.account`, le pré-vol d'inscription interroge le serveur au
//     montage (`OnbFlowSteps.checkRegistrationPreflight`) : hors ligne, l'avance
//     reste bloquée (« Création de compte indisponible ») ;
//   - les identifiants collectés (mot de passe, biométrie, fournisseur) ne sont
//     pas transmis au serveur ici : seul le profil local est écrit à la
//     complétion.
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

    @EnvironmentObject private var session: SessionStore

    init(
        mode: OnbDataSteps.Mode = .account,
        onCancel: (() -> Void)? = nil,
        onFinish: @escaping () -> Void
    ) {
        self.mode = mode
        self.onCancel = onCancel
        self.onFinish = onFinish
    }

    var body: some View {
        OnbFlowView(
            mode: mode,
            initialProfile: session.profile,
            onComplete: { profile, _ in commit(profile) },
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
    @State private var errorMessage: String?
    /// Réouverture de compte fournisseur en attente de décision (U13 §2).
    @State private var pendingReuse: LoginIntProviderReuseAlert?

    var body: some View {
        OnbFlowView(
            mode: .account,
            initialProfile: session.profile,
            onComplete: { profile, credentials in
                await openAccount(profile: profile, credentials: credentials)
            },
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
    @MainActor
    private func openAccount(profile: UserProfile, credentials: OnbUiCredentials) async {
        if let google = credentials.googleIdentity, let payload = credentials.providerSession {
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
        } else if let apple = credentials.appleIdentity, let payload = credentials.providerSession {
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
