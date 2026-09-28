import SwiftUI

/// Un bloc de la frise : le cube plat de `JourneyNode`
/// (`src/components/HecJourneyScene.tsx`), vu de côté.
///
/// La source dessine un pavé `1,62 × 0,25 × 1,62` en unités monde, rempli de
/// `HEC_JOURNEY_NAVY` quand le cours est vu (opacité 0,34), sinon de blanc
/// translucide (0,34 pour le bloc actif, 0,24 sinon). Le pavé ne grossit
/// **jamais** quand il est actif (le `× 1,14` n'existe que sur les repères
/// latéraux). En 2D, la lumière disparaît : un bord fin remplace les ombres.
///
/// Le titre et la date sous le bloc sont un ajout de lisibilité : la scène 3D
/// n'écrit rien sur la piste, elle ne montre que le blason final.
struct HecJourneyNodeView: View {
    let block: HecJourneySceneBlock
    /// Bloc sélectionné par le défilement (`activeIndex`).
    let highlighted: Bool
    /// Bloc courant du parcours (`currentBlockIndex`) : il porte le halo.
    let current: Bool

    private var isCompleted: Bool { block.courseStatus == .completed }

    var body: some View {
        ZStack {
            if current {
                HecJourneyHaloView()
            }
            slab
            caption.offset(y: HecJourneyMetrics.captionOffset)
        }
    }

    private var slab: some View {
        RoundedRectangle(cornerRadius: 5)
            .fill(isCompleted ? HecJourneyPalette.navy.opacity(0.34) : Color.white.opacity(highlighted ? 0.34 : 0.24))
            .frame(
                width: HecJourneyMetrics.nodeWidth,
                height: HecJourneyMetrics.nodeThickness
            )
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(
                        isCompleted ? HecJourneyPalette.navy.opacity(0.55) : Theme.border,
                        lineWidth: highlighted ? 1.6 : 1
                    )
            )
    }

    private var caption: some View {
        VStack(spacing: 1) {
            Text(block.title)
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(block.type.label.uppercased())
                .font(.system(size: 8, weight: .black))
                .tracking(1)
                .foregroundStyle(Theme.inkFaint)
        }
        .frame(width: HecJourneyMetrics.captionWidth)
    }
}

/// Halo pulsant du bloc courant (`CurrentBlockEmphasis`).
///
/// La source anime un plan `2,72 × 2,72` posé sous le bloc, dont l'opacité suit
/// `0,1 + sin(t × 1,8) × 0,035` et l'échelle `1 + wave × 0,035`
/// (`HecJourneyScene.tsx:353-358`). En 2D, le plan devient une ellipse de brume
/// bleu nuit autour du bloc.
struct HecJourneyHaloView: View {
    /// Diamètre du halo (le plan fait `2,72` pour un pavé de `1,62`).
    private var diameter: CGFloat { HecJourneyMetrics.nodeWidth * 2.72 / 1.62 }

    var body: some View {
        TimelineView(.animation) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            let wave = (sin(time * 1.8) + 1) / 2
            let scale = 1 + wave * 0.035
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [
                            HecJourneyPalette.navy.opacity(0.55),
                            HecJourneyPalette.navy.opacity(0),
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: diameter / 2
                    )
                )
                .frame(width: diameter * scale, height: diameter * 0.30 * scale)
                .opacity(0.1 + wave * 0.035)
        }
    }
}

/// Un repère latéral : colle, DS ou interrogation.
///
/// `JourneyAssessmentMarker` attache le repère au tuyau par une tige
/// (`HEC_JOURNEY_ASSESSMENT_BRANCH_LENGTH` : `0,87 × 0,024`) et pose un pavé
/// `0,82 × 0,18` à son bout, à gauche pour une colle, à droite sinon. Le
/// remplissage suit le statut de cours : `HEC_JOURNEY_NAVY` à 0,48 si le cours
/// est vu, sinon blanc à 0,72 quand le repère est actif, 0,56 sinon. Le repère
/// actif grossit de `× 1,14`.
struct HecJourneyAssessmentMarkerView: View {
    let block: HecJourneySceneBlock
    let highlighted: Bool

    private var direction: CGFloat {
        block.type == .block(.colle) ? -1 : 1
    }

    var body: some View {
        HStack(spacing: 0) {
            if direction < 0 { branch }
            marker
            if direction > 0 { branch }
        }
    }

    private var branch: some View {
        Rectangle()
            .fill(Color.white.opacity(0.9))
            .frame(width: HecJourneyMetrics.assessmentBranchLength, height: HecJourneyMetrics.assessmentBranchThickness)
    }

    private var marker: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(isCompleted ? HecJourneyPalette.navy.opacity(0.48) : Color.white.opacity(highlighted ? 0.72 : 0.56))
            .frame(
                width: HecJourneyMetrics.assessmentWidth * (highlighted ? 1.14 : 1),
                height: HecJourneyMetrics.assessmentHeight * (highlighted ? 1.14 : 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(isCompleted ? HecJourneyPalette.navy.opacity(0.6) : Theme.border, lineWidth: 1)
            )
    }

    private var isCompleted: Bool { block.courseStatus == .completed }
}
