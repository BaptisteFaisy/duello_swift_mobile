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
//  légende des séries et lecture tactile. Réutilise `ChartGradeSeries`
//  (`ChartGradeSeries.swift`). Cible iOS 16.
//
import SwiftUI

/// `GradeChart` de `src/components/GradeChart.tsx` : courbe des notes, ramenées
/// sur 20 pour rester comparables.
struct ChartGradeChart: View {
    let grades: [ChartGradeEntry]

    @State private var selectedIndex: Int?

    private let plotHeight: CGFloat = 138
    private let dotSize: CGFloat = 9

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
        ZStack {
            if let index = selectedIndex, points.indices.contains(index) {
                let point = points[index]
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(point.subject) · \(point.type.rawValue)")
                        .font(.system(size: 10, weight: .heavy))
                    Text("\(ExGFormat.xp(point.value))/20 · \(ChartDateFormat.shortDate(point.date))")
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundStyle(Theme.surface)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(Theme.ink)
                .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
            }
        }
        .frame(maxWidth: .infinity, minHeight: 45, alignment: .center)
        .padding(.leading, 32)
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
        .frame(width: 32, height: plotHeight, alignment: .trailing)
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
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .frame(width: width, height: plotHeight)
                    .gesture(
                        DragGesture(minimumDistance: 0).onChanged { value in
                            selectedIndex = nearestIndex(x: value.location.x, innerWidth: innerWidth)
                        }
                    )
            }
            .frame(width: width, height: plotHeight, alignment: .topLeading)
        }
        .frame(height: plotHeight)
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
        .padding(.leading, 32)
    }

    private var legend: some View {
        HStack(spacing: 12) {
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
        .padding(.leading, 32)
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

    private func nearestIndex(x: CGFloat, innerWidth: CGFloat) -> Int? {
        guard !points.isEmpty else { return nil }
        guard points.count > 1 else { return 0 }
        let ratio = (Double(x) - Double(dotSize / 2)) / Double(innerWidth)
        let index = Int((ratio * Double(points.count - 1)).rounded())
        return min(max(index, 0), points.count - 1)
    }
}
