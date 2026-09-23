//
//  ChartGradeChart.swift
//  Duello
//
//  Courbe chronologique des notes par type (lot D « Graphiques »,
//  préfixe `Chart`).
//
//  Fichier source Expo porté (libellés repris mot pour mot) :
//    - src/components/GradeChart.tsx (`GradeChart`, `SERIES_COLORS`,
//      `shortDate`)
//
//  Une ligne par type (DS, DM, Colle, TP, Autre), notes ramenées sur 20,
//  légende repliable des séries et lecture tactile par colonne. Réutilise
//  `ChartGradeSeries` (`ChartGradeSeries.swift`). Cible iOS 16.
//
import SwiftUI

/// Empilement horizontal qui passe à la ligne (`flexWrap: 'wrap'` de la légende).
private struct ChartWrapLayout: Layout {
    var spacing: CGFloat = 12

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0 && x + spacing + size.width > maxWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += (x > 0 ? spacing : 0) + size.width
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth.isFinite ? maxWidth : x, height: y + rowHeight)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX && x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

/// `GradeChart` de `src/components/GradeChart.tsx` : courbe des notes, ramenées
/// sur 20 pour rester comparables.
struct ChartGradeChart: View {
    let grades: [ChartGradeEntry]

    @State private var selectedIndex: Int?

    private let plotHeight: CGFloat = 138
    private let dotSize: CGFloat = 9
    private let axisWidth: CGFloat = 32
    /// `TOOLTIP_WIDTH`.
    private static let tooltipWidth: CGFloat = 168

    private var points: [ChartGradePoint] { ChartGradeSeries.buildPoints(grades) }
    private var series: [ChartGradeSeriesGroup] { ChartGradeSeries.buildSeries(points) }

    var body: some View {
        if points.isEmpty { EmptyView() } else { content }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            tooltipBand
            HStack(alignment: .top, spacing: 0) {
                axis
                plot
            }
            xAxis
            legend
        }
        .onChange(of: grades) { _ in selectedIndex = nil }
    }

    private var tooltipBand: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                if let index = selectedIndex, points.indices.contains(index) {
                    tooltip(index)
                        .padding(.leading, tooltipLeft(index, width: geo.size.width))
                }
            }
            .frame(width: geo.size.width, height: 45, alignment: .topLeading)
        }
        .frame(height: 45)
    }

    private func tooltip(_ index: Int) -> some View {
        let point = points[index]
        return VStack(alignment: .leading, spacing: 2) {
            Text("\(point.subject) · \(point.type.rawValue)")
                .font(.system(size: 10, weight: .heavy))
            Text("\(ExGFormat.xp(point.value))/20 · \(ChartDateFormat.shortDate(point.date))")
                .font(.system(size: 10, weight: .semibold))
        }
        .foregroundStyle(Theme.surface)
        .lineLimit(1)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .frame(width: Self.tooltipWidth, alignment: .leading)
        .background(Theme.ink)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
    }

    /// `left` de la source : bulle centrée sur le point puis bornée au tracé.
    private func tooltipLeft(_ index: Int, width: CGFloat) -> CGFloat {
        let plotWidth = max(width - axisWidth, 1)
        let innerWidth = max(plotWidth - dotSize, 1)
        let x = points.count < 2
            ? dotSize / 2 + innerWidth / 2
            : dotSize / 2 + innerWidth * CGFloat(index) / CGFloat(points.count - 1)
        let clamped = min(
            max(x - Self.tooltipWidth / 2, 0),
            max(plotWidth - Self.tooltipWidth, 0)
        )
        return axisWidth + clamped
    }

    private var axis: some View {
        VStack {
            Text("20")
            Spacer(minLength: 0)
            Text("10")
            Spacer(minLength: 0)
            Text("0")
        }
        .font(.system(size: 9, weight: .bold))
        .foregroundStyle(Theme.inkFaint)
        .frame(width: axisWidth, height: plotHeight, alignment: .trailing)
    }

    private var plot: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let innerWidth = max(width - dotSize, 1)
            let innerHeight = plotHeight - dotSize
            ZStack(alignment: .topLeading) {
                ForEach(0..<3, id: \.self) { step in
                    Rectangle()
                        .fill(Theme.border)
                        .frame(height: 1)
                        .offset(y: dotSize / 2 + innerHeight * CGFloat(step) / 2)
                }
                ForEach(series) { group in
                    linePath(group, innerWidth: innerWidth, innerHeight: innerHeight)
                        .stroke(group.type.color, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                }
                ForEach(Array(points.enumerated()), id: \.element.id) { index, point in
                    dot(point, index: index, innerWidth: innerWidth, innerHeight: innerHeight)
                }
                // Une colonne tactile par point, comme les `Pressable` de la source.
                HStack(spacing: 0) {
                    ForEach(points.indices, id: \.self) { index in
                        Color.clear
                            .contentShape(Rectangle())
                            .frame(maxWidth: .infinity)
                            .onTapGesture {
                                selectedIndex = selectedIndex == index ? nil : index
                            }
                    }
                }
                .frame(width: width, height: plotHeight)
            }
            .frame(width: width, height: plotHeight, alignment: .topLeading)
        }
        .frame(height: plotHeight)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Évolution de \(points.count) note\(points.count > 1 ? "s" : "") sur 20, répartie en \(series.count) courbe\(series.count > 1 ? "s" : "") par type")
    }

    private var xAxis: some View {
        HStack {
            Text(ChartDateFormat.shortDate(points[0].date))
            Spacer(minLength: 8)
            if points.count > 1 {
                Text(ChartDateFormat.shortDate(points[points.count - 1].date))
            }
        }
        .font(.system(size: 9, weight: .bold))
        .foregroundStyle(Theme.inkFaint)
        .padding(.top, 7)
        .padding(.leading, axisWidth)
    }

    private var legend: some View {
        ChartWrapLayout(spacing: 12) {
            ForEach(series) { group in
                HStack(spacing: 5) {
                    Circle().fill(group.type.color).frame(width: 8, height: 8)
                    Text(group.type.rawValue)
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundStyle(Theme.inkSoft)
                }
            }
        }
        .padding(.top, 12)
        .padding(.leading, axisWidth)
    }

    private func linePath(
        _ group: ChartGradeSeriesGroup,
        innerWidth: CGFloat,
        innerHeight: CGFloat
    ) -> Path {
        var path = Path()
        for (offset, point) in group.points.enumerated() {
            let index = points.firstIndex(of: point) ?? 0
            let location = CGPoint(x: xAt(index, innerWidth), y: yAt(point.value, innerHeight))
            if offset == 0 { path.move(to: location) } else { path.addLine(to: location) }
        }
        return path
    }

    private func dot(
        _ point: ChartGradePoint,
        index: Int,
        innerWidth: CGFloat,
        innerHeight: CGFloat
    ) -> some View {
        let isLastOfSeries = series.first { $0.type == point.type }?.points.last == point
        let strong = isLastOfSeries || index == selectedIndex
        return Circle()
            .fill(strong ? point.type.color : Theme.surface)
            .frame(width: dotSize, height: dotSize)
            .overlay(Circle().stroke(point.type.color, lineWidth: 2))
            .offset(
                x: xAt(index, innerWidth) - dotSize / 2,
                y: yAt(point.value, innerHeight) - dotSize / 2
            )
    }

    private func xAt(_ index: Int, _ innerWidth: CGFloat) -> CGFloat {
        let base = dotSize / 2
        guard points.count > 1 else { return base + innerWidth / 2 }
        return base + innerWidth * CGFloat(index) / CGFloat(points.count - 1)
    }

    private func yAt(_ value: Double, _ innerHeight: CGFloat) -> CGFloat {
        dotSize / 2 + innerHeight * CGFloat(1 - value / 20)
    }
}
