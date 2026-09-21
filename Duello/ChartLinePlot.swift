//
//  ChartLinePlot.swift
//  Duello
//
//  Courbe lissée partagée par les graphiques `Chart…` (lot D « Graphiques »).
//
//  Reprend la géométrie commune à :
//    - src/components/XpChart.tsx            (axe min/max, lecture tactile)
//    - src/components/EloChart.tsx
//    - src/components/CorrectionGradeChart.tsx
//    - src/components/SubjectSuccessChart.tsx
//
//  Repères à 0/50/100 %, marge d'un demi-point, tracé continu via
//  `ChartSmoothPath`. Les bornes `lower`/`upper` sont fournies par l'appelant
//  (déjà étendues de la marge propre à chaque graphique). Cible iOS 16.
//
import SwiftUI

/// Point d'une courbe lissée : valeur numérique et texte d'infobulle.
struct ChartLinePoint: Identifiable, Hashable {
    let id = UUID()
    var value: Double
    var tooltip: String
    /// Seconde ligne de l'infobulle (`tooltipDate`, `tooltipCount`…), quand la
    /// source empile deux lignes au lieu de les joindre.
    var tooltipDetail: String? = nil
}

/// Courbe lissée réutilisable : repères, tracé, points et lecture d'une période.
struct ChartSmoothLineChart: View {
    let points: [ChartLinePoint]
    let lower: Double
    let upper: Double
    let topAxisLabel: String
    let bottomAxisLabel: String
    let firstAxisLabel: String
    let lastAxisLabel: String
    let accessibility: String
    var height: CGFloat = 128
    var dotSize: CGFloat = 6
    var axisWidth: CGFloat = 38
    var tooltipHeight: CGFloat = 28
    var tint: Color = Theme.ink
    var showsDateRange: Bool = true
    /// Retrait de la bande d'infobulle ; par défaut celui de l'axe.
    var tooltipLeading: CGFloat? = nil
    /// `MAX_VISIBLE_DOTS` : au-delà, seuls le dernier point et la sélection restent.
    var maxVisibleDots: Int = 24
    /// Repère médian de l'axe (ex. « 10 »), absent de la plupart des sources.
    var middleAxisLabel: String? = nil
    /// Le libellé de fin n'apparaît que si la source le conditionne (`length > 1`).
    var showsLastAxisLabel: Bool = true

    @State private var selectedIndex: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            tooltipBand
            HStack(alignment: .top, spacing: 0) {
                axisColumn
                plot
            }
            if showsDateRange {
                HStack {
                    Text(firstAxisLabel)
                    Spacer(minLength: 8)
                    if showsLastAxisLabel {
                        Text(lastAxisLabel)
                    }
                }
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(Theme.inkFaint)
                .padding(.top, 7)
                .padding(.leading, axisWidth)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibility)
        .onChange(of: points) { _ in selectedIndex = nil }
    }

    private var tooltipBand: some View {
        ZStack {
            if let index = selectedIndex, points.indices.contains(index) {
                VStack(spacing: 1) {
                    Text(points[index].tooltip)
                        .font(.system(size: 11, weight: .black))
                    if let detail = points[index].tooltipDetail {
                        Text(detail)
                            .font(.system(size: 10, weight: .bold))
                            .opacity(0.65)
                    }
                }
                .foregroundStyle(Theme.surface)
                .lineLimit(1)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Theme.ink)
                .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall))
            }
        }
        .frame(maxWidth: .infinity, minHeight: tooltipHeight, alignment: .center)
        .padding(.leading, tooltipLeading ?? axisWidth)
    }

    private var axisColumn: some View {
        VStack {
            Text(topAxisLabel)
            Spacer(minLength: 0)
            if let middleAxisLabel {
                Text(middleAxisLabel)
                Spacer(minLength: 0)
            }
            Text(bottomAxisLabel)
        }
        .font(.system(size: 9, weight: .bold))
        .foregroundStyle(Theme.inkFaint)
        .multilineTextAlignment(.trailing)
        .frame(width: axisWidth, height: height, alignment: .trailing)
    }

    private var plot: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let innerWidth = max(width - dotSize, 1)
            let innerHeight = height - dotSize
            let line = ChartSmoothPath.path(points.enumerated().map { index, point in
                ChartPathPoint(
                    x: Double(xAt(index, innerWidth)),
                    y: Double(yAt(point.value, innerHeight))
                )
            })
            ZStack(alignment: .topLeading) {
                ForEach(0..<3, id: \.self) { step in
                    Rectangle()
                        .fill(Theme.border)
                        .frame(height: 1)
                        .offset(y: dotSize / 2 + innerHeight * CGFloat(step) / 2)
                }
                line.stroke(tint, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                dots(innerWidth: innerWidth, innerHeight: innerHeight)
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .frame(width: width, height: height)
                    .gesture(
                        DragGesture(minimumDistance: 0).onChanged { value in
                            selectedIndex = nearestIndex(x: value.location.x, innerWidth: innerWidth)
                        }
                    )
            }
            .frame(width: width, height: height, alignment: .topLeading)
        }
        .frame(height: height)
    }

    private func dots(innerWidth: CGFloat, innerHeight: CGFloat) -> some View {
        ForEach(Array(points.enumerated()), id: \.element.id) { index, point in
            let isSelected = index == selectedIndex
            if points.count <= maxVisibleDots || index == points.count - 1 || isSelected {
                Circle()
                    .fill(tint)
                    .frame(width: dotSize, height: dotSize)
                    .overlay(Circle().stroke(Theme.surface, lineWidth: isSelected ? 2 : 0))
                    .scaleEffect(isSelected ? 1.5 : 1)
                    .offset(
                        x: xAt(index, innerWidth) - dotSize / 2,
                        y: yAt(point.value, innerHeight) - dotSize / 2
                    )
            }
        }
    }

    private func xAt(_ index: Int, _ innerWidth: CGFloat) -> CGFloat {
        let base = dotSize / 2
        guard points.count > 1 else { return base + innerWidth / 2 }
        return base + innerWidth * CGFloat(index) / CGFloat(points.count - 1)
    }

    private func yAt(_ value: Double, _ innerHeight: CGFloat) -> CGFloat {
        let span = max(upper - lower, 0.000001)
        return dotSize / 2 + innerHeight * CGFloat(1 - (value - lower) / span)
    }

    private func nearestIndex(x: CGFloat, innerWidth: CGFloat) -> Int? {
        guard !points.isEmpty else { return nil }
        guard points.count > 1 else { return 0 }
        let ratio = (Double(x) - Double(dotSize / 2)) / Double(innerWidth)
        let index = Int((ratio * Double(points.count - 1)).rounded())
        return min(max(index, 0), points.count - 1)
    }
}
