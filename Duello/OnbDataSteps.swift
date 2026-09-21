//
//  OnbDataSteps.swift
//  Duello
//
//  Étapes du parcours d'inscription, portées de l'app Expo :
//    - src/utils/onboardingSteps.ts (`OnboardingMode`, `OnboardingStepKey`,
//      `ACCOUNT_DETAILS_STEPS`, `UPGRADE_STEPS`, `resolveOnboardingSteps`)
//    - src/screens/OnboardingScreen.tsx (`STEP_COPY`, surtitres d'étape)
//
//  La vue `OnboardingView` (déjà portée) n'affiche que les étapes de programme
//  dans l'ordre ; ce module restitue la liste complète des clés et leur ordre
//  par mode, sans modifier cette vue. Aucune dépendance externe. iOS 16.
//

import Foundation

/// Ordre et libellés des étapes du parcours d'inscription
/// (`resolveOnboardingSteps`, `STEP_COPY`).
enum OnbDataSteps {
    /// Mode d'entrée dans le parcours (`OnboardingMode`).
    enum Mode: String, CaseIterable {
        case account
        case guest
        case upgrade
    }

    /// Clé d'étape (`OnboardingStepKey`) ; la valeur brute reste identique à
    /// celle de l'app Expo (`current-track`, `premium-gift`, `auth-method`).
    enum Step: String, CaseIterable {
        case year
        case currentTrack = "current-track"
        case origin
        case options
        case premiumGift = "premium-gift"
        case ready
        case target
        case identity
        case authMethod = "auth-method"
        case credentials
    }

    /// `ACCOUNT_DETAILS_STEPS`.
    static let accountDetailsSteps: [Step] = [.identity, .authMethod, .credentials]
    /// `UPGRADE_STEPS`.
    static let upgradeSteps: [Step] = [.authMethod, .identity, .credentials, .ready, .premiumGift]

    /// `resolveOnboardingSteps` : étapes réellement parcourues selon le mode et
    /// la présence d'une option de mathématiques.
    ///
    /// - `upgrade` : uniquement `UPGRADE_STEPS` ;
    /// - `guest` : programme puis `ready`, sans compte ni cadeau ;
    /// - `account` : programme, détails de compte, `ready`, puis cadeau.
    static func resolve(asksForMathOption: Bool, mode: Mode) -> [Step] {
        if mode == .upgrade { return upgradeSteps }

        var programSteps: [Step] = [.year, .currentTrack]
        if asksForMathOption { programSteps.append(.options) }

        // La création d'un vrai compte est la seule situation qui accorde
        // l'essai Premium serveur : le cadeau s'annonce pour elle, jamais pour
        // un invité.
        let giftSteps: [Step] = mode == .account ? [.premiumGift] : []
        // Plus de page notifications dédiée : la popup système est déclenchée
        // par le dernier « Continuer ».
        let finalSteps: [Step] = [.ready]

        return mode == .guest
            ? programSteps + finalSteps
            : programSteps + accountDetailsSteps + finalSteps + giftSteps
    }

    /// Surtitre d'étape (`STEP_COPY`) ; `nil` pour les étapes sans surtitre.
    static func eyebrow(for step: Step) -> String? {
        switch step {
        case .year: return "TON ANNÉE"
        case .currentTrack: return "TA FILIÈRE ACTUELLE"
        case .origin: return "TON PARCOURS DE 1RE ANNÉE"
        case .options: return "TON OPTION"
        case .target: return "TON ÉCOLE CIBLE"
        case .ready, .premiumGift, .identity, .authMethod, .credentials: return nil
        }
    }
}
