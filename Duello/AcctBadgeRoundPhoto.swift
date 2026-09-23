//
//  AcctBadgeRoundPhoto.swift
//  Duello
//
//  Photo ronde de la vitrine de profil — port de `RoundProfilePhoto` de
//  `src/screens/AccountScreen.tsx` (l. 241-296).
//
//  La source dessine un SVG `viewBox="0 0 100 100"` : un disque de rayon 47
//  rempli de `colors.primaryLight`, la miniature JPEG découpée en cercle
//  (`preserveAspectRatio="xMidYMid slice"`), puis deux cercles de contour —
//  blanc (`strokeWidth` 3) et bord (`strokeWidth` 1,25). À défaut de photo,
//  l'initiale du nom en capitale (`toLocaleUpperCase('fr-FR')`), corps 38,
//  graisse 900.
//
//  La géométrie du disque (rayon 47/100) est reprise de `FlipBadgePresence`
//  (`profilePhotoRadiusFraction`) ; les épaisseurs de trait, exprimées dans la
//  `viewBox`, sont mises à l'échelle de la taille demandée (la source les met
//  aussi à l'échelle, la `viewBox` valant 100). Le décodage de l'URI publiée
//  réutilise `PhotoPickUri.publicProfilePhotoUri` ; `PhotoPickAvatar` reste le
//  jumeau employé par le sélecteur de photo.
//
//  Cible : iOS 16, aucune API iOS 17.
//
import SwiftUI
import UIKit

/// Disque de photo de profil du blason de vitrine (`RoundProfilePhoto`).
struct AcctBadgeRoundPhoto: View {
    /// Nom affiché : fournit l'initiale de repli.
    let name: String
    /// Photo publiée (miniature JPEG `data:` ou adresse distante), ou `nil`.
    let photoUri: String?
    /// Côté du carré, en points (la `viewBox` de la source).
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(Theme.primaryLight)
                .frame(width: disc, height: disc)
            photoLayer
            Circle()
                .stroke(Theme.surface, lineWidth: scaledStroke(3))
                .frame(width: disc, height: disc)
            Circle()
                .stroke(Theme.border, lineWidth: scaledStroke(1.25))
                .frame(width: disc, height: disc)
        }
        .frame(width: size, height: size)
    }

    /// Diamètre du disque : `2 × r`, avec `r = 47` pour une `viewBox` de 100.
    private var disc: CGFloat {
        size * 2 * FlipBadgePresence.profilePhotoRadiusFraction
    }

    /// Épaisseur d'un trait de la `viewBox` (sur 100) ramenée à `size`.
    private func scaledStroke(_ viewBoxWidth: CGFloat) -> CGFloat {
        size * viewBoxWidth / 100
    }

    /// Photo découpée en cercle, sinon l'initiale.
    @ViewBuilder
    private var photoLayer: some View {
        if let source = localPhotoSource {
            CachedImage(source) { image in
                image
                    .resizable()
                    .scaledToFill()
                    .frame(width: disc, height: disc)
                    .clipShape(Circle())
            } placeholder: {
                initialLabel
            }
        } else if let url = remoteURL {
            CachedRemoteImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Color.clear
            }
            .frame(width: disc, height: disc)
            .clipShape(Circle())
        } else {
            initialLabel
        }
    }

    /// Initiale du nom, centrée dans le disque (`x = 50`, `y = 63`).
    private var initialLabel: some View {
        Text(initial)
            .font(.system(size: size * 0.38, weight: .black))
            .foregroundStyle(Theme.ink)
    }

    /// Première lettre du nom, en capitale française (`toLocaleUpperCase('fr-FR')`).
    private var initial: String {
        guard let first = name.first else { return "" }
        return String(first).uppercased(with: Locale(identifier: "fr_FR"))
    }

    /// Miniature JPEG `data:` décodée localement (`publicProfilePhotoUri`) :
    /// octets + clé de cache, le décodage lui-même passe par `CachedImage`.
    private var localPhotoSource: CachedImageSource? {
        guard let uri = PhotoPickUri.publicProfilePhotoUri(photoUri),
              let comma = uri.firstIndex(of: ","),
              let data = Data(base64Encoded: String(uri[uri.index(after: comma)...])) else { return nil }
        return .data(data, key: ImageCache.key(for: uri))
    }

    /// Adresse distante, quand l'URI n'est pas une miniature `data:`.
    private var remoteURL: URL? {
        guard let uri = photoUri, !uri.isEmpty, !uri.hasPrefix("data:") else { return nil }
        return URL(string: uri)
    }
}
