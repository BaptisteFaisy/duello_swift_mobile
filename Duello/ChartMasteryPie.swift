//
//  ChartMasteryPie.swift
//  Duello
//
//  Camembert de maîtrise (lot D « Graphiques », préfixe `Chart`).
//
//  Fichier source Expo porté (libellés repris mot pour mot) :
//    - src/components/MasteryPie.tsx (`MasteryPie`, `pieGeometry`)
//
//  La source découpe le disque en deux moitiés masquées ; SwiftUI le rend
//  directement par une part de disque remplie dans le sens horaire depuis le
//  haut — même résultat, géométrie plus simple. Indicateur : 0 = pas travaillé,
//  1/3 = à revoir, 2/3 = maîtrisé, 3/3 = assimilé. Cible iOS 16.
//
import SwiftUI

/// `MasteryPie` de `src/components/MasteryPie.tsx` : cercle rempli de 0 à
/// `total` parts, dans le sens horaire depuis le haut.
struct ChartMasteryPie: View {
    /// Nombre de parts remplies (0 à `total`).
    var filled: Int
    /// Nombre total de parts du cercle.
    var total: Int = 3
    /// Diamètre en points.
    var size: CGFloat = 20
    /// Couleur des parts remplies (`colors.mastery`).
    var fillColor: Color = exgMastery
    /// Couleur du fond (parts vides).
    var trackColor: Color = Theme.primaryLight
    /// Couleur du contour.
    var ringColor: Color = Theme.inkFaint

    private var fraction: Double {
        guard total > 0 else { return 0 }
        return Double(min(max(filled, 0), total)) / Double(total)
    }

    var body: some View {
        ZStack {
            Circle().fill(trackColor)
            ChartPieSlice(fraction: fraction).fill(fillColor)
            Circle().strokeBorder(ringColor, lineWidth: 1)
        }
        .frame(width: size, height: size)
        .accessibilityLabel("Maîtrise : \(min(max(filled, 0), total)) sur \(total)")
    }
}

/// Part de disque remplie dans le sens horaire depuis le haut.
struct ChartPieSlice: Shape {
    /// Fraction du disque à remplir, bornée à [0, 1].
    var fraction: Double

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        let sweep = 360 * min(max(fraction, 0), 1)
        path.move(to: center)
        path.addArc(
            center: center,
            radius: radius,
            startAngle: .degrees(-90),
            endAngle: .degrees(-90 + sweep),
            clockwise: false
        )
        path.closeSubpath()
        return path
    }
}
