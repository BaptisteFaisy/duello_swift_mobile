import SwiftUI

/// Projection de la piste 3D du parcours sur l'écran, en deux dimensions.
///
/// `src/utils/hecJourney3d.ts` décrit la piste dans un monde à trois axes ;
/// faute de moteur 3D embarqué, `HecJourneySceneView` la regarde **de côté** :
/// - la profondeur `z` devient la position verticale, à raison de
///   `HEC_JOURNEY_NODE_GAP` points par cran (`src/utils/hecJourney.ts`) ;
/// - `x` écarte le bloc du centre de la piste ;
/// - la distance à la caméra donne l'opacité, par la loi de brume
///   (`hecJourneyFogVisibility`) ;
/// - le blason de la dernière étape reste au-dessus de son bloc
///   (`journeyNativeCrestLabelPoint`).
struct HecJourneyProjection {
    let blocks: [HecJourneySceneBlock]
    let positions: [Double]
    /// `scrollY` de la source, en points.
    let scrollOffset: CGFloat

    /// Progression du monde sous le doigt, interpolée entre deux crans
    /// (`hecJourneyPositionAtIndex`).
    var activeProgress: Double {
        HecJourneyLayout.position(
            atIndex: Double(scrollOffset / HecJourneyGesture.nodeGap),
            positions: positions
        )
    }

    /// Position d'un bloc à l'écran : `0,68 × hauteur` quand le bloc est au
    /// premier plan, remontant quand on avance dans le parcours.
    func point(at index: Int, size: CGSize) -> CGPoint {
        let world = HecJourneyGeometry.worldPoint(progress(at: index))
        return CGPoint(
            x: size.width / 2 + CGFloat(world.x) * HecJourneyMetrics.worldScale,
            y: size.height * HecJourneyMetrics.focusRatio
                - (CGFloat(index) * HecJourneyGesture.nodeGap - scrollOffset)
        )
    }

    /// Opacité d'un bloc : la brume de la scène 3D, relevée à 0,18 pour que le
    /// lointain reste devinable en 2D (la source le noie complètement dans le
    /// blanc).
    func opacity(at index: Int) -> Double {
        let visibility = HecJourneyGeometry.visibility(
            progress: progress(at: index),
            activeProgress: activeProgress
        )
        return HecJourneyMetrics.minimumOpacity
            + (1 - HecJourneyMetrics.minimumOpacity) * visibility
    }

    /// Opacité du blason, par la même loi que les blocs
    /// (`hecJourneyFogVisibility` appliquée à la distance caméra).
    func crestOpacity(at index: Int) -> Double {
        HecJourneyGeometry.fogVisibility(
            distance: HecJourneyGeometry.cameraDistance(
                to: progress(at: index),
                activeProgress: activeProgress
            )
        )
    }

    /// Crans à dessiner : ceux qu'un écran peut contenir, de part et d'autre du
    /// bloc courant. La source, elle, confie la découpe à la carte graphique.
    func visibleIndices(size: CGSize) -> [Int] {
        guard !blocks.isEmpty else { return [] }
        let anchor = HecJourneyGesture.activeIndex(offset: scrollOffset, count: blocks.count)
        let span = Int(ceil(size.height / HecJourneyGesture.nodeGap)) + 2
        let lower = max(0, anchor - span)
        let upper = min(blocks.count - 1, anchor + span)
        guard lower <= upper else { return [] }
        return Array(lower...upper)
    }

    /// Blason du bloc d'admission, reconstruit depuis les champs de la source
    /// (`crestLabel`, `crestColor`, `crestSchoolId`).
    func crest(at index: Int) -> HecJourneyAdmissionCrest {
        let block = blocks[index]
        return HecJourneyAdmissionCrest(
            schoolId: block.crestSchoolId ?? HecJourneyAdmissionCrest.default.schoolId,
            schoolName: block.title,
            crestLabel: block.crestLabel ?? block.title,
            colorHex: block.crestColorHex ?? HecJourneyAdmissionCrest.default.colorHex
        )
    }

    private func progress(at index: Int) -> Double {
        positions.indices.contains(index) ? positions[index] : 0
    }
}
