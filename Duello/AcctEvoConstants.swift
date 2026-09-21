//
//  AcctEvoConstants.swift
//  Duello
//
//  Constantes et unité du lot 10-B (préfixe `AcctEvo`) : pastille d'évolution
//  et chargement du graphique de performance.
//
//  Fichier source Expo porté (noms et libellés repris mot pour mot) :
//    - src/screens/AccountScreen.tsx, lignes 384-403
//      (`USE_REFINED_OVERVIEW`, `AUTO_SAVE_DELAY`, `INFORMATION_ICON_SIZE`,
//       `PROFILE_DETAILS_SETTLE_DELAY_MS`, `EMPTY_SUBJECT_SUCCESSES`,
//       `EMPTY_XP_SERIES`, `type PerformanceEvolutionUnit`)
//
//  Cible iOS 16 ; aucune dépendance externe.
//
import Foundation
import CoreGraphics

/// Constantes du bloc « évolution de performance » de l'écran Compte.
///
/// En Expo, `USE_REFINED_OVERVIEW` dépendait de la variante d'application
/// (`Constants.expoConfig.extra.appVariant`, `applicationId`, `name`). En
/// SwiftUI natif, la même intention est reconstruite depuis le bundle iOS et,
/// à défaut, depuis la variable d'environnement `DUELLO_APP_VARIANT`.
enum AcctEvoConstants {
    /// Identifiant de bundle de la variante « development » (`com.prepapp.mobile.dev`).
    static let developmentBundleIdentifier = "com.prepapp.mobile.dev"
    /// Nom d'affichage de la variante « development » (`Duello Dev`).
    static let developmentAppName = "Duello Dev"

    /// `USE_REFINED_OVERVIEW` — vrai sur la variante de développement.
    static let useRefinedOverview: Bool = {
        let environment = ProcessInfo.processInfo.environment
        if environment["DUELLO_APP_VARIANT"] == "development" { return true }
        let bundleIdentifier = Bundle.main.bundleIdentifier ?? ""
        if bundleIdentifier == developmentBundleIdentifier { return true }
        let displayName = (Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String) ?? ""
        return displayName == developmentAppName
    }()

    /// `AUTO_SAVE_DELAY` (ms) : assez court pour être immédiat, assez long pour
    /// grouper une saisie.
    static let autoSaveDelayMilliseconds = 350

    /// `INFORMATION_ICON_SIZE` : taille commune des pictogrammes des lignes de
    /// « Mes informations ».
    static let informationIconSize: CGFloat = 22

    /// `PROFILE_DETAILS_SETTLE_DELAY_MS` (ms) : stabilisation avant lecture des
    /// détails de profil.
    static let profileDetailsSettleDelayMilliseconds = 120

    /// `EMPTY_SUBJECT_SUCCESSES` — tableau vide typé, pour éviter une allocation
    /// et un `nil` inutiles côté appelant.
    static let emptySubjectSuccesses: [ChartSubjectSuccess] = []

    /// `EMPTY_XP_SERIES` — série d'XP vide typée.
    static let emptyXpSeries: [ChartXpSeriesPoint] = []
}

/// `type PerformanceEvolutionUnit` de `AccountScreen.tsx` : unité d'une
/// variation affichée dans la pastille d'évolution.
enum AcctEvoPerformanceEvolutionUnit: String, CaseIterable {
    case xp
    case elo
    case grade
}
