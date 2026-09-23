//
//  OnbUiConstants.swift
//  Duello
//
//  Constantes, étapes et libellés de l'écran d'inscription.
//  Porté de `src/screens/OnboardingScreen.tsx`, plage 95-163 :
//    `YEARS`, `ONBOARDING_LEVELS`, `LYCEE_YEARS` (via `OnbFlowAcademic`),
//    `TRAINING_BLOOM_SIZE`, `TRAINING_BLOOM_RADIUS`,
//    `CONTINUE_BUTTON_HEIGHT`, `ONBOARDING_FOOTER_BOTTOM_PADDING`,
//    `WEB_GUEST_ACTION_WIDTH`, `TRAINING_BLOOM_CENTER_ABOVE_SAFE_AREA`,
//    `TRAINING_HANDOFF_DURATION_MS`, `TRAINING_HANDOFF_REVEAL_DURATION_MS`,
//    `TRAINING_HANDOFF_EASING`, `STEP_COPY`, `normalize`.
//
//  Préfixe réservé du lot : `OnbUi`. Aucune dépendance externe. Cible iOS 16.
//  Aucun fichier existant n'est modifié : les types déjà portés (`Theme`,
//  `OnbGiftEasing`, `OnbDataSteps`) sont réutilisés, jamais redéfinis.
//

import CoreGraphics
import Foundation

/// Constantes de mise en page et de rythme de l'écran d'inscription.
enum OnbUiConstants {
    // MARK: Étapes

    /// `YEARS` — années de prépa (`PREPA_YEARS`). Les années du lycée vivent
    /// dans `OnbFlowAcademic.lyceeYears` (`LYCEE_YEARS` de la source) : la page
    /// « TON ANNÉE » affiche les années du monde choisi sur « TON NIVEAU ».
    static let years: [String] = ["1re année", "2e année"]

    /// `ONBOARDING_LEVELS` — mondes proposés par la page « TON NIVEAU », la
    /// prépa au-dessus du lycée (JP 2026-09-18).
    static let onboardingLevels: [String] = ["Prépa", "Lycée"]

    /// `STEP_COPY` — surtitres d'étape (`OnboardingStepKey` → `eyebrow`).
    ///
    /// **Non redéfini ici** : la table est déjà portée par
    /// `OnbDataSteps.eyebrow(for:)` (`OnbDataSteps.swift`). Utiliser ce
    /// accesseur plutôt que dupliquer les libellés.
    /// (Le lot 12-A cite `STEP_COPY` : il est couvert, hors de ce fichier.)

    // MARK: Halo de l'étape Entraînement

    /// `TRAINING_BLOOM_SIZE` — diamètre du halo qui couvre l'évaluation.
    static let trainingBloomSize: CGFloat = 96
    /// `TRAINING_BLOOM_RADIUS`.
    static let trainingBloomRadius: CGFloat = trainingBloomSize / 2
    /// `TRAINING_BLOOM_CENTER_ABOVE_SAFE_AREA` — centre du halo au-dessus de la
    /// zone sûre, aligné sur le milieu du bouton principal du pied d'écran.
    static let trainingBloomCenterAboveSafeArea: CGFloat =
        onboardingFooterBottomPadding + continueButtonHeight / 2

    /// `TRAINING_HANDOFF_DURATION_MS` — durée du passage vers la surface
    /// Entraînement. Plus d'attente décorative : le halo couvre l'évaluation du
    /// module (préchauffé dès sa première image).
    static let trainingHandoffDurationMs = 450
    /// `TRAINING_HANDOFF_REVEAL_DURATION_MS` — durée de la révélation.
    static let trainingHandoffRevealDurationMs = 300
    /// `TRAINING_HANDOFF_EASING` = `Easing.inOut(Easing.cubic)`.
    ///
    /// Reanimated n'existe pas côté Swift : la courbe est réutilisée depuis
    /// `OnbGiftEasing.cubicInOut` (déjà portée par le lot cadeau), évaluée
    /// `[0, 1] → [0, 1]` à la main, image par image.
    static let trainingHandoffEasing: (Double) -> Double = OnbGiftEasing.cubicInOut

    // MARK: Pied d'écran

    /// `CONTINUE_BUTTON_HEIGHT` — hauteur du bouton principal (« Continuer »).
    static let continueButtonHeight: CGFloat = 54
    /// `ONBOARDING_FOOTER_BOTTOM_PADDING` — marge basse du pied d'écran.
    static let onboardingFooterBottomPadding: CGFloat = 10

    /// `WEB_GUEST_ACTION_WIDTH` — largeur des actions invité.
    ///
    /// ⚠️ **Inutilisée sur iOS** : la source ne l'applique que sous
    /// `Platform.OS === 'web'`. Conservée pour la traçabilité du portage,
    /// volontairement non consommée par les vues Swift.
    static let webGuestActionWidth = "33.333333%"

    // MARK: Recherche

    /// `normalize` — repli des diacritiques et passage en minuscules, pour les
    /// recherches insensibles à la casse et aux accents.
    ///
    /// Équivalent Swift de `.normalize('NFD').replace(/[\u0300-\u036f]/g, '')`
    /// suivi de `.toLowerCase()`.
    static func normalize(_ value: String) -> String {
        value
            .folding(options: .diacriticInsensitive, locale: Locale(identifier: "fr_FR"))
            .lowercased()
    }
}
