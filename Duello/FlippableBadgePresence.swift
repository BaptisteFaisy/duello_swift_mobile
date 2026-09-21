//
//  FlippableBadgePresence.swift
//  Duello
//
//  Placement de la pastille de présence sur un blason retournable.
//
//  Fichier source Expo porté :
//    - src/utils/flippableBadgePresence.ts (PR #426, `muse/presence-dot-blason`)
//        `BADGE_SOUTH_EAST_EDGE_FRACTION`, `PROFILE_PHOTO_RADIUS_FRACTION`,
//        `flippableBadgePresenceDots`.
//
//  La pastille est centrée sur le bord de son illustration : la moitié
//  recouvre le dessin, l'autre moitié dépasse au-dehors. Le recto est un
//  blason (bord sud-est), le verso une photo ronde (bord sud-ouest).
//
//  Cible : iOS 16, aucune dépendance externe.
//
import CoreGraphics

/// Géométrie de la pastille sur un blason retournable (`flippableBadgePresence`).
enum FlipBadgePresence {

    /// Position d'une pastille dans le carré du blason (`FlippableBadgePresenceDot`).
    struct Dot: Equatable {
        let left: CGFloat
        let top: CGFloat
    }

    /// Positions du recto et du verso (`FlippableBadgePresenceDots`).
    struct Dots: Equatable {
        /// Recto : pastille centrée sur le bord sud-est du blason.
        let front: Dot
        /// Verso : pastille centrée sur le bord sud-ouest de la photo.
        let back: Dot
    }

    /// Sortie sud-est de la diagonale du blason, en fraction du carré :
    /// médiane mesurée sur les PNG embarqués (de 72,2 % à 74,4 %).
    static let badgeSouthEastEdgeFraction: CGFloat = 0.733

    /// Rayon de la photo ronde du verso, en fraction du carré : `r = 47` pour
    /// une `viewBox` de 100 dans `RoundProfilePhoto` (`AccountScreen`).
    static let profilePhotoRadiusFraction: CGFloat = 0.47

    /// Centre chaque pastille sur le bord de son illustration.
    ///
    /// - Parameters:
    ///   - boxSize: côté du carré du blason.
    ///   - dotSize: diamètre de la pastille.
    static func dots(boxSize: CGFloat, dotSize: CGFloat) -> Dots {
        let halfDot = dotSize / 2
        let frontCenter = boxSize * badgeSouthEastEdgeFraction
        let photoCenter = boxSize / 2
        let photoEdge = (boxSize * profilePhotoRadiusFraction) / sqrt(2)
        return Dots(
            front: Dot(left: frontCenter - halfDot, top: frontCenter - halfDot),
            back: Dot(
                left: photoCenter - photoEdge - halfDot,
                top: photoCenter + photoEdge - halfDot
            )
        )
    }
}
