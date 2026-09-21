//
//  EvEventLeaderboardView.swift
//  Duello
//
//  Classement publié d'un événement : une ligne par participant (rang, note sur
//  20 avec trois décimales au plus, Elo gagné, XP gagnés). Les trois premiers
//  forment un premier groupe, les sept suivants un deuxième, les autres
//  s'affichent ensemble ; les ex æquo partagent leur rang.
//
//  Fichier source Expo porté : `src/components/event/EventLeaderboardView.tsx`.
//
//  Limite connue : la présence temps réel (`usePresence`, socket) n'est pas
//  portée — la ligne affiche le nom sans la pastille « en ligne », comme le
//  classement d'exercice (`ExGExerciseLeaderboard`).
//
//  Cible : iOS 16.
//
import SwiftUI

struct EvEventLeaderboardView: View {
    let entries: [EvLeaderboardEntry]
    let ownId: String?

    var body: some View {
        VStack(spacing: 6) {
            ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                if startsGroup(at: index) {
                    Color.clear.frame(height: 10)
                }
                EvEventLeaderboardRow(entry: entry, highlighted: entry.id == ownId)
            }
        }
    }

    /// Un séparateur précède la ligne quand son groupe de rangs change.
    private func startsGroup(at index: Int) -> Bool {
        guard index > 0, index < entries.count else { return false }
        let previous = EvEventScoring.leaderboardTier(rank: entries[index - 1].rank)
        let current = EvEventScoring.leaderboardTier(rank: entries[index].rank)
        return previous != current
    }
}

// MARK: - Ligne du classement

/// Ligne d'un participant : rang, nom, note, Elo et XP.
private struct EvEventLeaderboardRow: View {
    let entry: EvLeaderboardEntry
    let highlighted: Bool

    var body: some View {
        HStack(spacing: 12) {
            Text("\(entry.rank)")
                .font(.system(size: 16, weight: .black))
                .monospacedDigit()
                .foregroundStyle(Theme.ink)
                .frame(minWidth: 26, alignment: .leading)
            Text(entry.displayName)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .trailing, spacing: 1) {
                Text("\(EvEventScoring.formatScore(entry.score))/20")
                    .font(.system(size: 15, weight: .black))
                    .monospacedDigit()
                    .foregroundStyle(Theme.ink)
                Text("\(signed(entry.eloDelta)) Elo")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(Theme.inkSoft)
                Text("\(signed(entry.xpAwarded)) XP")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Theme.inkFaint)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusSmall)
                .stroke(highlighted ? Theme.ink : Theme.border, lineWidth: highlighted ? 2 : 1)
        )
    }

    /// Delta signé d'un nombre entier (« +12 », « -8 », « 0 »).
    private func signed(_ value: Int) -> String {
        value >= 0 ? "+\(value)" : "\(value)"
    }

    /// Delta signé d'un Elo décimal, sans zéro traîné (« +12 », « -8,5 »).
    private func signed(_ value: Double) -> String {
        let magnitude = value == value.rounded() ? String(Int(value)) : String(value)
        return value >= 0 ? "+\(magnitude)" : magnitude
    }
}
