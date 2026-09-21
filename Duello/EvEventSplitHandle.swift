//
//  EvEventSplitHandle.swift
//  Duello
//
//  Ligne amovible entre le sujet et les réponses : un doigt horizontal la
//  déplace et la proportion choisie reste tant que la page est ouverte.
//
//  Fichier source Expo porté : `SplitHandle` de
//  `src/components/event/EventWorkspace.tsx`. La source mesure le déplacement
//  horizontal du doigt (`gesture.dx`) rapporté à la hauteur de la fenêtre, et
//  n'accepte le geste que s'il est plus horizontal que vertical : le portage
//  reproduit ce comportement tel quel.
//
//  Cible : iOS 16.
//
import SwiftUI

struct EvEventSplitHandle: View {
    /// Hauteur de référence de la fenêtre, comme `useWindowDimensions().height`.
    let height: CGFloat
    /// Proportion ajoutée au volet du sujet, signée.
    let onDrag: (Double) -> Void

    @State private var lastTranslation: CGFloat = 0

    var body: some View {
        ZStack {
            Capsule()
                .fill(Theme.border)
                .frame(width: 46, height: 5)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 6)
                .onChanged { value in
                    guard abs(value.translation.width) > abs(value.translation.height) else { return }
                    let delta = value.translation.width - lastTranslation
                    lastTranslation = value.translation.width
                    onDrag(Double(delta / max(1, height)))
                }
                .onEnded { _ in lastTranslation = 0 }
        )
    }
}
