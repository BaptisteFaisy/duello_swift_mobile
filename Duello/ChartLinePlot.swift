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
//  `ChartSmoothPath` (ou segments droits pour « Réussites par matière »).
//  L'infobulle reprend la position de la source : largeur fixe, bulle centrée
//  sur le point touché puis bornée aux bords du tracé (`XpChart.tsx:74-83`).
//  Les bornes `lower`/`upper` sont fournies par l'appelant (déjà étendues de la
//  marge propre à chaque graphique). Cible iOS 16.
//
import SwiftUI

/// Point d'une courbe lissée : valeur numérique et textes d'infobulle.
struct ChartLinePoint: Identifiable, Hashable {
    let id = UUID()
    var value: Double
    /// Ligne principale de l'infobulle (la valeur), en 11/`900`.
    var tooltip: String
    /// Première ligne optionnelle (matière ou titre), au-dessus de la valeur.
    var tooltipTitle: String? = nil
    /// Suffixe atténué accolé à la valeur (« · 15 juil. »), en 10/`700`.
    var tooltipAnnotation: String? = nil
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
    /// Le **dernier** point reste marqué même hors sélection (`SubjectSuccessChart`).
    var strongLastDot: Bool = false
    /// Largeur fixe de l'infobulle (`TOOLTIP_WIDTH`) ; `nil` = largeur automatique.
    var tooltipWidth: CGFloat? = nil
    /// Marge haute de l'axe des dates (`7`, `8` sur Elo et Réussites).
    var xAxisTopPadding: CGFloat = 7
    /// Retrait gauche de l'axe des dates ; par défaut celui de l'axe.
    var xAxisLeading: CGFloat? = nil
    /// Décalage du tracé par rapport aux bords (demi-point par défaut).
    var plotInset: CGFloat? = nil
    /// Segments droits au lieu d'une courbe lissée (`SubjectSuccessChart.tsx`).
    var straightSegments: Bool = false
    /// Police de la première ligne d'infobulle (matière/titre).
    var tooltipTitleFont: Font = .system(size: 10, weight: .heavy)
    /// Rembourrage vertical de l'infobulle.
    var tooltipVerticalPadding: CGFloat = 4

    @State private var selectedIndex: Int?

    private var inset: CGFloat { plotInset ?? dotSize / 2 }

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
                .padding(.top, xAxisTopPadding)
                .padding(.leading, xAxisLeading ?? axisWidth)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibility)
        .onChange(of: points) { _ in selectedIndex = nil }
    }

    private var tooltipBand: some View {
        // La largeur du conteneur est mesurée ici : la bulle se place par
        // rapport au tracé, pas par rapport à la bande (`tooltipRow`).
        GeometryReader { geo in
            ZStack(alignment: .bottomLeading) {
                if let index = selectedIndex, points.indices.contains(index) {
                    tooltipView(index)
                        .padding(.leading, tooltipLeft(index, width: geo.size.width))
                        .padding(.bottom, 4)
                }
            }
            .frame(width: geo.size.width, height: tooltipHeight, alignment: .bottomLeading)
        }
        .frame(height: tooltipHeight)
    }

    private func tooltipView(_ index: Int) -> some View {
        let point = points[index]
        return VStack(spacing: 0) {
            if let title = point.tooltipTitle {
                Text(title)
                    .font(tooltipTitleFont)
            }
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text(point.tooltip)
                    .font(.system(size: 11, weight: .black))
                if let annotation = point.tooltipAnnotation {
                    Text(annotation)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.65))
                }
            }
        }
        .foregroundStyle(Theme.surface)
        .lineLimit(1)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 8)
        .padding(.vertical, tooltipVerticalPadding)
        .frame(width: tooltipWidth)
        .background(Theme.ink)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall))
    }

    /// `left` de la source : bulle centrée sur le point puis bornée au tracé.
    private func tooltipLeft(_ index: Int, width: CGFloat) -> CGFloat {
        guard let tooltipWidth else { return tooltipLeading ?? axisWidth }
        let plotWidth = max(width - axisWidth, 1)
        let innerWidth = max(plotWidth - inset * 2, 1)
        let x = points.count < 2
            ? inset + innerWidth / 2
            : inset + innerWidth * CGFloat(index) / CGFloat(points.count - 1)
        let clamped = min(max(x - tooltipWidth / 2, 0), max(plotWidth - tooltipWidth, 0))
        return (tooltipLeading ?? axisWidth) + clamped
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
            let innerWidth = max(width - inset * 2, 1)
            let innerHeight = height - inset * 2
            ZStack(alignment: .topLeading) {
                ForEach(0..<3, id: \.self) { step in
                    Rectangle()
                        .fill(Theme.border)
                        .frame(height: 1)
                        .offset(y: inset + innerHeight * CGFloat(step) / 2)
                }
                linePath(innerWidth: innerWidth, innerHeight: innerHeight)
                    .stroke(tint, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
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

    /// Tracé lissé (source commune) ou segments droits (`SubjectSuccessChart`).
    private func linePath(innerWidth: CGFloat, innerHeight: CGFloat) -> Path {
        let coordinates = points.enumerated().map { index, point in
            ChartPathPoint(
                x: Double(xAt(index, innerWidth)),
                y: Double(yAt(point.value, innerHeight))
            )
        }
        guard straightSegments else { return ChartSmoothPath.path(coordinates) }
        var path = Path()
        guard let first = coordinates.first else { return path }
        path.move(to: CGPoint(x: first.x, y: first.y))
        for coordinate in coordinates.dropFirst() {
            path.addLine(to: CGPoint(x: coordinate.x, y: coordinate.y))
        }
        return path
    }

    private func dots(innerWidth: CGFloat, innerHeight: CGFloat) -> some View {
        ForEach(Array(points.enumerated()), id: \.element.id) { index, point in
            let strong = index == selectedIndex
                || (strongLastDot && index == points.count - 1)
            if points.count <= maxVisibleDots || index == points.count - 1 || index == selectedIndex {
                Circle()
                    .fill(tint)
                    .frame(width: dotSize, height: dotSize)
                    .overlay(Circle().stroke(Theme.surface, lineWidth: strong ? 2 : 0))
                    .scaleEffect(strong ? 1.5 : 1)
                    .offset(
                        x: xAt(index, innerWidth) - dotSize / 2,
                        y: yAt(point.value, innerHeight) - dotSize / 2
                    )
            }
        }
    }

    private func xAt(_ index: Int, _ innerWidth: CGFloat) -> CGFloat {
        guard points.count > 1 else { return inset + innerWidth / 2 }
        return inset + innerWidth * CGFloat(index) / CGFloat(points.count - 1)
    }

    private func yAt(_ value: Double, _ innerHeight: CGFloat) -> CGFloat {
        let span = max(upper - lower, 0.000001)
        return inset + innerHeight * CGFloat(1 - (value - lower) / span)
    }

    private func nearestIndex(x: CGFloat, innerWidth: CGFloat) -> Int? {
        guard !points.isEmpty else { return nil }
        guard points.count > 1 else { return 0 }
        let ratio = (Double(x) - Double(inset)) / Double(innerWidth)
        let index = Int((ratio * Double(points.count - 1)).rounded())
        return min(max(index, 0), points.count - 1)
    }
}
