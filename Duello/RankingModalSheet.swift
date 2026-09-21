import Foundation
import SwiftUI

// MARK: - Feuille de classement

/// Version feuille du classement, présentée par les écrans qui affichent un
/// classement (coupes Maths et Défis). Portage de
/// `src/components/LeaderboardModal.tsx` : contenu plein écran, en-tête de
/// fermeture et classements identiques à `RankingsView`.
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

    /// - Parameters:
    ///   - initialTab: onglet ouvert à l'ouverture de la feuille.
    ///   - subject: matière classée.
    init(initialTab: RankingsView.RankingsTab = .subject, subject: String = "Mathématiques") {
        self.initialTab = initialTab
        self.subject = subject
    }

    var body: some View {
        NavigationStack {
            RankingsView(initialTab: initialTab, subject: subject)
                .navigationTitle("Classements")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Fermer") { dismiss() }
                    }
                }
        }
    }
}
