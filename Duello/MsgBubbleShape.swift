import SwiftUI

/// Contour de bulle de message : trois coins arrondis, un coin resserré du côté
/// de l'émetteur.
///
/// `UnevenRoundedRectangle` est réservé à **iOS 17** et la cible de l'app est
/// **iOS 16** : le contour est donc tracé à la main, comme
/// `HecJourneyCrestShape` (`HecJourneyCrestView.swift`), avec les arcs tangents
/// de `Path` (API disponible depuis iOS 13).
///
/// Écart assumé avec le shim Linux : `scripts/linux-shims/SwiftUI.swift` déclare
/// `UnevenRoundedRectangle` pour rester proche du vrai framework. Ce fichier ne
/// s'en sert pas — le shim sert à vérifier, pas à autoriser.
struct MsgBubbleShape: Shape {
    /// Rayon des coins arrondis (17 dans la source Expo).
    var radius: CGFloat
    /// Rayon du coin resserré, du côté de l'émetteur (5 dans la source Expo).
    var tightRadius: CGFloat
    /// Vrai quand la bulle est celle de l'utilisateur : le coin resserré est
    /// alors en bas à droite, sinon en bas à gauche.
    var isMine: Bool

    func path(in rect: CGRect) -> Path {
        let limit = min(rect.width, rect.height) / 2
        let round = min(radius, limit)
        let tight = min(tightRadius, limit)
        let topLeading = round
        let topTrailing = round
        let bottomLeading = isMine ? round : tight
        let bottomTrailing = isMine ? tight : round

        var path = Path()
        path.move(to: CGPoint(x: rect.minX + topLeading, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - topTrailing, y: rect.minY))
        path.addArc(
            tangent1End: CGPoint(x: rect.maxX, y: rect.minY),
            tangent2End: CGPoint(x: rect.maxX, y: rect.minY + topTrailing),
            radius: topTrailing
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - bottomTrailing))
        path.addArc(
            tangent1End: CGPoint(x: rect.maxX, y: rect.maxY),
            tangent2End: CGPoint(x: rect.maxX - bottomTrailing, y: rect.maxY),
            radius: bottomTrailing
        )
        path.addLine(to: CGPoint(x: rect.minX + bottomLeading, y: rect.maxY))
        path.addArc(
            tangent1End: CGPoint(x: rect.minX, y: rect.maxY),
            tangent2End: CGPoint(x: rect.minX, y: rect.maxY - bottomLeading),
            radius: bottomLeading
        )
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + topLeading))
        path.addArc(
            tangent1End: CGPoint(x: rect.minX, y: rect.minY),
            tangent2End: CGPoint(x: rect.minX + topLeading, y: rect.minY),
            radius: topLeading
        )
        path.closeSubpath()
        return path
    }
}
