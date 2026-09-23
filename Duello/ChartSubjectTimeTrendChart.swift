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
//  Les barres maison (largeur 7, rayon 3,5), les trois repères de grille, le
//  geste de balayage (`resolveTimeChartSwipePage`) et l'accessibilité réglable
//  sont repris de la source ; la pagination s'appuie sur `ChartTimeNavigation`.
//  Cible iOS 16.
//
import SwiftUI

/// `chartAccessibilityLabel` de `SubjectTimeTrendChart.tsx`.
private func chartTimeAccessibility(
    _ buckets: [ChartTimeBucket],
    _ granularity: ChartTimeGranularity
) -> String {
    let values = buckets.map {
        "\(ChartTimeSeries.title($0.start, granularity)) : \(Int($0.minutes.rounded())) minutes"
    }
    return "Durée d’entraînement \(granularity.name). \(values.joined(separator: ", "))"
}

/// `PLOT_HEIGHT` de la source.
private let chartTimePlotHeight: CGFloat = 138
/// `BAR_WIDTH` / rayon d'une barre.
private let chartTimeBarWidth: CGFloat = 7

/// `MinuteAxis` de `SubjectTimeTrendChart.tsx` : « min » puis l'axe des minutes.
private struct ChartMinuteAxis: View {
    let maximum: Double

    var body: some View {
        VStack(alignment: .trailing, spacing: 0) {
            Text("min")
                .font(.system(size: 8, weight: .heavy))
                .frame(maxWidth: .infinity, alignment: .trailing)
                .frame(height: 13)
            VStack(alignment: .trailing, spacing: 0) {
                Text("\(Int(maximum.rounded()))")
                Spacer(minLength: 0)
                Text("\(Int((maximum / 2).rounded()))")
                Spacer(minLength: 0)
                Text("0")
            }
            .font(.system(size: 9, weight: .bold))
            .frame(height: chartTimePlotHeight)
        }
        .foregroundStyle(Theme.inkFaint)
        .frame(width: 38, height: chartTimePlotHeight + 13, alignment: .trailing)
    }
}

/// `TimeBars` de `SubjectTimeTrendChart.tsx` : trois repères et une barre par période.
private struct ChartTimeBars: View {
    let buckets: [ChartTimeBucket]
    let maximum: Double
    let highlightLast: Bool

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let slot = width / CGFloat(max(buckets.count, 1))
            ZStack(alignment: .topLeading) {
                ForEach(0..<3, id: \.self) { step in
                    Rectangle()
                        .fill(Theme.border)
                        .frame(width: width, height: 1)
                        .offset(y: chartTimePlotHeight * CGFloat(step) / 2)
                }
                ForEach(Array(buckets.enumerated()), id: \.element.id) { index, bucket in
                    let height = bucket.minutes <= 0
                        ? 0
                        : max(2, (bucket.minutes / maximum) * chartTimePlotHeight)
                    RoundedRectangle(cornerRadius: chartTimeBarWidth / 2)
                        .fill(highlightLast && index == buckets.count - 1 ? Theme.ink : Theme.inkSoft)
                        .frame(width: chartTimeBarWidth, height: height)
                        .offset(
                            x: slot * CGFloat(index) + slot / 2 - chartTimeBarWidth / 2,
                            y: chartTimePlotHeight - height
                        )
                }
            }
            .frame(width: width, height: chartTimePlotHeight, alignment: .topLeading)
        }
        .frame(height: chartTimePlotHeight)
    }
}

/// État d'un geste de balayage : dernière abscisse, instant et vitesse estimée.
private struct ChartTimeSwipeTracker {
    var lastX: CGFloat = 0
    var lastTime: Date? = nil
    var velocity: Double = 0
}

/// `SubjectTimeTrendChart` : temps d'entraînement par période, avec pagination
/// de sept périodes, navigation calendaire et balayage horizontal.
struct ChartSubjectTimeTrendChart: View {
    /// Historique complet, de la période la plus ancienne à celle en cours.
    let buckets: [ChartTimeBucket]
    let granularity: ChartTimeGranularity

    @State private var pageIndex = 0
    @State private var swipe = ChartTimeSwipeTracker()

    private var pageCount: Int { ChartTimeNavigation.pageCount(buckets) }
    private var visible: [ChartTimeBucket] {
        ChartTimeNavigation.window(buckets, granularity, pageIndex: pageIndex)
    }
    private var maximum: Double {
        ChartTimeNavigation.minuteAxisMaximum(visible.map(\.minutes).max() ?? 0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            navigationRow
            chartBody
        }
        .onChange(of: granularity) { _ in pageIndex = 0 }
        .onChange(of: pageCount) { newValue in pageIndex = min(pageIndex, max(0, newValue - 1)) }
    }

    private var chartBody: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .bottom, spacing: 0) {
                ChartMinuteAxis(maximum: maximum)
                ChartTimeBars(buckets: visible, maximum: maximum, highlightLast: pageIndex == 0)
            }
            xAxis
        }
        .contentShape(Rectangle())
        .gesture(swipeGesture)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(chartTimeAccessibility(visible, granularity))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: select(pageIndex - 1)
            case .decrement: select(pageIndex + 1)
            default: break
            }
        }
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

    private func arrow(
        systemName: String,
        enabled: Bool,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 18, weight: .bold))
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

    /// Balayage horizontal : la page atteinte suit `resolveTimeChartSwipePage`.
    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 6)
            .onChanged { value in
                let now = Date()
                if let previous = swipe.lastTime {
                    let delta = now.timeIntervalSince(previous)
                    if delta > 0.0001 {
                        swipe.velocity = Double(value.translation.width - swipe.lastX) / delta
                    }
                }
                swipe.lastX = value.translation.width
                swipe.lastTime = now
            }
            .onEnded { value in
                let velocity = swipe.velocity
                swipe = ChartTimeSwipeTracker()
                // Intention horizontale nette seulement (`horizontalGesture.ts`).
                guard abs(value.translation.width) > abs(value.translation.height) * 1.5 else { return }
                pageIndex = ChartTimeNavigation.resolveSwipePage(
                    pageCount: pageCount,
                    currentPage: pageIndex,
                    translationX: Double(value.translation.width),
                    velocityX: velocity
                )
            }
    }
}

/// `SubjectTimeChartWindow` : fenêtre statique pour un parent qui gère déjà la
/// navigation calendaire.
struct ChartSubjectTimeChartWindow: View {
    let buckets: [ChartTimeBucket]
    let granularity: ChartTimeGranularity

    private var maximum: Double {
        ChartTimeNavigation.minuteAxisMaximum(buckets.map(\.minutes).max() ?? 0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .bottom, spacing: 0) {
                ChartMinuteAxis(maximum: maximum)
                ChartTimeBars(buckets: buckets, maximum: maximum, highlightLast: false)
            }
            HStack(spacing: 2) {
                ForEach(buckets.indices, id: \.self) { index in
                    Text(ChartTimeSeries.axisLabel(buckets[index].start, granularity))
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(Theme.inkFaint)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.top, 7)
            .padding(.leading, 38)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(chartTimeAccessibility(buckets, granularity))
    }
}
