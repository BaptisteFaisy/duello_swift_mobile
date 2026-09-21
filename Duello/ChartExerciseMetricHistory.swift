//
//  ChartExerciseMetricHistory.swift
//  Duello
//
//  Historique des essais d'un exercice (lot D « Graphiques », préfixe `Chart`).
//
//  Fichier source Expo porté (libellés repris mot pour mot) :
//    - src/components/ExerciseMetricHistory.tsx (`ExerciseMetricHistoryPage`,
//      `HistoryCard`, `HistoryMetric`, `historyDate`)
//
//  Réutilise `ExGRemarkBadge` (`ExGCorrectionSummaryViews.swift`),
//  `ChartGradeEvolutionBadge`, `ExGFormat` et `DuelloEmptyState` — la source
//  importait `GradingRemarkBadge`, `GradeEvolutionBadge` et
//  `ExercisePageEmptyState`. Cible iOS 16.
//
import SwiftUI

/// `AnnaleMetricHistoryEntry` de `utils/annaleAttempt.ts` réduit aux mesures
/// affichées par l'historique des essais.
struct ChartMetricHistoryEntry: Identifiable, Hashable {
    var submissionId: String
    var submittedAt: String
    var score: Double
    var spentSeconds: Double
    var firstTry: Bool
    var attemptNumber: Int
    var improvementPercentage: Double?
    var rank: Int?
    var id: String { submissionId }
}

/// `ExerciseMetricHistoryPage` de `src/components/ExerciseMetricHistory.tsx` :
/// page des essais du compte sur l'exercice, du plus récent au plus ancien.
struct ChartExerciseMetricHistory: View {
    let history: [ChartMetricHistoryEntry]
    var backLabel: String = "Retour"
    var onBack: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let onBack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Theme.ink)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(backLabel)
                .padding(.horizontal, 8)
            }
            if history.isEmpty {
                DuelloEmptyState(icon: "clock", title: "Aucun historique")
            } else {
                list
            }
        }
    }

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(history.reversed()) { entry in
                    card(entry)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
    }

    private func card(_ entry: ChartMetricHistoryEntry) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 10) {
                    Text("Essai \(entry.attemptNumber)")
                        .font(.system(size: 16))
                        .foregroundStyle(Theme.ink)
                    ExGRemarkBadge(score: entry.score)
                    if let improvement = entry.improvementPercentage {
                        ChartGradeEvolutionBadge(percentage: improvement)
                    }
                }
                Text(ChartDateFormat.historyDate(entry.submittedAt))
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.inkSoft)
            }
            HStack(spacing: 4) {
                metric(label: "Note", value: ExGFormat.score(entry.score))
                metric(label: "Rang", value: ExGFormat.rank(entry.rank))
                metric(label: "Temps", value: ExGFormat.duration(entry.spentSeconds))
            }
            if entry.firstTry {
                Text("Réussi du premier coup")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(Theme.primary)
            }
        }
        .padding(15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLarge))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusLarge)
                .stroke(Theme.border, lineWidth: 1)
        )
    }

    private func metric(label: String, value: String) -> some View {
        VStack(spacing: 3) {
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Theme.inkSoft)
            Text(value)
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 9)
        .background(Theme.surfaceMuted)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
    }
}
