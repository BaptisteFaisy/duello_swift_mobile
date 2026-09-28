import SwiftUI

/// Mesures de la frise, converties depuis les unités du monde 3D.
///
/// Les constantes viennent de `src/components/HecJourneyScene.tsx` :
/// `HEC_JOURNEY_NODE_SIZE` (1,62), `HEC_JOURNEY_NODE_HEIGHT` (0,25),
/// `HEC_JOURNEY_TRACK_VERTICAL_OFFSET` (−0,26), `HEC_JOURNEY_TRACK_RADIUS`
/// (0,13), `HEC_JOURNEY_ASSESSMENT_BRANCH_LENGTH` (0,87),
/// `HEC_JOURNEY_ASSESSMENT_BLOCK_WIDTH` (0,82),
/// `HEC_JOURNEY_ASSESSMENT_BLOCK_HEIGHT` (0,18) et la taille du blason
/// (`admissionCrestImage` : 152 points).
enum HecJourneyMetrics {
    /// Points par unité du monde : resserre le parcours à l'échelle de l'écran.
    static let worldScale: CGFloat = 26
    static let nodeWidth: CGFloat = 1.62 * worldScale
    /// Épaisseur du pavé : `HEC_JOURNEY_NODE_HEIGHT` (0,25), sans relief
    /// ajouté — la source reste à 0,25 même sans éclairage.
    static let nodeThickness: CGFloat = 0.25 * worldScale
    static let trackRadius: CGFloat = 0.13 * worldScale
    static let trackOffset: CGFloat = -0.26 * worldScale
    static let assessmentBranchLength: CGFloat = 0.87 * worldScale
    /// Tige du repère : section `0,024` unité.
    static let assessmentBranchThickness: CGFloat = 0.024 * worldScale
    /// Pavé du repère : `0,82 × 0,18`.
    static let assessmentWidth: CGFloat = 0.82 * worldScale
    static let assessmentHeight: CGFloat = 0.18 * worldScale
    /// Hauteur du bloc de premier plan dans le cadre (sous le centre, comme la
    /// caméra qui regarde la piste de haut).
    static let focusRatio: CGFloat = 0.68
    /// Opacité plancher des blocs lointains : nulle — la brume les noie.
    static let minimumOpacity: Double = 0
    static let captionOffset: CGFloat = 30
    static let captionWidth: CGFloat = 150
    /// `journeyNativeCrestLabelPoint` : le blason flotte 0,72 au-dessus du bloc.
    static let crestLift: CGFloat = 0.72 * worldScale
    static let crestHeight: CGFloat = 144
    /// Socle du blason (`JourneyAdmissionMarker`) : cylindre `0,96` de rayon,
    /// `0,2` de haut, posé `0,13` sous le bloc.
    static let crestSocleWidth: CGFloat = 0.96 * 2 * worldScale
    static let crestSocleHeight: CGFloat = 0.2 * worldScale
    /// `AdmissionCrestSprite` : `2,34` au repos, `2,5` quand le blason est actif.
    static let crestActiveScale: CGFloat = 2.5 / 2.34
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
    /// Dernier échantillon du geste, pour estimer la vitesse (pt/ms) sans
    /// `DragGesture.Value.velocity` (iOS 17+).
    @State private var lastSample: (translation: CGFloat, time: Date)?
    @State private var velocity: CGFloat = 0

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
    /// transparent (opacité 0,035) sur fond blanc ; ici un trait de 7 points
    /// (= diamètre 0,26), lissé comme la courbe Catmull-Rom de la source, et
    /// assez marqué pour être vu sans relief.
    private func trackLayer(points: [CGPoint]) -> some View {
        let shifted = points.map { CGPoint(x: $0.x, y: $0.y + HecJourneyMetrics.trackOffset) }
        return HecJourneySceneView.smoothedPath(shifted)
            .stroke(
                HecJourneyPalette.track.opacity(0.55),
                style: StrokeStyle(lineWidth: 7, lineCap: .round, lineJoin: .round)
            )
    }

    /// Catmull-Rom → Bézier (tension 0,42 comme `CatmullRomCurve3`), pour que la
    /// piste ne montre pas les angles d'une polyligne.
    private static func smoothedPath(_ points: [CGPoint]) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        guard points.count > 1 else { return path }
        let k: CGFloat = 0.14
        for index in 0..<(points.count - 1) {
            let p0 = points[max(0, index - 1)]
            let p1 = points[index]
            let p2 = points[index + 1]
            let p3 = points[min(points.count - 1, index + 2)]
            let c1 = CGPoint(x: p1.x + (p2.x - p0.x) * k, y: p1.y + (p2.y - p0.y) * k)
            let c2 = CGPoint(x: p2.x - (p3.x - p1.x) * k, y: p2.y - (p3.y - p1.y) * k)
            path.addCurve(to: p2, control1: c1, control2: c2)
        }
        return path
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
                admissionLayer(index: index, point: point, projection: projection)
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

    /// Blason final : le socle blanc sous le sprite, l'échelle qui suit la
    /// distance (`crestScale`) et le grossissement `× 2,5/2,34` quand il est
    /// actif (`AdmissionCrestSprite`).
    private func admissionLayer(
        index: Int,
        point: CGPoint,
        projection: HecJourneyProjection
    ) -> some View {
        let scale = projection.crestScale(at: index)
            * (index == activeIndex ? HecJourneyMetrics.crestActiveScale : 1)
        return ZStack {
            Ellipse()
                .fill(Color.white)
                .frame(
                    width: HecJourneyMetrics.crestSocleWidth * scale,
                    height: HecJourneyMetrics.crestSocleHeight * scale
                )
                .offset(y: HecJourneyMetrics.crestHeight * scale / 2)
            HecJourneyCrestView(
                crest: projection.crest(at: index),
                height: HecJourneyMetrics.crestHeight
            )
            .scaleEffect(scale)
        }
        .opacity(projection.crestOpacity(at: index))
        .position(x: point.x, y: point.y - HecJourneyMetrics.crestLift)
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
                    lastSample = nil
                    velocity = 0
                }
                sampleVelocity(value.translation.height)
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
                lastSample = nil
                guard axis == .vertical else { return }
                let projected = HecJourneyGesture.offsetFromPull(
                    startOffset: scrollOffset + HecJourneyGesture.momentum(velocity: velocity),
                    translationY: 0,
                    count: blocks.count
                )
                snap(to: HecJourneyGesture.activeIndex(offset: projected, count: blocks.count))
            }
    }

    /// Estime la vitesse du doigt en points par milliseconde, comme le `vy` du
    /// `PanResponder` de la source, à partir de deux échantillons successifs.
    private func sampleVelocity(_ translation: CGFloat) {
        let now = Date()
        if let last = lastSample {
            let elapsed = now.timeIntervalSince(last.time) * 1000
            if elapsed > 0 {
                velocity = (translation - last.translation) / elapsed
            }
        }
        lastSample = (translation, now)
    }

    /// `onPanResponderRelease` : la frise se cale sur le cran le plus proche,
    /// avec le ressort de la source (`damping 25, stiffness 145, mass 0,76`).
    private func snap(to index: Int) {
        guard index >= 0 else { return }
        if index != activeIndex {
            onActiveIndexChange(index)
        }
        withAnimation(.interpolatingSpring(mass: 0.76, stiffness: 145, damping: 25)) {
            scrollOffset = CGFloat(index) * HecJourneyGesture.nodeGap
        }
    }
}
