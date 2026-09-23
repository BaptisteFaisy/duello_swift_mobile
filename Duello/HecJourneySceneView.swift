import SwiftUI

/// Mesures de la frise, converties depuis les unités du monde 3D.
///
/// Les constantes viennent de `src/components/HecJourneyScene.tsx` :
/// `HEC_JOURNEY_NODE_SIZE` (1,62), `HEC_JOURNEY_NODE_HEIGHT` (0,25),
/// `HEC_JOURNEY_TRACK_VERTICAL_OFFSET` (−0,26),
/// `HEC_JOURNEY_ASSESSMENT_BRANCH_LENGTH` (0,87),
/// `HEC_JOURNEY_ASSESSMENT_BLOCK_WIDTH` (0,82) et la taille du blason
/// (`admissionCrestImage` : 152 points).
enum HecJourneyMetrics {
    /// Points par unité du monde : resserre le parcours à l'échelle de l'écran.
    static let worldScale: CGFloat = 26
    static let nodeWidth: CGFloat = 1.62 * worldScale
    /// Épaisseur du pavé : 0,25 unité dans la source, relevée à 0,45 pour
    /// rester lisible sans éclairage ni ombres.
    static let nodeThickness: CGFloat = 0.45 * worldScale
    static let trackRadius: CGFloat = 0.13 * worldScale
    static let trackOffset: CGFloat = -0.26 * worldScale
    static let assessmentBranchLength: CGFloat = 0.87 * worldScale
    static let assessmentWidth: CGFloat = 0.82 * worldScale
    /// Hauteur du bloc de premier plan dans le cadre (sous le centre, comme la
    /// caméra qui regarde la piste de haut).
    static let focusRatio: CGFloat = 0.68
    /// Opacité plancher des blocs lointains.
    static let minimumOpacity: Double = 0.18
    static let captionOffset: CGFloat = 30
    static let captionWidth: CGFloat = 150
    /// `journeyNativeCrestLabelPoint` : le blason flotte 0,72 au-dessus du bloc.
    static let crestLift: CGFloat = 0.72 * worldScale
    static let crestHeight: CGFloat = 144
}

/// Frise du parcours HEC : la scène 3D d'Expo projetée en deux dimensions.
///
/// Porté de `src/components/HecJourneyScene.tsx` — `JourneyTrack`,
/// `JourneyNode`, `JourneyAssessmentMarker`, `JourneyAdmissionMarker`,
/// `CurrentBlockEmphasis`, `JourneySceneErrorBoundary` — avec les gestes de
/// `src/utils/hecJourney.ts` et la géométrie de `src/utils/hecJourney3d.ts`.
///
/// Différences assumées, toutes imposées par l'absence de moteur 3D embarqué
/// (la source dessine un Canvas `three` : tuyau courbe, blocs posés dessus,
/// caméra qui suit la piste, brume linéaire) :
/// - la profondeur devient la position verticale, `x` écarte le bloc du centre
///   et la brume devient l'opacité (`HecJourneyProjection`) ;
/// - le `JourneySceneErrorBoundary` n'a plus d'objet : il n'y a pas de contexte
///   OpenGL à perdre ;
/// - le geste horizontal n'est plus relayé au pager d'onglets (`onTabSwipe*`
///   n'est pas porté) : la reconnaissance simultanée laisse l'axe horizontal au
///   `TabView` parent ;
/// - le titre et la date sous chaque bloc sont un ajout de lisibilité.
struct HecJourneySceneView: View {
    let blocks: [HecJourneySceneBlock]
    let positions: [Double]
    let activeIndex: Int
    let currentBlockIndex: Int
    /// Décalage courant, en points (`scrollY` de la source).
    @Binding var scrollOffset: CGFloat
    let onSelectNode: (Int) -> Void
    let onActiveIndexChange: (Int) -> Void

    @State private var dragStartOffset: CGFloat = 0
    @State private var dragAxis: HecJourneyGesture.Axis?

    var body: some View {
        GeometryReader { geometry in
            let projection = HecJourneyProjection(
                blocks: blocks,
                positions: positions,
                scrollOffset: scrollOffset
            )
            // Pré-calcul unique par évaluation : la liste des crans visibles et
            // leurs points projetés, réutilisés par la piste et par les blocs
            // (au lieu d'être recalculés dans la boucle de `body`).
            let visibleIndices = projection.visibleIndices(size: geometry.size)
            let points = visibleIndices.map { projection.point(at: $0, size: geometry.size) }
            ZStack(alignment: .topLeading) {
                trackLayer(points: points)
                ForEach(visibleIndices.indices, id: \.self) { offset in
                    blockLayer(
                        index: visibleIndices[offset],
                        point: points[offset],
                        projection: projection
                    )
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
            .contentShape(Rectangle())
            .simultaneousGesture(dragGesture)
        }
        .background(Theme.background)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(HecJourneyCopy.a11yScene)
    }

    // MARK: Piste

    /// La piste : dans la source, un tuyau de rayon 0,13 unité, presque
    /// transparent (opacité 0,035) sur fond blanc ; ici un trait de 7 points,
    /// assez marqué pour être vu sans relief.
    private func trackLayer(points: [CGPoint]) -> some View {
        Path { path in
            for (order, point) in points.enumerated() {
                let shifted = CGPoint(x: point.x, y: point.y + HecJourneyMetrics.trackOffset)
                if order == 0 {
                    path.move(to: shifted)
                } else {
                    path.addLine(to: shifted)
                }
            }
        }
        .stroke(
            HecJourneyPalette.track.opacity(0.55),
            style: StrokeStyle(lineWidth: 7, lineCap: .round, lineJoin: .round)
        )
    }

    // MARK: Blocs

    @ViewBuilder
    private func blockLayer(index: Int, point: CGPoint, projection: HecJourneyProjection) -> some View {
        let block = blocks[index]
        Group {
            if block.type.isAssessment {
                HecJourneyAssessmentMarkerView(block: block, highlighted: index == activeIndex)
                    .offset(x: sideOffset(index: index), y: HecJourneyMetrics.trackOffset)
                    .position(point)
            } else if block.type == .admission {
                HecJourneyCrestView(
                    crest: projection.crest(at: index),
                    height: HecJourneyMetrics.crestHeight
                )
                .opacity(projection.crestOpacity(at: index))
                .position(x: point.x, y: point.y - HecJourneyMetrics.crestLift)
            } else {
                HecJourneyNodeView(
                    block: block,
                    highlighted: index == activeIndex,
                    current: index == currentBlockIndex
                )
                .position(point)
            }
        }
        .opacity(block.type == .admission ? 1 : projection.opacity(at: index))
        .onTapGesture { onSelectNode(index) }
        .accessibilityLabel(HecJourneyCopy.a11yOpenBlock(block.title))
    }

    /// Écart latéral d'un repère : une colle part à gauche, les autres à
    /// droite, au bout de la tige (`HEC_JOURNEY_TRACK_RADIUS` +
    /// `HEC_JOURNEY_ASSESSMENT_BRANCH_LENGTH` + demi-pavé).
    private func sideOffset(index: Int) -> CGFloat {
        let direction: CGFloat = blocks[index].type == .block(.colle) ? -1 : 1
        let distance = HecJourneyMetrics.trackRadius
            + (HecJourneyMetrics.assessmentBranchLength + HecJourneyMetrics.assessmentWidth) / 2
        return direction * distance
    }

    // MARK: Geste

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: HecJourneyGesture.dragActivationDistance)
            .onChanged { value in
                if dragAxis == nil {
                    dragStartOffset = scrollOffset
                    dragAxis = HecJourneyGesture.axis(
                        dx: value.translation.width,
                        dy: value.translation.height
                    )
                }
                guard dragAxis == .vertical else { return }
                scrollOffset = HecJourneyGesture.offsetFromPull(
                    startOffset: dragStartOffset,
                    translationY: value.translation.height,
                    count: blocks.count
                )
                let index = HecJourneyGesture.activeIndex(offset: scrollOffset, count: blocks.count)
                if index >= 0, index != activeIndex {
                    onActiveIndexChange(index)
                }
            }
            .onEnded { value in
                let axis = dragAxis
                    ?? HecJourneyGesture.axis(dx: value.translation.width, dy: value.translation.height)
                dragAxis = nil
                guard axis == .vertical else { return }
                let projected = HecJourneyGesture.offsetFromPull(
                    startOffset: scrollOffset + HecJourneyGesture.momentum(from: value),
                    translationY: 0,
                    count: blocks.count
                )
                snap(to: HecJourneyGesture.activeIndex(offset: projected, count: blocks.count))
            }
    }

    /// `onPanResponderRelease` : la frise se cale sur le cran le plus proche,
    /// avec le ressort de la source (amortissement 25, raideur 145, masse 0,76
    /// — transposés en `spring(response:dampingFraction:)`).
    private func snap(to index: Int) {
        guard index >= 0 else { return }
        if index != activeIndex {
            onActiveIndexChange(index)
        }
        withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
            scrollOffset = CGFloat(index) * HecJourneyGesture.nodeGap
        }
    }
}
