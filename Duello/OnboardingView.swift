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
//   - la filière « actuelle » n'expose que **ECG** (`OnbFlowCoordinator`
//     `visibleCurrentTracks`, fidèle aux lignes 1087-1108 de la source) : plus
//     étroit que l'ancienne vue, qui proposait MPSI / MP2I / ECG / MP / MPI /
//     PSI ;
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

    /// Mode d'entrée du parcours (`OnboardingMode`). Défaut `.account`, comme
    /// la source. Passer `.guest` pour ne garder que les étapes de programme
    /// (année, filière, option, prêt), sans détails de compte ni cadeau.
    private let mode: OnbDataSteps.Mode

    @EnvironmentObject private var session: SessionStore

    init(mode: OnbDataSteps.Mode = .account, onFinish: @escaping () -> Void) {
        self.mode = mode
        self.onFinish = onFinish
    }

    var body: some View {
        OnbFlowView(
            mode: mode,
            initialProfile: session.profile,
            onComplete: { profile, _ in commit(profile) }
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
