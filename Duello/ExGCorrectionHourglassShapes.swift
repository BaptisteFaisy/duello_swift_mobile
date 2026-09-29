//
//  ExGCorrectionHourglassShapes.swift
//  Duello
//
//  Formes du sablier de correction (`CorrectionHourglass.tsx`) : contour du
//  verre, polygone de sable et filet. Découpé de
//  `ExGCorrectionCountdownAndBars.swift` le 2026-09-29 (ratchet : 12 fonctions
//  > 10) — contenu repris **ligne pour ligne**.
//  Cible : iOS 16.
//
import SwiftUI

enum ExGHourglassBox {
    static func point(_ x: CGFloat, _ y: CGFloat, in rect: CGRect) -> CGPoint {
        CGPoint(x: rect.minX + x * rect.width / 24, y: rect.minY + y * rect.height / 32)
    }
}

/// Contour du verre (`GLASS_POINTS`), du haut vers le bas en passant par le col.
struct ExGHourglassGlassShape: Shape {
    /// Sommets du verre, dans la boîte 24×32 du SVG.
    static let points: [(CGFloat, CGFloat)] = [
        (5, 2), (19, 2), (12, 16), (19, 30), (5, 30), (12, 16),
    ]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addLines(Self.points.map { ExGHourglassBox.point($0.0, $0.1, in: rect) })
        path.closeSubpath()
        return path
    }
}

/// Polygone de sable du sablier, rempli d'encre.
struct ExGHourglassSandShape: Shape {
    let points: [CGPoint]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addLines(points.map { ExGHourglassBox.point($0.x, $0.y, in: rect) })
        path.closeSubpath()
        return path
    }
}

/// Filet du sablier : du col vers le tas (`AnimatedStream`).
struct ExGHourglassStreamShape: Shape {
    let streamY2: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: ExGHourglassBox.point(12, 15.6, in: rect))
        path.addLine(to: ExGHourglassBox.point(12, streamY2, in: rect))
        return path
    }
}
