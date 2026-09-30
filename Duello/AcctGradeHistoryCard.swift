//
//  AcctGradeHistoryCard.swift
//  Duello
//
//  Historique des notes du profil (lot S04, vague 6).
//
//  Fichier source Expo porté (libellés repris mot pour mot) :
//    - src/components/GradeHistoryCard.tsx (`GradeHistoryCard`,
//      `GradeHistoryRowView`).
//
//  Réutilise `GradeHistoryRow` (`RankingGradeHistory.swift`),
//  `ExGRemarkBadge` (`GradingRemarkBadge`), `ChartGradeEvolutionBadge`
//  (`GradeEvolutionBadge`) et `ExGFormat.score` (`formatGradingScore`).
//
//  L'état est figé, contrairement à la version animée du site : la carte est
//  rendue une fois par état de l'écran, comme la source.
//
//  Cible : iOS 16, aucune API iOS 17.
//
import SwiftUI

/// `GradeHistoryCard` de `src/components/GradeHistoryCard.tsx` : les dernières
/// corrections, de la plus récente à la plus ancienne, chacune avec sa
/// catégorie, son intitulé, son appréciation, son éventuel record, sa note sur
/// 20 et son évolution face à la note précédente.
struct AcctGradeHistoryCard: View {
    let rows: [GradeHistoryRow]

    var body: some View {
        if rows.isEmpty {
            EmptyView()
        } else {
            content
        }
    }

    /// Bandeau « Historique » puis la liste des lignes (`styles.list`, gap 7).
    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Historique")
                .font(.system(size: 11, weight: .bold))
                .tracking(1.1)
                .textCase(.uppercase)
                .foregroundStyle(Theme.inkFaint)
                .padding(.bottom, 8)
            VStack(spacing: 7) {
                ForEach(rows) { row in
                    rowView(row)
                }
            }
        }
    }

    /// Une ligne : intitulé à gauche, note et évolution à droite (`styles.row`).
    private func rowView(_ row: GradeHistoryRow) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text(row.category)
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.8)
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.ink)
                Text(row.title)
                    .font(.system(size: 13.5, weight: .bold))
                    .tracking(-0.14)
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                remarks(row)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            figure(row)
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 10)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
    }

    /// Pastille « Record » (seul aplat noir plein de la ligne) puis appréciation.
    private func remarks(_ row: GradeHistoryRow) -> some View {
        HStack(spacing: 6) {
            if row.record {
                Text("Record")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Theme.surface)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Theme.ink)
                    .clipShape(Capsule())
                    .accessibilityLabel("Record")
            }
            ExGRemarkBadge(score: row.score)
        }
        .padding(.top, 2)
    }

    /// Note sur 20 et pastille d'évolution (`styles.figure`).
    private func figure(_ row: GradeHistoryRow) -> some View {
        VStack(alignment: .trailing, spacing: 3) {
            Text(ExGFormat.score(row.score))
                .font(.system(size: 13, weight: .heavy))
                .monospacedDigit()
                .foregroundStyle(Theme.ink)
            if let percentage = row.evolutionPercentage {
                ChartGradeEvolutionBadge(percentage: percentage)
            }
        }
    }
}
