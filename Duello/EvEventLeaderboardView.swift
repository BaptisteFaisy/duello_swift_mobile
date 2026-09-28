//
//  EvEventLeaderboardView.swift
//  Duello
//
//  Classement publié d'un événement : une ligne par participant (rang, icône du
//  compte, prénom, puis sur la même ligne la note sur 20 avec trois décimales
//  au plus, l'Elo gagné et les XP gagnés). Les trois premiers forment un premier
//  groupe, les sept suivants un deuxième, les autres s'affichent ensemble ; les
//  ex æquo partagent leur rang. Chaque ligne ouvre le profil du compte.
//
//  Fichier source Expo porté : `src/components/event/EventLeaderboardView.tsx`.
//
//  La présence temps réel (`usePresence`, socket) est lue via le store partagé
//  `SocPresenceStore`, comme la feuille des vues.
//
//  Cible : iOS 16.
//
import SwiftUI

struct EvEventLeaderboardView: View {
    let entries: [EvLeaderboardEntry]
    let ownId: String?
    /// Ouvre le profil du compte choisi ; `nil` laisse les lignes inactives.
    var onOpenProfile: ((String) -> Void)? = nil

    var body: some View {
        VStack(spacing: 6) {
            ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                if startsGroup(at: index) {
                    Color.clear.frame(height: 10)
                }
                EvEventLeaderboardRow(
                    entry: entry,
                    highlighted: entry.id == ownId,
                    onOpenProfile: onOpenProfile
                )
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

/// Ligne d'un participant : rang, avatar, prénom, note, Elo et XP.
private struct EvEventLeaderboardRow: View {
    let entry: EvLeaderboardEntry
    let highlighted: Bool
    let onOpenProfile: ((String) -> Void)?

    var body: some View {
        Button {
            onOpenProfile?(entry.id)
        } label: {
            HStack(spacing: 10) {
                Text("\(entry.rank)")
                    .font(.system(size: 15, weight: .black))
                    .monospacedDigit()
                    .foregroundStyle(Theme.ink)
                    .frame(minWidth: 24, alignment: .leading)
                SocialAvatarPresence(online: SocPresenceStore.shared.isOnline(entry.id), dotSize: 10) {
                    LeaderboardAvatar(
                        initial: initial,
                        photoUri: entry.photoUri,
                        size: 30,
                        background: Theme.surfaceMuted,
                        foreground: Theme.inkSoft
                    )
                }
                Text(entry.displayName)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                metrics
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 12)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusSmall)
                    .stroke(highlighted ? Theme.ink : Theme.border, lineWidth: highlighted ? 2 : 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(EvLeaderboardRowStyle())
        .disabled(onOpenProfile == nil)
        .accessibilityLabel(
            "Voir le profil de \(entry.displayName), rang \(entry.rank), \(EvEventScoring.formatScore(entry.score)) sur 20"
        )
    }

    /// Note, Elo et XP sur une seule ligne, alignés sur la ligne de base.
    private var metrics: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("\(EvEventScoring.formatScore(entry.score))/20")
                .font(.system(size: 14, weight: .black))
                .monospacedDigit()
                .foregroundStyle(Theme.ink)
            Text("\(signed(entry.eloDelta)) Elo")
                .font(.system(size: 11, weight: .heavy))
                .monospacedDigit()
                .foregroundStyle(Theme.inkSoft)
            Text("\(signed(entry.xpAwarded)) XP")
                .font(.system(size: 10, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(Theme.inkFaint)
        }
    }

    /// Première lettre du prénom, en capitale ; « ? » sans nom, comme la source.
    private var initial: String {
        guard let first = entry.displayName.first else { return "?" }
        return String(first).uppercased()
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

/// Ligne estompée à l'appui (`rowPressed`).
private struct EvLeaderboardRowStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.opacity(configuration.isPressed ? 0.72 : 1)
    }
}
