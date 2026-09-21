//
//  ChartSubjectTimeTrendChart.swift
//  Duello
//
//  Temps d'entraînement par période (lot D « Graphiques », préfixe `Chart`).
//
//  Fichier source Expo porté (libellés repris mot pour mot) :
//    - src/components/SubjectTimeTrendChart.tsx (`SubjectTimeTrendChart`,
//      `SubjectTimeChartWindow`, `MinuteAxis`, `ChartNavigation`,
//      `chartAccessibilityLabel`, `granularityName`)
//
//  Le geste de balayage et le défilement infini de l'Expo sont remplacés par la
//  pagination du kit (`ChartTimeNavigation`) et par `DuelloBarChart`
//  (`DuelloUI.swift`, Swift Charts). Cible iOS 16.
//
import Charts
import SwiftUI

/// `SubjectTimeTrendChart` : temps d'entraînement par période, avec pagination
/// de sept périodes et navigation calendaire.
struct ChartSubjectTimeTrendChart: View {
    /// Historique complet, de la période la plus ancienne à celle en cours.
    let buckets: [ChartTimeBucket]
    let granularity: ChartTimeGranularity

    @State private var pageIndex = 0

    private var pageCount: Int { ChartTimeNavigation.pageCount(buckets) }
    private var visible: [ChartTimeBucket] {
        ChartTimeNavigation.window(buckets, granularity, pageIndex: pageIndex)
    }
    private var maximum: Double {
        ChartTimeNavigation.minuteAxisMaximum(visible.map(\.minutes).max() ?? 0)
    }
    /// Barres de la fenêtre : la dernière période passe en `colors.ink` quand la
    /// page courante est affichée (`currentBar` de `SubjectTimeTrendChart.tsx`).
    private var bars: some View {
        Chart(visible.indices, id: \.self) { index in
            BarMark(
                x: .value("Période", ChartTimeSeries.axisLabel(visible[index].start, granularity)),
                y: .value("Minutes", visible[index].minutes)
            )
            .foregroundStyle(isCurrent(index) ? Theme.ink : Theme.inkSoft)
            .cornerRadius(4)
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .frame(height: 138)
    }

    /// Libellés de période, le dernier en gras quand la page courante est affichée.
    private var xAxis: some View {
        HStack(spacing: 2) {
            ForEach(visible.indices, id: \.self) { index in
                Text(ChartTimeSeries.axisLabel(visible[index].start, granularity))
                    .font(.system(size: 8, weight: isCurrent(index) ? .black : .bold))
                    .foregroundStyle(isCurrent(index) ? Theme.ink : Theme.inkFaint)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.top, 7)
        .padding(.leading, 38)
    }

    /// `pageIndex == 0` : la page courante ; seule la dernière barre s'y distingue.
    private func isCurrent(_ index: Int) -> Bool {
        pageIndex == 0 && index == visible.count - 1
    }
    private var accessibilityText: String {
        let values = visible.map {
            "\(ChartTimeSeries.title($0.start, granularity)) : \(Int($0.minutes.rounded())) minutes"
        }
        return "Durée d’entraînement \(granularity.name). \(values.joined(separator: ", "))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            navigationRow
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .bottom, spacing: 8) {
                    minuteAxis
                    bars
                }
                xAxis
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityText)
        }
        .onChange(of: granularity) { _ in pageIndex = 0 }
        .onChange(of: pageCount) { newValue in pageIndex = min(pageIndex, max(0, newValue - 1)) }
    }

    private var navigationRow: some View {
        HStack {
            arrow(
                systemName: "chevron.left",
                enabled: pageIndex < pageCount - 1,
                label: "Afficher les sept périodes précédentes"
            ) { select(pageIndex + 1) }
            Spacer(minLength: 8)
            Text(ChartTimeNavigation.pageLabel(granularity, pageIndex: pageIndex))
                .font(.system(size: 10, weight: .heavy))
                .foregroundStyle(Theme.inkSoft)
            Spacer(minLength: 8)
            arrow(
                systemName: "chevron.right",
                enabled: pageIndex > 0,
                label: "Afficher les sept périodes suivantes"
            ) { select(pageIndex - 1) }
        }
        .padding(.bottom, 12)
    }

    private var minuteAxis: some View {
        VStack(alignment: .trailing, spacing: 0) {
            Text("min").font(.system(size: 8, weight: .heavy))
            Spacer(minLength: 0)
            Text("\(Int(maximum.rounded()))").font(.system(size: 9, weight: .bold))
            Text("\(Int((maximum / 2).rounded()))").font(.system(size: 9, weight: .bold))
            Text("0").font(.system(size: 9, weight: .bold))
        }
        .foregroundStyle(Theme.inkFaint)
        .frame(width: 38, height: 151, alignment: .trailing)
    }

    private func arrow(
        systemName: String,
        enabled: Bool,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Theme.ink)
                .frame(width: 32, height: 32)
                .background(Theme.surfaceMuted)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.24)
        .accessibilityLabel(label)
    }

    private func select(_ page: Int) {
        pageIndex = max(0, min(pageCount - 1, page))
    }
}

/// `SubjectTimeChartWindow` : fenêtre statique pour un parent qui gère déjà la
/// navigation calendaire.
struct ChartSubjectTimeChartWindow: View {
    let buckets: [ChartTimeBucket]
    let granularity: ChartTimeGranularity

    private var chartPoints: [DuelloChartPoint] {
        buckets.map {
            DuelloChartPoint(label: ChartTimeSeries.axisLabel($0.start, granularity), value: $0.minutes)
        }
    }

    var body: some View {
        DuelloBarChart(points: chartPoints, tint: Theme.inkSoft)
            .accessibilityLabel("Durée d’entraînement \(granularity.name)")
    }
}
