//
//  ChartXpLevelCard.swift
//  Duello
//
//  Carte sombre du niveau d'XP (lot D « Graphiques », préfixe `Chart`).
//
//  Fichier source Expo porté (libellés repris mot pour mot) :
//    - src/components/XpLevelCard.tsx (`XpLevelCard`, `XpCardStat`,
//      `activityStats`)
//
//  Carte en dégradé sombre (`#161C1A` → `#0A0D0C`), barre d'XP et compteurs
//  d'entraînement. Réutilise `ChartXpProgressBar`, `ExGFormat.xp` et
//  `ProgressStore.formatTrainingTime`. Cible iOS 16.
//
import SwiftUI

/// `XpSummary` de `utils/xp.ts` réduit aux champs de la carte.
struct ChartXpSummary: Hashable {
    var level: Int
    var total: Double
    var progress: Double
    var intoLevel: Double
    var levelSpan: Double
    var toNextLevel: Double
    var isMaxLevel: Bool
}

/// `XpCardStat` de `XpLevelCard.tsx` : compteur d'entraînement (icône, valeur, libellé).
struct ChartXpCardStat: Identifiable, Hashable {
    var icon: String
    var value: String
    var label: String
    var id: String { label }
}

/// `activityStats` de `XpLevelCard.tsx` : compteurs communs aux écrans qui
/// affichent la carte d'XP.
enum ChartActivityStats {
    static func build(
        challenges: Int,
        exercises: Int,
        questions: Int,
        exerciseMinutes: Int,
        streak: Int? = nil
    ) -> [ChartXpCardStat] {
        var stats = [
            ChartXpCardStat(icon: "bolt", value: "\(challenges)", label: "Défis"),
            ChartXpCardStat(icon: "checkmark.circle", value: "\(exercises)", label: "Exercices"),
            ChartXpCardStat(icon: "sparkles", value: "\(questions)", label: "Questions"),
            ChartXpCardStat(
                icon: "timer",
                value: ProgressStore.formatTrainingTime(minutes: exerciseMinutes),
                label: "Entraînement"
            ),
        ]
        if let streak {
            stats.append(ChartXpCardStat(icon: "flame", value: "\(streak) j", label: "Série"))
        }
        return stats
    }
}

/// `XpLevelCard` de `src/components/XpLevelCard.tsx` : carte du niveau d'XP,
/// barre de progression et compteurs d'entraînement.
struct ChartXpLevelCard: View {
    let summary: ChartXpSummary
    /// Compteurs affichés sous la barre.
    var stats: [ChartXpCardStat] = []
    /// Rend la carte cliquable, vers le détail de l'XP.
    var onPress: (() -> Void)? = nil
    /// Gain mis en avant juste après une session terminée.
    var highlightedGain: Double? = nil
    /// Variation d'Elo du défi qui vient de se terminer, positive ou négative.
    var eloDelta: Int? = nil
    /// À `false` (bilan de fin de défi), on épure : ni total ni légende.
    var showsTotal: Bool = true

    private var showsGain: Bool { (highlightedGain ?? 0) > 0 }
    private var showsElo: Bool { eloDelta != nil }
    private var showsHeader: Bool { showsGain || showsElo || onPress != nil }
    private var columns: Int { stats.isEmpty || stats.count <= 4 ? stats.count : 3 }

    var body: some View {
        if let onPress {
            Button(action: onPress) { cardBody }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    "Niveau \(summary.level), \(ExGFormat.xp(summary.total)) XP. Voir le détail de mon expérience"
                )
        } else {
            cardBody
        }
    }

    private var cardBody: some View {
        VStack(alignment: .leading, spacing: 0) {
            if showsHeader { header }
            levelRow
            ChartXpProgressBar(
                progress: summary.progress,
                height: 9,
                trackColor: Color.white.opacity(0.14),
                fillColor: Theme.progress
            )
            .padding(.top, 14)
            if showsTotal { legend.padding(.top, 9) }
            if !stats.isEmpty { statsGrid.padding(.top, 17) }
        }
        .padding(18)
        .background(
            LinearGradient(
                colors: [Color(hex: 0x161C1A), Color(hex: 0x0A0D0C)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLarge))
    }

    private var header: some View {
        HStack(spacing: 7) {
            Spacer(minLength: 0)
            if showsGain {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up").font(.system(size: 10, weight: .heavy))
                    Text("\(ExGFormat.xp(highlightedGain ?? 0)) XP")
                        .font(.system(size: 10, weight: .heavy))
                }
                .foregroundStyle(Theme.ink)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.white)
                .clipShape(Capsule())
            }
            if showsElo, let eloDelta {
                HStack(spacing: 4) {
                    Image(systemName: eloDelta < 0 ? "arrow.down" : "arrow.up")
                        .font(.system(size: 10, weight: .heavy))
                    Text("\(eloDelta < 0 ? "" : "+")\(eloDelta) Elo")
                        .font(.system(size: 10, weight: .heavy))
                }
                .foregroundStyle(Color.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .overlay(Capsule().stroke(Color.white.opacity(0.28), lineWidth: 1))
            }
            if !showsGain && !showsElo {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.45))
            }
        }
    }

    private var levelRow: some View {
        HStack(alignment: .bottom, spacing: 0) {
            Text("NIVEAU")
                .font(.system(size: 9, weight: .heavy))
                .tracking(1.4)
                .foregroundStyle(Color.white.opacity(0.55))
                .padding(.bottom, 7)
            Text("\(summary.level)")
                .font(.system(size: 42, weight: .heavy))
                .tracking(-1.5)
                .foregroundStyle(Color.white)
                .padding(.leading, 8)
            Spacer(minLength: 8)
            if showsTotal {
                Text("\(ExGFormat.xp(summary.total)) XP")
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundStyle(Color.white)
                    .padding(.bottom, 7)
            }
        }
        .padding(.top, showsHeader ? 16 : 0)
    }

    private var legend: some View {
        Text(
            summary.isMaxLevel
                ? "Niveau maximum atteint. Rien au-dessus, bravo."
                : "\(ExGFormat.xp(summary.intoLevel))/\(ExGFormat.xp(summary.levelSpan)) XP · encore \(ExGFormat.xp(summary.toNextLevel)) XP avant le niveau \(summary.level + 1)"
        )
        .font(.system(size: 10, weight: .semibold))
        .foregroundStyle(Color.white.opacity(0.7))
        .fixedSize(horizontal: false, vertical: true)
    }

    private var statsGrid: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: max(1, columns)),
            spacing: 14
        ) {
            ForEach(stats) { stat in
                VStack(spacing: 4) {
                    Image(systemName: stat.icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.55))
                    Text(stat.value)
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundStyle(Color.white)
                        .lineLimit(1)
                    Text(stat.label)
                        .font(.system(size: 8, weight: .heavy))
                        .textCase(.uppercase)
                        .tracking(0.5)
                        .foregroundStyle(Color.white.opacity(0.5))
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.top, 15)
        .overlay(alignment: .top) {
            Rectangle().fill(Color.white.opacity(0.16)).frame(height: 0.5)
        }
    }
}
