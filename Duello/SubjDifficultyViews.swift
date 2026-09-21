import SwiftUI

/// Barème des points de difficulté.
///
/// `DIFFICULTY_DOTS` (`src/screens/SubjectsScreen.tsx`, ligne 1100) n'est qu'un
/// **alias de `DIFFICULTY_ORDER`** (`src/utils/itemDifficulty.ts`) : aucune
/// donnée nouvelle, on réutilise donc `TrainDifficulty.order`.
enum SubjDifficultyBarème {
    /// Port de `DIFFICULTY_DOTS` = `DIFFICULTY_ORDER` = `[1, 2, 3, 4, 5, 6]`.
    static let levels: [Int] = TrainDifficulty.order
}

/// Six points, remplis jusqu'au niveau de difficulté (`DifficultyDots`).
///
/// La variante standard est **rigoureusement identique** à
/// `TrainDifficultyDots` (écart 3, pastille 6×6, `border` → `ink`, la source
/// remplissant avec `colors.primary` = `#0A0D0C` = `Theme.ink`) : on la
/// délègue, sans recopier le barème ni les mesures.
///
/// Le seul apport propre à la source est le mode `compact` (styles
/// `badgeFilterDifficultyDots`/`badgeFilterDifficultyDot` : écart 2,
/// pastille 5×5), absent de `TrainDifficultyDots` — rendu ici.
struct SubjDifficultyDots: View {
    let level: Int
    var compact: Bool = false

    /// Écart des points en mode compact (`gap: 2`).
    private static let compactSpacing: CGFloat = 2
    /// Diamètre des points en mode compact (`width/height: 5`).
    private static let compactDotSize: CGFloat = 5

    var body: some View {
        if compact {
            HStack(spacing: Self.compactSpacing) {
                ForEach(SubjDifficultyBarème.levels, id: \.self) { dot in
                    Circle()
                        .fill(dot <= level ? Theme.ink : Theme.border)
                        .frame(width: Self.compactDotSize, height: Self.compactDotSize)
                }
            }
        } else {
            TrainDifficultyDots(level: level)
        }
    }
}

/// Pastille de difficulté (`DifficultyPill`) : les points, plus le libellé
/// quand le contexte le permet — « le filtre garde le libellé, la fiche
/// seulement les points ».
///
/// En mode standard, la pastille est **identique** à `TrainDifficultyPill`
/// (écart 6, marges 8/4, fond `surfaceMuted`, libellé 10 pt `heavy` `inkSoft`,
/// `accessibilityLabel` « Difficulté : … ») : on la délègue. Le mode `compact`
/// de la source (styles `badgeFilterValuePill`/`badgeFilterValueText` :
/// marges 5/4, écart 3, libellé 9 pt sur une seule ligne) est le seul apport
/// — rendu ici.
struct SubjDifficultyPill: View {
    let level: Int
    var compact: Bool = false
    var showsLabel: Bool = true

    /// Écart points/libellé en mode compact (`gap: 3`).
    private static let compactSpacing: CGFloat = 3
    /// `paddingHorizontal: 5` en mode compact.
    private static let compactHorizontalPadding: CGFloat = 5
    /// `paddingVertical: 4` en mode compact.
    private static let compactVerticalPadding: CGFloat = 4
    /// `fontSize: 9` du libellé en mode compact.
    private static let compactLabelSize: CGFloat = 9

    var body: some View {
        if compact {
            compactPill
        } else {
            TrainDifficultyPill(level: level, showsLabel: showsLabel)
        }
    }

    /// Pastille compacte : la source neutralise ici l'échelle standard pour
    /// tenir dans une ligne de filtres, libellé compris sur une seule ligne.
    private var compactPill: some View {
        HStack(spacing: Self.compactSpacing) {
            SubjDifficultyDots(level: level, compact: true)
            if showsLabel {
                Text(TrainDifficulty.label(for: level))
                    .font(.system(size: Self.compactLabelSize, weight: .heavy))
                    .foregroundStyle(Theme.inkSoft)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, Self.compactHorizontalPadding)
        .padding(.vertical, Self.compactVerticalPadding)
        .background(Theme.surfaceMuted)
        .clipShape(Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Difficulté : \(TrainDifficulty.label(for: level))")
    }
}
