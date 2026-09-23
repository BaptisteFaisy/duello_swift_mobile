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
            // Session déjà ouverte : ce parcours complète un profil, il ne crée
            // aucun compte. Le pré-vol d'inscription n'a donc rien à vérifier —
            // et il répondait 409 « Un compte existe déjà avec cette adresse
            // e-mail » sur l'adresse de l'utilisateur, ce qui bloquait l'avance
            // définitivement (« Continuer » désactivé, sans reprise possible).
            requiresRegistrationPreflight: !session.isSignedIn,
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

    var body: some View {
        OnbFlowView(
            mode: .account,
            initialProfile: session.profile,
            onComplete: { profile, credentials in
                await openAccount(profile: profile, credentials: credentials)
            },
            onCancel: onFinish
        )
        .overlay(alignment: .bottom) { errorBanner }
    }

    /// `completeOnboarding` : ouvre le compte construit par le parcours.
    ///
    /// Un mot de passe crée le compte serveur (`registerServerPassword`) ; un
    /// fournisseur pose la session déjà validée pendant le parcours (le
    /// `claimServerUsername` de la source n'a pas d'équivalent ici).
    @MainActor
    private func openAccount(profile: UserProfile, credentials: OnbUiCredentials) async {
        do {
            if let google = credentials.googleIdentity, let payload = credentials.providerSession {
                try session.signInWithGoogle(identity: google, payload: payload)
            } else if let apple = credentials.appleIdentity, let payload = credentials.providerSession {
                try LoginIntSession.openAppleSession(
                    session: session,
                    identity: apple,
                    payload: payload
                )
            } else if !credentials.password.isEmpty {
                try await session.signUp(
                    email: profile.email,
                    password: credentials.password,
                    displayName: profile.displayName
                )
            } else {
                errorMessage = "Aucun moyen de connexion n’a été choisi."
                return
            }

            session.profile = profile
            session.persistProfile()
            onFinish()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Bandeau d'échec, posé au-dessus du pied de page du parcours.
    @ViewBuilder private var errorBanner: some View {
        if let errorMessage {
            Text(errorMessage)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(Theme.like)
                .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
                .padding(.horizontal, 22)
                .padding(.bottom, 96)
        }
    }
}
