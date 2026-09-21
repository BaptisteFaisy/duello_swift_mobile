import SwiftUI

/// Un bloc de la frise : le cube plat de `JourneyNode`
/// (`src/components/HecJourneyScene.tsx`), vu de côté.
///
/// La source dessine un pavé `1,62 × 0,25 × 1,62` en unités monde, rempli de
/// `HEC_JOURNEY_NAVY` quand le cours est vu, sinon de blanc translucide
/// (opacité 0,34 pour le bloc actif, 0,24 sinon), et éclairé par la scène. En
/// 2D, la lumière disparaît : un bord fin remplace les ombres, et l'épaisseur
/// du pavé est portée de 0,25 à 0,45 unité pour rester lisible à l'écran.
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
                RoundedRectangle(cornerRadius: 12)
                    .stroke(HecJourneyPalette.navy.opacity(0.28), lineWidth: 2)
                    .frame(
                        width: HecJourneyMetrics.nodeWidth + 16,
                        height: HecJourneyMetrics.nodeThickness + 16
                    )
            }
            slab
            caption.offset(y: HecJourneyMetrics.captionOffset)
        }
    }

    private var slab: some View {
        RoundedRectangle(cornerRadius: 5)
            .fill(isCompleted ? HecJourneyPalette.navy.opacity(0.34) : Color.white.opacity(highlighted ? 0.34 : 0.24))
            .frame(
                width: HecJourneyMetrics.nodeWidth * (highlighted ? 1.14 : 1),
                height: HecJourneyMetrics.nodeThickness * (highlighted ? 1.14 : 1)
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

/// Un repère latéral : colle, DS ou interrogation.
///
/// `JourneyAssessmentMarker` attache le repère au tuyau par une tige
/// (`HEC_JOURNEY_ASSESSMENT_BRANCH_LENGTH`) et pose un pavé plus petit à son
/// bout, à gauche pour une colle, à droite sinon. Le remplissage suit le statut
/// de cours : `HEC_JOURNEY_NAVY` à 0,48 si le cours est vu, sinon blanc à 0,72
/// quand le repère est actif, 0,56 sinon.
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
            .frame(width: HecJourneyMetrics.assessmentBranchLength, height: 2)
    }

    private var marker: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(isCompleted ? HecJourneyPalette.navy.opacity(0.48) : Color.white.opacity(highlighted ? 0.72 : 0.56))
            .frame(
                width: HecJourneyMetrics.assessmentWidth * (highlighted ? 1.14 : 1),
                height: HecJourneyMetrics.assessmentWidth * (highlighted ? 1.14 : 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(isCompleted ? HecJourneyPalette.navy.opacity(0.6) : Theme.border, lineWidth: 1)
            )
            .overlay(
                Text(HecJourneyBlocks.label(block.type.blockType ?? .ds))
                    .font(.system(size: 8, weight: .black))
                    .foregroundStyle(Theme.inkSoft)
            )
    }

    private var isCompleted: Bool { block.courseStatus == .completed }
}
