import Foundation
import SwiftUI

// MARK: - Feuille de classement

/// Version feuille du classement, présentée par les écrans qui affichent un
/// classement (coupes Maths et Défis). Portage de
/// `src/components/LeaderboardModal.tsx` : contenu plein écran, chevron de
/// fermeture **dans l'en-tête** (comme `BackButton` de `LeaderboardScreen.tsx`)
/// et classements identiques à `RankingsView`.
///
/// La source est un `Modal` plein écran **sans titre ni barre de navigation** :
/// l'ajout Swift d'un `NavigationStack` titré « Classements » avec un bouton
/// « Fermer » est retiré. La fermeture passe par le chevron du ruban (`onBack`).
///
/// Extrait de l'ancien `RankingsView.swift` : dépend seulement de
/// `RankingScreenTabs` (`RankingsView`) et de ses deux onglets, sans
/// renommage.
struct LeaderboardModalView: View {
    @Environment(\.dismiss) private var dismiss

    /// Onglet ouvert à l'ouverture de la feuille.
    var initialTab: RankingsView.RankingsTab = .subject
    /// Matière classée.
    var subject: String = "Mathématiques"
    /// Masque l'accès au classement XP (coupe de Défis).
    var eloOnly: Bool = false
    /// Masque l'accès aux ligues Elo (coupe d'Entraînement).
    var xpOnly: Bool = false
    /// Ouvre la fiche d'un joueur (`onOpenProfile`).
    var onOpenProfile: ((String) -> Void)? = nil

    /// - Parameters:
    ///   - initialTab: onglet ouvert à l'ouverture de la feuille.
    ///   - subject: matière classée.
    ///   - eloOnly: masque l'accès au classement XP.
    ///   - xpOnly: masque l'accès aux ligues Elo.
    init(
        initialTab: RankingsView.RankingsTab = .subject,
        subject: String = "Mathématiques",
        eloOnly: Bool = false,
        xpOnly: Bool = false,
        onOpenProfile: ((String) -> Void)? = nil
    ) {
        self.initialTab = initialTab
        self.subject = subject
        self.eloOnly = eloOnly
        self.xpOnly = xpOnly
        self.onOpenProfile = onOpenProfile
    }

    var body: some View {
        RankingsView(
            initialTab: initialTab,
            subject: subject,
            eloOnly: eloOnly,
            xpOnly: xpOnly,
            onOpenProfile: onOpenProfile,
            onBack: { dismiss() }
        )
        .background(Theme.background)
    }
}
