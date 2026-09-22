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

extension ScreenshotTour {
    /// Sème une session et un profil factices dans `store` quand le mode capture
    /// est actif — mêmes formes que le vrai chemin (jeton `dus_`, expiration
    /// lointaine), sans réseau ni trousseau. Hors mode capture, ne fait rien.
    ///
    /// Vit ici (et non dans `SessionStore.swift`) pour tenir la limite de
    /// complexité du projet : un fichier = une responsabilité, et le code de
    /// capture n'a rien à faire dans le magasin de session de production.
    static func seedSessionIfNeeded(_ store: SessionStore) {
        guard let shot = screen else { return }
        let far = ISO8601DateFormatter().string(from: Date().addingTimeInterval(60 * 60 * 24 * 30))
        store.session = ServerSession(
            token: "dus_screenshot_tour",
            expiresAt: far,
            publicId: "member-screenshot",
            email: "camille@email.fr"
        )
        store.isSignedIn = true
        store.profile = UserProfile()
        store.profile.email = "camille@email.fr"
        store.profile.firstName = "Camille"
        store.profile.lastName = "Faisy"
        store.profile.displayName = "Camille"
        // L'écran `onboarding` se joue avant tout parcours choisi ; les autres
        // écrans authentifiés supposent une filière posée. Libellés alignés sur
        // ceux de l'app (« 1re année », `data/tracks.ts:1863`) pour que la
        // capture soit comparable à celle du RN.
        if shot != "onboarding" {
            store.profile.year = "1re année"
            store.profile.track = "ECG"
            store.profile.specialty = "Maths appliquées"
        }
        store.isLoadingSession = false
    }
}
