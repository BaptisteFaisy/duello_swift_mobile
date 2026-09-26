import SwiftUI

/// Onglet « Défis » de l'écran « Progression » : une carte par matière affichée
/// (cote Elo, défis joués et gagnés, **sans** barre), puis l'encart d'invitation
/// tant qu'aucune matière visible n'a de défi joué. Extension de
/// `DuelloProgressView` (voir `ProgressScreen.swift` pour le découpage).
extension DuelloProgressView {

    // MARK: Défis

    @ViewBuilder
    var duelSection: some View {
        if activeSubjectNames.isEmpty {
            noSubjectSelectedState
        } else {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(visibleSubjects) { subject in
                    duelCard(subject)
                }

                if visibleDuelPlayed == 0 {
                    infoCard(duelInvitation)
                }
            }
        }
    }

    /// Carte de défis d'une matière : cote Elo et bilan des duels, sans barre.
    private func duelCard(_ subject: TrackSubject) -> some View {
        let stat = duelStat(for: subject)

        return VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(subject.name)
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                Spacer(minLength: 10)
                Text("\(elo(for: subject)) Elo")
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(Theme.primary)
            }

            HStack(alignment: .center, spacing: 10) {
                Text("\(stat.played) défi\(agreement(stat.played)) joué\(agreement(stat.played))")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.inkSoft)
                Spacer(minLength: 10)
                Text(duelSummary(stat))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.inkSoft)
            }
        }
        .progressCard()
    }

    /// Invitation à ouvrir un premier défi dans une matière affichée.
    private var duelInvitation: String {
        "Lance un défi depuis l’onglet Défis : tes duels s’ajouteront ici, matière par matière."
    }

    /// « N gagnés · X % », ou un tiret cadratin sans défi joué.
    private func duelSummary(_ stat: DuelStat) -> String {
        let rate = stat.played > 0 ? "\(stat.winRatePercent) %" : "—"
        return "\(stat.won) gagné\(agreement(stat.won)) · \(rate)"
    }
}
