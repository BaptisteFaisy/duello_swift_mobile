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
//  Monde lycée (lot « onb-lycee-rn », 2026-09-23) : les étapes `level`
//  (« TON NIVEAU », qui précède `year`) et `specialty` (« TA SPÉCIALITÉ ») sont
//  portées, ainsi que `asksForOrigin` (un PSI précise sa filière de 1re année).
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
        case level
        case year
        case currentTrack = "current-track"
        case origin
        case specialty
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

    /// `resolveOnboardingSteps` : étapes réellement parcourues selon le mode, le
    /// monde scolaire et la présence d'une option de mathématiques.
    ///
    /// - `upgrade` : uniquement `UPGRADE_STEPS` ;
    /// - `guest` : programme puis `ready`, sans compte ni cadeau ;
    /// - `account` : programme, détails de compte, `ready`, puis cadeau.
    ///
    /// « TON NIVEAU » ouvre toujours le parcours (JP 2026-09-18) : il précède
    /// « TON ANNÉE » et distingue Lycée de Prépa. Le lycée enchaîne sur son
    /// année (2de, 1re, Terminale) puis sa spécialité ; la prépa garde année
    /// puis filière (l'origine d'un PSI, puis l'option de maths le cas
    /// échéant).
    static func resolve(
        asksForMathOption: Bool,
        asksForOrigin: Bool = false,
        isLyceeTrack: Bool = false,
        mode: Mode
    ) -> [Step] {
        if mode == .upgrade { return upgradeSteps }

        var programSteps: [Step] = [.level, .year]
        if isLyceeTrack {
            if asksForMathOption { programSteps.append(.specialty) }
        } else {
            programSteps.append(.currentTrack)
            // Les PSI précisent leur filière de 1re année juste après leur
            // filière actuelle.
            if asksForOrigin { programSteps.append(.origin) }
            if asksForMathOption { programSteps.append(.options) }
        }

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
        case .level: return "TON NIVEAU"
        case .year: return "TON ANNÉE"
        case .currentTrack: return "TA FILIÈRE ACTUELLE"
        case .origin: return "TON PARCOURS DE 1RE ANNÉE"
        case .specialty: return "TA SPÉCIALITÉ"
        case .options: return "TON OPTION"
        case .target: return "TON ÉCOLE CIBLE"
        case .ready, .premiumGift, .identity, .authMethod, .credentials: return nil
        }
    }
}
