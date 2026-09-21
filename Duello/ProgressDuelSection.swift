import SwiftUI

/// Onglet « Défis » de l'écran « Progression » : cote Elo de la matière, défis
/// joués et gagnés, invitation tant qu'aucun défi n'a été joué. Extension de
/// `DuelloProgressView` (voir `ProgressScreen.swift` pour le découpage).
extension DuelloProgressView {

    // MARK: Défis

    /// Défis de la matière : cote, défis joués et gagnés, encart d'invitation
    /// tant qu'aucun défi n'a été joué.
    @ViewBuilder
    var duelSection: some View {
        let stat = duelStat

        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(selectedSubject?.name ?? "Matière")
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                Spacer(minLength: 10)
                Text("\(selectedElo) Elo")
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(Theme.ink)
            }

            ProgressBar(fraction: stat.fraction)

            HStack(spacing: 10) {
                Text("\(stat.played) défi\(agreement(stat.played)) joué\(agreement(stat.played))")
                Spacer(minLength: 10)
                Text(duelSummary(stat))
            }
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Theme.inkSoft)
        }
        .duelloCard()

        if stat.played == 0 {
            infoCard(duelInvitation)
        }
    }

    /// Invitation à ouvrir un premier défi dans la matière affichée.
    private var duelInvitation: String {
        "Lance un défi depuis l'onglet Défis : tes duels s'ajouteront ici, matière par matière."
    }

    /// « N gagnés · X % », ou un tiret cadratin sans défi joué.
    private func duelSummary(_ stat: DuelStat) -> String {
        let rate = stat.played > 0 ? "\(stat.winRatePercent) %" : "—"
        return "\(stat.won) gagné\(agreement(stat.won)) · \(rate)"
    }
}
