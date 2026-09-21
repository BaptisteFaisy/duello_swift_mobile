import Foundation
import SwiftUI

// MARK: - Lignes de classement

/// Ligne prête à afficher, calculée après fusion et tri côté client.
///
/// Extrait de l'ancien `RankingsView.swift` : était `private`, élargi à
/// `internal` car construit par `RankingRowBuilder` et consommé par
/// `RankingSubjectLeaderboard`, `RankingWeeklyXp` et `LeaderboardRowView` —
/// mêmes propriétés, même libellé d'accessibilité.
struct RankedLeaderboardRow: Identifiable {
    let id: String
    let rank: Int
    let displayName: String
    let initial: String
    let meta: String
    let score: Int
    let valueLabel: String
    let isCurrentUser: Bool
    let isAnonymous: Bool

    /// Libellé d'accessibilité : rang, nom, contexte puis valeur.
    var accessibilityLabel: String {
        let rankText = leaderboardRankLabel(rank)
        let valueText = "\(groupedNumber(score)) \(valueLabel)"
        return [rankText, displayName, meta, valueText]
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }
}

/// Ligne de classement : rang, avatar à initiale, nom, contexte et valeur.
///
/// Extrait de l'ancien `RankingsView.swift` : était `private`, élargi à
/// `internal` car instancié par les deux classements — corps inchangé.
struct LeaderboardRowView: View {
    let row: RankedLeaderboardRow

    var body: some View {
        HStack(spacing: 10) {
            Text("\(row.rank)")
                .font(.system(size: 13, weight: .black))
                .foregroundStyle(row.rank <= 3 ? Theme.ink : Theme.inkFaint)
                .frame(width: 26, alignment: .center)

            DuelloAvatar(
                initial: row.isAnonymous ? "" : row.initial,
                size: 32,
                background: row.isCurrentUser ? Theme.ink : Theme.primaryLight,
                foreground: row.isCurrentUser ? Theme.surface : Theme.inkSoft
            )

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(row.displayName)
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                    if row.isCurrentUser {
                        DuelloPill(text: "Moi", tone: .ink)
                    }
                }
                if !row.meta.isEmpty {
                    Text(row.meta)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.inkFaint)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 1) {
                Text(groupedNumber(row.score))
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(Theme.ink)
                Text(row.valueLabel)
                    .font(.system(size: 9, weight: .heavy))
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.inkFaint)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 8)
        .background(row.isCurrentUser ? Theme.primaryLight : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(row.accessibilityLabel)
    }
}

/// Séparateur fin entre deux lignes, à la couleur de bordure du thème.
///
/// Extrait de l'ancien `RankingsView.swift` : était `private`, élargi à
/// `internal` car posé par les deux classements — corps inchangé.
struct LeaderboardRowDivider: View {
    var body: some View {
        Rectangle()
            .fill(Theme.border)
            .frame(height: 1)
    }
}
