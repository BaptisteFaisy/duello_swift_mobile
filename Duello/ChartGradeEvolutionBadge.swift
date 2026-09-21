//
//  ChartGradeEvolutionBadge.swift
//  Duello
//
//  Pastille d'évolution d'une note (lot D « Graphiques », préfixe `Chart`).
//
//  Fichier source Expo porté (libellés repris mot pour mot) :
//    - src/components/GradeEvolutionBadge.tsx (`GradeEvolutionBadge`)
//
//  Verte si la note progresse, rouge sinon ; la teinte vient de `Theme`
//  (`colors.progress` / `colors.like`, fonds clairs équivalents). Cible iOS 16.
//
import SwiftUI

/// `GradeEvolutionBadge` de `src/components/GradeEvolutionBadge.tsx` :
/// évolution de la note face à l'essai précédent.
struct ChartGradeEvolutionBadge: View {
    let percentage: Double

    private var rising: Bool { percentage > 0 }
    private var label: String { "\(rising ? "+" : "")\(formatted) %" }

    /// Nombre affiché sans décimale inutile, séparateur décimal français.
    private var formatted: String {
        percentage.rounded() == percentage
            ? "\(Int(percentage))"
            : ExGFormat.xp(percentage)
    }

    var body: some View {
        Text(label)
            .font(.system(size: 13, weight: .bold))
            .tracking(0.4)
            .foregroundStyle(rising ? Theme.progress : Theme.like)
            .padding(.horizontal, 10)
            .padding(.vertical, 3)
            .background(rising ? Theme.progressLight : exgLikeLight)
            .clipShape(Capsule())
            .accessibilityLabel("Évolution : \(label)")
    }
}
