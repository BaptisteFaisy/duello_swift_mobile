//
//  PhotoPickAvatar.swift
//  Duello
//
//  Vignette ronde de la photo de profil — port de `RoundProfilePhoto` de
//  `src/screens/AccountScreen.tsx` : la miniature JPEG est découpée en cercle
//  (`preserveAspectRatio="xMidYMid slice"`), cerclée de blanc puis du liseré de
//  bord ; à défaut, l'initiale du nom en capitale (`toLocaleUpperCase('fr-FR')`).
//
//  Cible : iOS 16.
//
import SwiftUI
import UIKit

struct PhotoPickAvatar: View {
    let name: String
    let photoUri: String?
    var size: CGFloat = 52

    var body: some View {
        ZStack {
            Circle().fill(Theme.primaryLight)
            photoLayer
            Circle().stroke(Theme.surface, lineWidth: 3)
            Circle().stroke(Theme.border, lineWidth: 1.25)
        }
        .frame(width: size, height: size)
    }

    /// Photo découpée en cercle, sinon l'initiale.
    @ViewBuilder private var photoLayer: some View {
        if let source = localPhotoSource {
            CachedImage(source) { image in
                image
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } placeholder: {
                initialLabel
            }
        } else {
            initialLabel
        }
    }

    /// Initiale du nom, centrée dans le disque.
    private var initialLabel: some View {
        Text(initial)
            .font(.system(size: size * 0.38, weight: .black))
            .foregroundStyle(Theme.ink)
    }

    /// Première lettre du nom, en capitale.
    private var initial: String {
        guard let first = name.trimmingCharacters(in: .whitespacesAndNewlines).first else { return "" }
        return String(first).uppercased()
    }

    /// Décode la seule URI admise à la publication (miniature JPEG base64) :
    /// octets + clé de cache, le décodage passe par `CachedImage` (une fois).
    private var localPhotoSource: CachedImageSource? {
        guard let uri = PhotoPickUri.publicProfilePhotoUri(photoUri),
              let comma = uri.firstIndex(of: ","),
              let data = Data(base64Encoded: String(uri[uri.index(after: comma)...])) else { return nil }
        return .data(data, key: ImageCache.key(for: uri))
    }
}
