//
//  TrendCurve.swift
//  Duello
//
//  Courbe unique façon Trade Republic (parité RN dev, vague I7).
//
//  Fichier source Expo porté (noms et valeurs repris mot pour mot) :
//    - src/components/TrendCurve.tsx (`TrendCurve`, `TrendCurvePoint`)
//
//  Aucun quadrillage ni axe : le tracé touche le bord gauche (jamais le droit)
//  et le doigt le parcourt avec un cran tactile par point. Le défilement
//  vertical reste au parent : dès qu'il reprend le toucher, la lecture s'efface.
//  Réutilise `ChartSmoothPath` (`buildSmoothChartPath`). Cible iOS 16.
//
import SwiftUI

/// `TrendCurvePoint` de `src/components/TrendCurve.tsx`.
struct TrendCurvePoint: Hashable {
    var at: Double
    var value: Double
}

/// Clé de préférence : largeur mesurée du conteneur de la courbe.
private struct TrendCurveWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

/// `TrendCurve` de `src/components/TrendCurve.tsx` : une courbe sans axe ni
/// quadrillage, lue au doigt avec un cran tactile par point.
struct TrendCurve: View {
    /// Points de la courbe, de la première à la dernière période.
    let points: [TrendCurvePoint]
    /// Valeur mise en avant dans la bulle (« 12 Elo », « 14,5/20 »…).
    let formatValue: (Double) -> String
    /// Date de la période (« juil. 2026 »…).
    let formatDate: (Double) -> String
    /// Libellé VoiceOver de la courbe entière.
    let accessibilityLabel: String

    /// `PLOT_HEIGHT`.
    private static let plotHeight: CGFloat = 132
    /// `LINE_THICKNESS`.
    private static let lineThickness: CGFloat = 2.5
    /// `EDGE_INSET`.
    private static let edgeInset: CGFloat = 2
    /// `SCRUB_LINE_WIDTH`.
    private static let scrubLineWidth: CGFloat = 1.5
    /// `SCRUB_DOT_RADIUS`.
    private static let scrubDotRadius: CGFloat = 5
    /// `TOOLTIP_WIDTH`.
    private static let tooltipWidth: CGFloat = 124
    /// `PAGE_MARGIN` : la courbe la compense à gauche pour toucher le bord.
    private static let pageMargin: CGFloat = 24
    /// `TAP_SLOP` : en deçà, le toucher reste un appui, la bulle persiste.
    private static let tapSlop: CGFloat = 10

    @State private var contentWidth: CGFloat = 0
    @State private var selectedIndex: Int?

    /// `bleed` : marge de page compensée à gauche (nulle sur le web).
    private var bleed: CGFloat { Self.pageMargin }

    private var plotWidth: CGFloat { max(contentWidth + bleed, 1) }
    private var innerWidth: CGFloat { max(plotWidth - Self.edgeInset * 2, 1) }
    private var innerHeight: CGFloat { Self.plotHeight - Self.edgeInset * 2 }

    private var lowest: Double { points.map(\.value).min() ?? 0 }
    private var highest: Double { points.map(\.value).max() ?? 0 }

    /// Marge verticale : 15 % de l'amplitude, ou 10 % de la valeur haute.
    private var padding: Double {
        let span = highest - lowest
        return span > 0 ? span * 0.15 : max(abs(highest) * 0.1, 1)
    }

    private var minValue: Double { lowest >= 0 ? max(0, lowest - padding) : lowest - padding }
    private var maxValue: Double { highest + padding }

    private func xAt(_ index: Int) -> CGFloat {
        let inner = points.count < 2
            ? innerWidth / 2
            : (innerWidth * CGFloat(index)) / CGFloat(points.count - 1)
        return Self.edgeInset + inner
    }

    private func yAt(_ value: Double) -> CGFloat {
        let ratio = CGFloat((value - minValue) / max(maxValue - minValue, 1))
        return Self.edgeInset + innerHeight * (1 - ratio)
    }

    private var linePath: Path {
        ChartSmoothPath.path(
            points.enumerated().map { index, point in
                ChartPathPoint(x: Double(xAt(index)), y: Double(yAt(point.value)))
            }
        )
    }

    var body: some View {
        if points.isEmpty {
            EmptyView()
        } else {
            content
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            tooltipRow
            plot
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            GeometryReader { geometry in
                Color.clear.preference(key: TrendCurveWidthKey.self, value: geometry.size.width)
            }
        )
        .onPreferenceChange(TrendCurveWidthKey.self) { width in
            contentWidth = width
        }
    }

    /// Bande réservée en permanence (`tooltipRow`) : la lecture d'un point ne
    /// décale pas la courbe.
    private var tooltipRow: some View {
        ZStack(alignment: .bottomLeading) {
            Color.clear
            if let index = selectedIndex, points.indices.contains(index), contentWidth > 0 {
                tooltip(index)
                    .padding(.leading, bubbleLeft(index))
                    .padding(.bottom, 2)
            }
        }
        .frame(height: 26)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Bulle de lecture (`styles.tooltip`) : valeur puis date atténuée.
    private func tooltip(_ index: Int) -> some View {
        tooltipText(index)
            .lineLimit(1)
            .padding(.vertical, 4)
            .frame(width: Self.tooltipWidth)
            .background(Theme.ink)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall))
    }

    private func tooltipText(_ index: Int) -> Text {
        Text(formatValue(points[index].value))
            .font(.system(size: 11, weight: .black))
            .foregroundColor(Theme.white)
        + Text(" · \(formatDate(points[index].at))")
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(Color.white.opacity(0.65))
    }

    /// Position gauche de la bulle, bornée aux bords du conteneur.
    private func bubbleLeft(_ index: Int) -> CGFloat {
        let desired = xAt(index) + bleed - Self.tooltipWidth / 2
        return min(max(desired, 0), max(contentWidth - Self.tooltipWidth, 0))
    }

    /// Zone de tracé : le toucher y sélectionne le point le plus proche.
    private var plot: some View {
        canvas
            .frame(width: plotWidth, height: Self.plotHeight, alignment: .topLeading)
            .contentShape(Rectangle())
            .gesture(scrubGesture)
            .padding(.leading, -bleed)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityLabel)
            .accessibilityAdjustableAction { direction in
                step(direction)
            }
    }

    /// Tracé, repère de lecture et point marqué (`Svg` de la source).
    private var canvas: some View {
        ZStack(alignment: .topLeading) {
            if contentWidth > 0 {
                linePath
                    .stroke(
                        Theme.ink,
                        style: StrokeStyle(
                            lineWidth: Self.lineThickness,
                            lineCap: .round,
                            lineJoin: .round
                        )
                    )
                if let index = selectedIndex, points.indices.contains(index) {
                    scrubLine(index)
                    dot(index, strong: true)
                } else if points.count == 1 {
                    dot(0, strong: false)
                }
            }
        }
        .frame(width: plotWidth, height: Self.plotHeight, alignment: .topLeading)
    }

    /// Repère vertical du point lu (`Line`, opacité 0,35).
    private func scrubLine(_ index: Int) -> some View {
        Path { path in
            path.move(to: CGPoint(x: xAt(index), y: Self.edgeInset))
            path.addLine(to: CGPoint(x: xAt(index), y: Self.plotHeight - Self.edgeInset))
        }
        .stroke(Theme.ink, lineWidth: Self.scrubLineWidth)
        .opacity(0.35)
    }

    /// Point marqué (`Circle`) : anneau blanc sur le point lu, plein sur un
    /// point unique.
    private func dot(_ index: Int, strong: Bool) -> some View {
        let radius = strong ? Self.scrubDotRadius : Self.scrubDotRadius - 1
        return Circle()
            .fill(Theme.ink)
            .frame(width: radius * 2, height: radius * 2)
            .overlay(
                strong
                    ? AnyView(Circle().stroke(Theme.white, lineWidth: Self.lineThickness))
                    : AnyView(EmptyView())
            )
            .position(x: xAt(index), y: yAt(points[index].value))
    }

    /// Lecture au doigt : un cran par point frôlé ; un glissement efface.
    private var scrubGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                selectNearest(value.location.x)
            }
            .onEnded { value in
                let travelled = hypot(value.translation.width, value.translation.height)
                if travelled < Self.tapSlop { return }
                selectedIndex = nil
            }
    }

    /// Sélectionne le point le plus proche de `x` (`selectNearest`), un cran
    /// tactile par point frôlé.
    private func selectNearest(_ x: CGFloat) {
        guard !points.isEmpty else { return }
        let clamped = min(max(x, 0), plotWidth)
        var best = 0
        var bestDistance = CGFloat.infinity
        for index in points.indices {
            let distance = abs(xAt(index) - clamped)
            if distance < bestDistance {
                bestDistance = distance
                best = index
            }
        }
        if best != selectedIndex {
            selectedIndex = best
            #if os(iOS)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            #endif
        }
    }

    /// Pas de lecture clavier/VoiceOver (`stepSelection`).
    private func step(_ direction: AccessibilityAdjustmentDirection) {
        guard !points.isEmpty else { return }
        let delta = direction == .increment ? 1 : -1
        let current = selectedIndex ?? (direction == .increment ? -1 : points.count)
        selectedIndex = min(max(current + delta, 0), points.count - 1)
    }
}
