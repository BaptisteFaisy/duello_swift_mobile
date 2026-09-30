//
//  Ui2DismissSheetPan.swift
//  Duello
//
//  Fermeture d'une feuille par glissement vers le bas.
//
//  Fichier source Expo porté :
//  `src/components/photo-transcription/useDismissSheetPan.ts`
//  (`useDismissSheetPan` : `translateY` + `panResponder`). Les seuils et le
//  ressort sont repris mot pour mot : le geste ne s'accroche que sur un
//  glissement **vers le bas** (`dy > 3` et plus vertical qu'horizontal), suit
//  le doigt, puis ferme si la distance dépasse 48 points ou si un coup sec est
//  donné (`dy > 12` et `vy > 0,55 pt/ms`) ; sinon la feuille revient en place
//  sans rebond (`bounciness: 0` → amortissement critique).
//
//  `PhotoTranscriptionModal.tsx:91` porte ce geste sur la feuille ; le portage
//  l'expose en modificateur réutilisable (`dismissSheetPan(onClose:)`), à poser
//  sur le contenu de la feuille.
//
//  Cible : iOS 16. Aucune dépendance externe.
//
import SwiftUI

/// `useDismissSheetPan` : glissement de fermeture d'une feuille.
struct DismissSheetPanModifier: ViewModifier {
    /// `onClose` : appelé quand le geste demande la fermeture.
    var onClose: () -> Void

    /// `translateY` de la source : décalage vertical courant, 0 au repos.
    @State private var translateY: CGFloat = 0
    /// Geste accroché (`onMoveShouldSetPanResponder` une fois accordé) : il le
    /// reste jusqu'au relâchement, même si le doigt remonte.
    @State private var captured = false
    /// Horodatage du dernier échantillon, pour estimer la vitesse.
    @State private var lastTime: Date?
    /// Décalage du dernier échantillon, pour estimer la vitesse.
    @State private var lastTranslation: CGFloat = 0

    /// `gesture.dy > 3` : seuil d'accroche du geste.
    private static let grabDistance: CGFloat = 3
    /// `gesture.dy > 48` : distance de fermeture franche.
    private static let dismissDistance: CGFloat = 48
    /// `gesture.dy > 12` : distance minimale d'un coup sec.
    private static let flickDistance: CGFloat = 12
    /// `gesture.vy > 0,55` (points par milliseconde) → points par seconde.
    private static let flickVelocity: CGFloat = 550

    func body(content: Content) -> some View {
        content
            .offset(y: translateY)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged(handleChange)
                    .onEnded(handleEnd)
            )
    }

    /// `onPanResponderMove` : accroche sur un glissement vers le bas, puis suit
    /// le doigt tant qu'il descend (`if (gesture.dy > 0) translateY.setValue`).
    private func handleChange(_ value: DragGesture.Value) {
        let height = value.translation.height
        if !captured {
            // `dy > 3 && |dy| > |dx|` : jamais sur un geste horizontal.
            guard height > Self.grabDistance,
                  abs(height) > abs(value.translation.width) else { return }
            captured = true
            lastTime = value.time
        }
        lastTranslation = height
        if height > 0 { translateY = height }
    }

    /// `onPanResponderRelease` : ferme sur distance franche ou coup sec, sinon
    /// revient en place (`Animated.spring(…, bounciness: 0)`).
    private func handleEnd(_ value: DragGesture.Value) {
        guard captured else { return }
        let distance = value.translation.height
        let velocity = releaseVelocity(endingAt: value.time, distance: distance)
        captured = false
        lastTime = nil
        if distance > Self.dismissDistance
            || (distance > Self.flickDistance && velocity > Self.flickVelocity) {
            onClose()
            translateY = 0
            return
        }
        withAnimation(.spring(response: 0.3, dampingFraction: 1)) {
            translateY = 0
        }
    }

    /// Vitesse de relâchement en points par seconde (la source exprime `vy` en
    /// points par milliseconde : `0,55 pt/ms` = `550 pt/s`).
    private func releaseVelocity(endingAt time: Date, distance: CGFloat) -> CGFloat {
        guard let lastTime else { return 0 }
        let seconds = time.timeIntervalSince(lastTime)
        guard seconds > 0 else { return 0 }
        return (distance - lastTranslation) / CGFloat(seconds)
    }
}

extension View {
    /// `useDismissSheetPan` : rend la feuille glissable vers le bas pour fermer.
    /// À poser sur le contenu de la feuille (`PhotoTranscriptionModal.tsx:91`).
    func dismissSheetPan(onClose: @escaping () -> Void) -> some View {
        modifier(DismissSheetPanModifier(onClose: onClose))
    }
}
