//
//  ChartXpProgressBar.swift
//  Duello
//
//  Barre d'expérience animée (lot D « Graphiques », préfixe `Chart`).
//
//  Fichier source Expo porté (libellés repris mot pour mot) :
//    - src/components/XpProgressBar.tsx (`XpProgressBar`)
//
//  La barre se remplit à l'ouverture puis à chaque gain d'XP : 700 ms, sortie
//  cubique (`Easing.out(Easing.cubic)` ≈ `.timingCurve(0.215, 0.61, 0.355, 1)`).
//  Cible iOS 16.
//
import SwiftUI

/// `XpProgressBar` de `src/components/XpProgressBar.tsx` : barre d'expérience
/// dont le remplissage suit la progression dans le niveau courant.
struct ChartXpProgressBar: View {
    /// Avancement dans le niveau courant, entre 0 et 1.
    var progress: Double
    var height: CGFloat = 10
    var trackColor: Color = Theme.surfaceMuted
    var fillColor: Color = Theme.progress

    @State private var animated: Double = 0

    /// Progression bornée à [0, 1], comme `Math.min(Math.max(progress, 0), 1)`.
    private var target: Double {
        progress.isFinite ? min(max(progress, 0), 1) : 0
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(trackColor)
                Capsule()
                    .fill(fillColor)
                    .frame(width: geo.size.width * animated)
            }
        }
        .frame(height: height)
        .clipShape(Capsule())
        .accessibilityElement()
        .accessibilityLabel("Progression XP")
        .accessibilityValue("\(Int(target * 100)) %")
        .onAppear { animate(to: target) }
        .onChange(of: target) { newValue in animate(to: newValue) }
    }

    /// Anime le remplissage vers la valeur cible (durée et courbe de la source).
    private func animate(to value: Double) {
        withAnimation(.timingCurve(0.215, 0.61, 0.355, 1, duration: 0.7)) {
            animated = value
        }
    }
}
