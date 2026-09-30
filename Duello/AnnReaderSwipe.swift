import SwiftUI

// MARK: - Balayage du document et séparateur
//
// Extrait de `AnnReaderWorkspace.swift` (vague 6, lot S02) pour libérer des
// lignes et des fonctions : le suivi de vitesse, la résolution du geste
// horizontal et la poignée du séparateur. Contenu repris **ligne pour ligne** —
// aucun type, propriété, méthode ni signature renommé.

/// Suit la vitesse horizontale d'un glissement, sans provoquer de rendu
/// (contrairement à un `@State` mis à jour à chaque point).
final class AnnSwipeTracker {
    private var lastX: CGFloat = 0
    private var lastTime: Date = .distantPast
    private(set) var velocityX: Double = 0

    func sample(_ x: CGFloat) {
        let now = Date()
        let interval = now.timeIntervalSince(lastTime)
        if interval > 0, lastTime != .distantPast {
            velocityX = Double(x - lastX) / interval
        }
        lastX = x
        lastTime = now
    }
}

/// Direction d'un glissement, résolue à l'axe dominant (`horizontalGesture.ts`).
enum AnnGestureIntent {
    case pending
    case horizontal
    case vertical
}

/// Seuils et cible du balayage de document, repris de `horizontalGesture.ts`
/// et `documentModeSwipe.ts`.
enum AnnDocumentSwipe {
    /// `HORIZONTAL_ACTIVATION_DISTANCE`.
    static let activationDistance = 9.0
    /// `VERTICAL_FAILURE_DISTANCE`.
    static let verticalFailureDistance = 4.0
    /// `HORIZONTAL_DOMINANCE_RATIO`.
    static let dominanceRatio = 1.5
    /// `SWIPE_COMMIT_DISTANCE`.
    static let commitDistance = 32.0
    /// `SWIPE_FLICK_MIN_DISTANCE`.
    static let flickMinDistance = 12.0
    /// `SWIPE_FLICK_VELOCITY`.
    static let flickVelocity = 380.0

    /// `resolveHorizontalGestureIntent` : l'axe vertical garde la main sur un
    /// défilement, l'axe horizontal n'est réservé que sur une intention nette.
    static func intent(translationX: Double, translationY: Double) -> AnnGestureIntent {
        let distanceX = abs(translationX)
        let distanceY = abs(translationY)
        if distanceY >= verticalFailureDistance, distanceY >= distanceX { return .vertical }
        if distanceX >= activationDistance, distanceX > distanceY * dominanceRatio { return .horizontal }
        return .pending
    }

    /// `resolveDocumentSwipeTarget` : un geste trop court garde l'onglet courant,
    /// la gauche va au corrigé déverrouillé, la droite revient à l'énoncé.
    static func target(
        current: AnnDocumentMode,
        translationX: Double,
        velocityX: Double,
        canShowSolution: Bool
    ) -> AnnDocumentMode? {
        let distance = abs(translationX)
        let deliberate = distance > commitDistance
            || (distance > flickMinDistance && abs(velocityX) > flickVelocity)
        guard deliberate else { return nil }
        let direction = distance > 2 ? translationX : velocityX
        if direction >= 0 { return .statement }
        return canShowSolution ? .solution : nil
    }
}

/// Poignée du séparateur : 24 pt de haut, trait `border` 2 pt (`paneSplitter`, `:900-935`).
struct AnnSplitterHandle: View {
    /// Hauteur de la zone de préhension (`paneSplitterRoot.height`, `:900`).
    static let height: CGFloat = 24

    let ratio: Double
    let bounds: (min: Double, max: Double)
    let contentHeight: CGFloat
    let onRatio: (Double) -> Void
    let onCommit: () -> Void

    /// Position de la ligne au début du geste (`dragOrigin`, `:698`).
    @State private var dragOrigin: Double?

    var body: some View {
        Rectangle()
            .fill(Theme.border)
            .frame(height: 2)
            .frame(maxWidth: .infinity, minHeight: Self.height)
            .background(Theme.background)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 2)
                    .onChanged { value in
                        let origin = dragOrigin ?? ratio
                        if dragOrigin == nil { dragOrigin = origin }
                        guard contentHeight > 0 else { return }
                        let next = origin + Double(value.translation.height) / Double(contentHeight)
                        onRatio(min(bounds.max, max(bounds.min, next)))
                    }
                    .onEnded { _ in
                        dragOrigin = nil
                        onCommit()
                    }
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Hauteur de l’énoncé ou du corrigé")
            .accessibilityHint("Maintiens puis déplace la ligne pour agrandir l’énoncé ou le champ de réponse")
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: nudge(AnnaleSplit.SPLIT_STEP)
                case .decrement: nudge(-AnnaleSplit.SPLIT_STEP)
                @unknown default: break
                }
            }
    }

    /// `nudgeRatio` : un cran au clavier/lecteur d'écran, puis enregistrement.
    private func nudge(_ delta: Double) {
        onRatio(min(bounds.max, max(bounds.min, ratio + delta)))
        onCommit()
    }
}
