import SwiftUI

/// Contour de blason : coins hauts resserrés, coins bas très arrondis, comme le
/// repli `fallbackCrest` de `src/components/HecJourneyAdmissionScreen.tsx`
/// (`borderTopLeftRadius: 26`, `borderBottomLeftRadius: 54`).
///
/// `UnevenRoundedRectangle` étant réservé à iOS 17, le contour est tracé à la
/// main avec les arcs tangents de `Path` (API disponible depuis iOS 13).
struct HecJourneyCrestShape: Shape {
    /// Rayon des deux coins supérieurs.
    var topRadius: CGFloat = 26
    /// Rayon des deux coins inférieurs.
    var bottomRadius: CGFloat = 54

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let top = min(topRadius, min(rect.width, rect.height) / 2)
        let bottom = min(bottomRadius, min(rect.width, rect.height) / 2)

        path.move(to: CGPoint(x: rect.minX + top, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - top, y: rect.minY))
        path.addArc(
            tangent1End: CGPoint(x: rect.maxX, y: rect.minY),
            tangent2End: CGPoint(x: rect.maxX, y: rect.minY + top),
            radius: top
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - bottom))
        path.addArc(
            tangent1End: CGPoint(x: rect.maxX, y: rect.maxY),
            tangent2End: CGPoint(x: rect.maxX - bottom, y: rect.maxY),
            radius: bottom
        )
        path.addLine(to: CGPoint(x: rect.minX + bottom, y: rect.maxY))
        path.addArc(
            tangent1End: CGPoint(x: rect.minX, y: rect.maxY),
            tangent2End: CGPoint(x: rect.minX, y: rect.maxY - bottom),
            radius: bottom
        )
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + top))
        path.addArc(
            tangent1End: CGPoint(x: rect.minX, y: rect.minY),
            tangent2End: CGPoint(x: rect.minX + top, y: rect.minY),
            radius: top
        )
        path.closeSubpath()
        return path
    }
}

/// Blason d'une école d'admission.
///
/// La source Expo affiche le PNG de `leagueBadgeSourceForLeague` quand il
/// existe (`assets/league-badges/*.png`) et retombe sinon sur un écusson coloré
/// portant `crestLabel` (`AdmissionCrest` de `HecJourneyAdmissionScreen.tsx` et
/// `AdmissionCrestSprite` de `HecJourneyScene.tsx`). Les badges PNG ne sont pas
/// embarqués dans l'app Swift : le repli de la source est donc le rendu
/// nominal, avec les couleurs et les libellés exacts du catalogue
/// (`HecJourneyAdmissionCatalog`).
struct HecJourneyCrestView: View {
    let crest: HecJourneyAdmissionCrest
    /// Hauteur de l'écusson ; la largeur suit le rapport 132 × 144 de la source.
    var height: CGFloat = 144

    private var width: CGFloat { height * 132 / 144 }
    private var scale: CGFloat { height / 144 }

    var body: some View {
        ZStack {
            HecJourneyCrestShape(topRadius: 26 * scale, bottomRadius: 54 * scale)
                .fill(Color(hex: crest.colorHex))
                .shadow(color: Color.black.opacity(0.16), radius: 12 * scale, y: 7 * scale)
            HecJourneyCrestShape(topRadius: 20 * scale, bottomRadius: 47 * scale)
                .stroke(Color.white.opacity(0.78), lineWidth: 2 * scale)
                .padding(7 * scale)
            Text(crest.crestLabel)
                .font(.system(size: 25 * scale, weight: .black))
                .foregroundStyle(Color.white)
                .tracking(1 * scale)
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .minimumScaleFactor(0.4)
                .frame(width: width * 0.82)
        }
        .frame(width: width, height: height)
        .accessibilityLabel(crest.schoolName)
    }
}
