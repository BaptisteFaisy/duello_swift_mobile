import SwiftUI

/// Paliers de difficulté servis par l'API (`DIFFICULTY_ORDER` de
/// `src/utils/itemDifficulty.ts`) et leurs libellés (`DIFFICULTY_LABELS`).
enum TrainDifficulty {
    /// Ordre de présentation : on entre dans un chapitre par le plus accessible.
    static let order: [Int] = [1, 2, 3, 4, 5, 6]

    /// Libellé d'un palier ; chaîne vide pour un palier hors barème.
    static func label(for level: Int) -> String {
        switch level {
        case 1: return "Très facile"
        case 2: return "Facile"
        case 3: return "Moyen"
        case 4: return "Difficile"
        case 5: return "Très difficile"
        case 6: return "Extrême"
        default: return ""
        }
    }
}

/// Six points, remplis jusqu'au niveau de difficulté (`DifficultyDots`).
struct TrainDifficultyDots: View {
    let level: Int

    var body: some View {
        HStack(spacing: 3) {
            ForEach(TrainDifficulty.order, id: \.self) { dot in
                Circle()
                    .fill(dot <= level ? Theme.ink : Theme.border)
                    .frame(width: 6, height: 6)
            }
        }
    }
}

/// Pastille de difficulté : les points, et le libellé quand le contexte le
/// permet (`DifficultyPill`).
struct TrainDifficultyPill: View {
    let level: Int
    var showsLabel: Bool = true

    var body: some View {
        HStack(spacing: 6) {
            TrainDifficultyDots(level: level)
            if showsLabel {
                Text(TrainDifficulty.label(for: level))
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundStyle(Theme.inkSoft)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Theme.surfaceMuted)
        .clipShape(Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Difficulté : \(TrainDifficulty.label(for: level))")
    }
}
