//
//  LeagueBadgeOutline.swift
//  Duello
//
//  Blason détouré (`LeagueBadgeOutline.tsx`).
//
//  Fichiers source Expo portés (libellés et géométrie repris mot pour mot) :
//    - src/components/LeagueBadgeOutline.tsx
//
//  La source teinte les PNG par `tintColor` (React Native) et empile huit copies
//  décalées d'un point : elles dessinent le contour, une neuvième copie teintée
//  de la couleur de surface remplit le centre. Ici les images sont rendues en
//  mode gabarit (`.renderingMode(.template)`) puis colorées : même silhouette,
//  mêmes teintes `colors.ink` / `colors.surface`. Les blasons sont chargés à
//  distance (`LeagueBadges`), les PNG n'étant pas embarqués. Sans blason, la
//  source affiche `shield-outline` : le repli est le symbole SF `shield`.
//
//  Cible : iOS 16, aucune API iOS 17.
//
import SwiftUI

/// Blason détouré : huit copies d'encre décalées d'un point, une copie de
/// surface au centre.
struct LeagueBadgeOutline: View {
    /// Adresse du blason ; `nil` ⇒ repli bouclier.
    let badgeURL: URL?
    /// Côté du blason, en points.
    let size: CGFloat

    /// `OUTLINE_OFFSETS` : les huit décalages d'un point, dans l'ordre exact.
    private static let outlineOffsets: [(x: CGFloat, y: CGFloat)] = [
        (-1, -1), (0, -1), (1, -1), (-1, 0), (1, 0), (-1, 1), (0, 1), (1, 1),
    ]

    var body: some View {
        if let badgeURL {
            ZStack {
                ForEach(Self.outlineOffsets.indices, id: \.self) { index in
                    let offset = Self.outlineOffsets[index]
                    LeagueOutlineImage(url: badgeURL, size: size, tint: Theme.ink)
                        .offset(x: offset.x, y: offset.y)
                }
                LeagueOutlineImage(url: badgeURL, size: size, tint: Theme.surface)
            }
            .frame(width: size, height: size)
            .accessibilityHidden(true)
        } else {
            Image(systemName: "shield")
                .font(.system(size: size * 0.7))
                .foregroundStyle(Theme.ink)
                .frame(width: size, height: size)
                .accessibilityHidden(true)
        }
    }
}

/// Une copie du blason, chargée à distance puis teintée (mode gabarit).
private struct LeagueOutlineImage: View {
    let url: URL
    let size: CGFloat
    let tint: Color

    var body: some View {
        CachedRemoteImage(url: url) { image in
            image
                .resizable()
                .renderingMode(.template)
                .scaledToFit()
                .foregroundStyle(tint)
        } placeholder: {
            Color.clear
        }
        .frame(width: size, height: size)
    }
}
