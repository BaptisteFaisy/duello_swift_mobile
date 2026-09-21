import SwiftUI

/// Gestes de la frise, portés de `src/utils/hecJourney.ts`.
///
/// La source arbitre **une seule fois** l'axe du geste : horizontal il
/// appartient au pager d'onglets (`hecJourneyGestureAxis`), vertical il fait
/// défiler la frise comme une ascension — faire glisser le doigt vers le bas
/// fait monter dans les chapitres, puis le faire glisser vers le haut permet de
/// redescendre (`hecJourneyOffsetFromPull`).
enum HecJourneyGesture {

    enum Axis { case horizontal, vertical }

    /// `HEC_JOURNEY_NODE_GAP` : distance entre deux crans.
    static let nodeGap: CGFloat = 140
    /// `HEC_JOURNEY_DRAG_ACTIVATION_DISTANCE`.
    static let dragActivationDistance: CGFloat = 10
    /// Bornes de l'élan projeté (`Math.max(-1.8, Math.min(1.8, vy)) * 72`).
    static let momentumLimit: CGFloat = 1.8
    static let momentumStep: CGFloat = 72

    /// `hecJourneyGestureAxis` : l'axe est décidé une fois pour toutes.
    static func axis(dx: CGFloat, dy: CGFloat) -> Axis? {
        if abs(dx) > dragActivationDistance, abs(dx) > abs(dy) * 1.2 { return .horizontal }
        if shouldStartDrag(dx: dx, dy: dy) { return .vertical }
        return nil
    }

    /// `shouldStartHecJourneyDrag` : un léger tremblement reste un appui sur le
    /// bloc, pas un défilement.
    static func shouldStartDrag(dx: CGFloat, dy: CGFloat) -> Bool {
        abs(dy) > dragActivationDistance && abs(dy) > abs(dx) * 1.35
    }

    /// `hecJourneyActiveIndex` : cran le plus proche du décalage courant.
    static func activeIndex(offset: CGFloat, count: Int) -> Int {
        guard count > 0 else { return -1 }
        let raw = (max(0, offset) / nodeGap).rounded()
        return Int(min(max(0, raw), CGFloat(count - 1)))
    }

    /// `hecJourneyOffsetFromPull` : décalage borné aux deux extrémités.
    static func offsetFromPull(startOffset: CGFloat, translationY: CGFloat, count: Int) -> CGFloat {
        let maximum = max(0, CGFloat(count - 1)) * nodeGap
        return min(max(startOffset + translationY, 0), maximum)
    }

    /// Élan projeté : la source multiplie la vitesse par 72 points
    /// (`withSpring(targetIndex * HEC_JOURNEY_NODE_GAP)`) ; SwiftUI fournit une
    /// translation projetée, dont on retire la translation déjà parcourue pour
    /// obtenir le même dépassement.
    static func momentum(from value: DragGesture.Value) -> CGFloat {
        let residual = value.predictedEndTranslation.height - value.translation.height
        let limit = momentumLimit * momentumStep
        return min(max(residual, -limit), limit)
    }
}
