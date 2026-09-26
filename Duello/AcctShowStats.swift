//
//  AcctShowStats.swift
//  Duello
//
//  Vitrine du profil — statistiques, niveau, succès par matière et pied de
//  l'écran (lot 10-E, préfixe `AcctShow`).
//
//  Fichiers source Expo portés (libellés repris mot pour mot) :
//    - src/screens/AccountScreen.tsx, l. 2904-2915 (`accountMetricsPanel`,
//      `accountMetricsBars`, `levelProgress`)
//    - src/screens/AccountScreen.tsx, l. 3355-3392 (« Exos réussis par
//      matière », section masquée dans la source)
//    - src/screens/AccountScreen.tsx, l. 3444-3451 et
//      src/components/DownloadedChartWindow.tsx, l. 59-87
//      (`DownloadedChartPeriods`, « pied de l'écran » : la période choisie
//       pilote les quatre graphiques à la fois)
//
//  Réutilise `ChartPerformanceOverviewBar`, `ChartXpSummary`,
//  `ChartXpProgressBar`, `ChartSubjectSuccessChart`, `ChartSubjectSuccess`,
//  `ExGFormat.xp`, `AcctEvoConstants`, `DuelloChip` et l'habillage `AcctShow*`.
//
//  Cible : iOS 16, aucune API iOS 17 ; aucune dépendance externe.
//
import SwiftUI

/// Bandeau de statistiques de la vitrine (`accountMetricsPanel`) : repères
/// généraux, repères détaillés, puis la progression du niveau d'XP.
struct AcctShowStatsPanel: View {
    /// Repères généraux (`metricRows.overview` : XP, Elo, série, programme).
    let overview: [ChartPerformanceOverviewStat]
    /// Repères détaillés (`metricRows.details` : niveau, défis, exercices, temps).
    let details: [ChartPerformanceOverviewStat]
    /// Niveau d'XP du profil consulté (`viewedXpSummary`).
    let xpSummary: ChartXpSummary

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                ChartPerformanceOverviewBar(
                    stats: overview,
                    refined: AcctEvoConstants.useRefinedOverview,
                    hideStatDividers: true
                )
                ChartPerformanceOverviewBar(
                    stats: details,
                    refined: AcctEvoConstants.useRefinedOverview,
                    hideStatDividers: true
                )
            }
            .padding(.top, 14)
            .padding(.horizontal, 12)

            AcctShowLevelProgress(summary: xpSummary)
        }
        .background(Theme.background)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLarge))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusLarge)
                .stroke(Theme.border, lineWidth: 1)
        )
        .padding(.top, 12)
    }
}

/// Progression du niveau d'XP de la vitrine (`levelProgress`) : titre, total,
/// barre et légende.
struct AcctShowLevelProgress: View {
    /// Résumé d'XP du profil consulté.
    let summary: ChartXpSummary
    /// Titre court (« Niveau 3 ») plutôt que « Progression du niveau 3 ».
    var compactTitle: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Text("\(compactTitle ? "Niveau" : "Progression du niveau") \(summary.level)")
                    .font(.system(size: 11, weight: .black))
                    .foregroundStyle(Theme.ink)
                Spacer(minLength: 0)
                Text("\(ExGFormat.xp(summary.total)) XP")
                    .font(.system(size: 11, weight: .black))
                    .foregroundStyle(Theme.ink)
            }

            ChartXpProgressBar(
                progress: summary.progress,
                height: 9,
                trackColor: Theme.surfaceMuted,
                fillColor: Theme.ink
            )

            Text(legend)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(Theme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
    }

    /// Légende : progression dans le niveau, ou plafond atteint.
    private var legend: String {
        summary.isMaxLevel
            ? "Niveau maximum atteint. Rien au-dessus, bravo."
            : "\(ExGFormat.xp(summary.intoLevel))/\(ExGFormat.xp(summary.levelSpan)) XP · encore \(ExGFormat.xp(summary.toNextLevel)) XP avant le niveau \(summary.level + 1)"
    }
}

/// Section « Exos réussis par matière » de la vitrine (`AccountScreen.tsx`,
/// l. 3355-3392) : compteur réussi/total et taux par matière.
struct AcctShowSubjectSuccessSection: View {
    /// Réussites par matière (`subjectSuccesses`).
    let entries: [ChartSubjectSuccess]
    /// Vrai lorsque la vitrine affiche le profil d'un autre membre.
    var isMember: Bool = false

    private var succeeded: Int { entries.reduce(0) { $0 + $1.succeeded } }
    private var total: Int { entries.reduce(0) { $0 + $1.total } }

    var body: some View {
        AcctShowSectionCard(
            icon: "checkmark.circle",
            iconColor: ChartGoogleGColors.red,
            title: "Exos réussis par matière",
            subtitle: "Exercices, colles et annales entièrement réussis",
            trailing: trailingTotal
        ) {
            if total > 0 {
                ChartSubjectSuccessChart(entries: entries)
            } else {
                AcctShowChartEmpty(icon: "graduationcap", message: emptyMessage)
            }
        }
    }

    /// Compteur réussi/total (`timeHeadlineValue`), masqué sans donnée.
    private var trailingTotal: AnyView? {
        guard total > 0 else { return nil }
        return AnyView(
            Text("\(succeeded)/\(total)")
                .font(.system(size: 16, weight: .black))
                .foregroundStyle(Theme.ink)
        )
    }

    /// Explique l'absence de réussites (`chartEmptyText`).
    private var emptyMessage: String {
        isMember
            ? "Aucune réussite par matière publiée pour le moment."
            : "Aucun exercice disponible dans ton programme pour l’instant. La barre se remplira dès qu’une matière aura des sujets."
    }
}

/// Pied de la vitrine (`DownloadedChartPeriods`) : la période choisie
/// s'applique d'un coup aux quatre graphiques.
struct AcctShowPeriodFooter: View {
    /// Période commune aux quatre graphiques.
    let value: ChartTimeGranularity
    /// Applique la période aux quatre graphiques.
    let onChange: (ChartTimeGranularity) -> Void

    var body: some View {
        HStack(spacing: 8) {
            ForEach(ChartTimeGranularity.allCases, id: \.self) { period in
                periodButton(period)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 18)
        .padding(.bottom, 12)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Période des quatre graphiques")
    }

    /// Un bouton de période ; fond d'encre quand il est actif.
    private func periodButton(_ period: ChartTimeGranularity) -> some View {
        let selected = period == value
        return Button {
            onChange(period)
        } label: {
            Text(AcctShowGranularityTabs.label(for: period))
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(selected ? Theme.surface : Theme.ink)
                .padding(.horizontal, 22)
                .padding(.vertical, 10)
                .background(selected ? Theme.ink : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }
}
