//
//  ChartGradeEvolutionBadge.swift
//  Duello
//
//  Pastille d'évolution d'une note (lot D « Graphiques », préfixe `Chart`).
//
//  Fichier source Expo porté (libellés repris mot pour mot) :
//    - src/components/GradeEvolutionBadge.tsx (`GradeEvolutionBadge`)
//
//  Verte si la note progresse, grise si elle stagne, rouge sinon : la teinte
//  suit `gradeEvolutionTone` (`EVOLUTION_TONE_COLORS`). Cible iOS 16.
//
import SwiftUI

/// `GradeEvolutionBadge` de `src/components/GradeEvolutionBadge.tsx` :
/// évolution de la note face à l'essai précédent.
struct ChartGradeEvolutionBadge: View {
    let percentage: Double

    private var tone: ExGGradeEvolutionTone { exgGradeEvolutionTone(percentage) }
    private var label: String { "\(percentage > 0 ? "+" : "")\(formatted) %" }

    /// Nombre affiché sans décimale inutile, séparateur décimal français.
    private var formatted: String {
        percentage.rounded() == percentage
            ? "\(Int(percentage))"
            : ExGFormat.xp(percentage)
    }

    /// `EVOLUTION_TONE_COLORS` : encre grise à zéro, comme la source.
    private var foreground: Color {
        switch tone {
        case .rising: return Theme.progress
        case .steady: return Theme.inkSoft
        case .falling: return Theme.like
        }
    }

    private var background: Color {
        switch tone {
        case .rising: return Theme.progressLight
        case .steady: return Theme.surfaceMuted
        case .falling: return exgLikeLight
        }
    }

    var body: some View {
        Text(label)
            .font(.system(size: 13, weight: .bold))
            .tracking(0.4)
            .foregroundStyle(foreground)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(background)
            .clipShape(Capsule())
            .accessibilityLabel("Évolution : \(label)")
    }
}
