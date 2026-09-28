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
    /// (`hecJourneyPositionAtIndex`) : `scrollY / NODE_GAP` donne l'index
    /// fractionnaire, que les positions datées transforment en avancée réelle.
    var activeProgress: Double {
        HecJourneyLayout.position(
            atIndex: Double(scrollOffset / HecJourneyGesture.nodeGap),
            positions: positions
        )
    }

    /// Position d'un bloc à l'écran. La **date** décide de l'écart vertical,
    /// jamais l'index : deux blocs proches dans le temps restent proches, un
    /// bloc lointain descend de tout son décalage de position
    /// (`positions[index] − activeProgress`) multiplié par `NODE_GAP`, comme la
    /// caméra 3D qui recule le long de la piste.
    func point(at index: Int, size: CGSize) -> CGPoint {
        let world = HecJourneyGeometry.worldPoint(progress(at: index))
        return CGPoint(
            x: size.width / 2 + CGFloat(world.x) * HecJourneyMetrics.worldScale,
            y: size.height * HecJourneyMetrics.focusRatio
                - CGFloat(progress(at: index) - activeProgress) * HecJourneyGesture.nodeGap
        )
    }

    /// Opacité d'un bloc : la brume de la scène 3D (`hecJourneyFogVisibility`),
    /// sans plancher — un bloc noyé dans la brume disparaît, comme la source.
    func opacity(at index: Int) -> Double {
        HecJourneyGeometry.visibility(
            progress: progress(at: index),
            activeProgress: activeProgress
        )
    }

    /// Opacité du blason, par la même loi que les blocs
    /// (`hecJourneyFogVisibility` appliquée à la distance caméra).
    func crestOpacity(at index: Int) -> Double {
        HecJourneyGeometry.fogVisibility(distance: crestDistance(at: index))
    }

    /// Échelle du blason (`HecJourneyScene.tsx:133`) :
    /// `max(0,32, min(1,05, 5,7 / distance))`.
    func crestScale(at index: Int) -> CGFloat {
        let distance = crestDistance(at: index)
        return CGFloat(max(0.32, min(1.05, 5.7 / max(0.0001, distance))))
    }

    /// Crans à dessiner : ceux dont la position datée tombe dans la fenêtre
    /// verticale visible, de part et d'autre du bloc courant. La source, elle,
    /// confie la découpe à la carte graphique.
    func visibleIndices(size: CGSize) -> [Int] {
        guard !blocks.isEmpty else { return [] }
        let half = Double(size.height) / 2 + Double(HecJourneyGesture.nodeGap)
        let progress = activeProgress
        let visible = blocks.indices.filter {
            abs(self.progress(at: $0) - progress) * Double(HecJourneyGesture.nodeGap) <= half
        }
        if !visible.isEmpty { return visible }
        let anchor = HecJourneyGesture.activeIndex(offset: scrollOffset, count: blocks.count)
        return [max(0, min(blocks.count - 1, anchor))]
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

    private func crestDistance(at index: Int) -> Double {
        HecJourneyGeometry.cameraDistance(
            to: progress(at: index),
            activeProgress: activeProgress
        )
    }

    private func progress(at index: Int) -> Double {
        positions.indices.contains(index) ? positions[index] : 0
    }
}
