import SwiftUI

// MARK: - Badge « compte abonné »

/// Portage de `src/components/PremiumBadge.tsx` : la coche noire qui signale un
/// compte abonné.
///
/// Elle se pose partout où un nom s'affiche — fiche de profil, résultats de
/// recherche, liste d'abonnés, invitation à un défi — et ne dit qu'une chose :
/// ce compte paie l'abonnement. Elle ne remplace jamais le cadenas d'un compte
/// privé, qui répond à une autre question.
struct PremPremiumBadge: View {
    var size: CGFloat = 15

    var body: some View {
        PremCheckmarkShape()
            .stroke(
                Theme.ink,
                style: StrokeStyle(
                    lineWidth: size * (2.4 / 16),
                    lineCap: .round,
                    lineJoin: .round
                )
            )
            .frame(width: size, height: size)
            .accessibilityElement()
            .accessibilityLabel("Compte abonné")
    }
}

/// Le tracé `M2.5 8.1 6.25 11.85 13.5 4.6` du SVG source, dans une boîte
/// 16 × 16 mise à l'échelle de la vue.
struct PremCheckmarkShape: Shape {
    func path(in rect: CGRect) -> Path {
        let unit = min(rect.width, rect.height) / 16
        var path = Path()
        path.move(to: CGPoint(x: 2.5 * unit, y: 8.1 * unit))
        path.addLine(to: CGPoint(x: 6.25 * unit, y: 11.85 * unit))
        path.addLine(to: CGPoint(x: 13.5 * unit, y: 4.6 * unit))
        return path
    }
}
