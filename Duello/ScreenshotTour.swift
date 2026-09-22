import Foundation

/// Mode « capture d'écran » — **outil de développement, jamais livré à l'usage**.
///
/// Activé uniquement par la variable d'environnement `DUELLO_SHOT` (job CI
/// `screenshots.yml`). Sans elle, ce fichier ne fait rien : `screen` vaut `nil`
/// et aucun chemin de l'application n'est modifié.
///
/// Raison d'être : comparer le rendu SwiftUI au rendu React Native écran par
/// écran exige de **photographier** chaque écran. Or les onglets principaux ne
/// s'affichent qu'avec une session ouverte, et un simulateur CI n'a ni compte
/// ni serveur. Ce mode sème donc une session et un profil factices, puis fige
/// la racine sur l'écran demandé.
///
/// Valeurs acceptées : `welcome`, `onboarding`, `profile`, `training`,
/// `challenges`.
enum ScreenshotTour {
    /// Écran demandé, ou `nil` hors mode capture.
    static var screen: String? {
        guard let raw = ProcessInfo.processInfo.environment["DUELLO_SHOT"] else { return nil }
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    static var isActive: Bool { screen != nil }

    /// Onglet initial des écrans qui vivent dans la barre principale.
    /// Renvoie `nil` hors mode capture ou pour un écran hors barre.
    static var tabSelection: Int? {
        switch screen {
        case "profile": return 0
        case "training": return 1
        case "challenges": return 2
        default: return nil
        }
    }
}
