//
//  PhotoPickUri.swift
//  Duello
//
//  Normalisation d'URI de photo de profil — port de
//  `src/utils/profilePhotoUri.ts`.
//
//  Seule une miniature JPEG autonome produite par l'app peut quitter le
//  téléphone : ni chemin local (`file://`), ni URL distante, ni autre format
//  (PNG par exemple). Les mêmes règles protègent l'annuaire, qui refuse toute
//  valeur non conforme.
//
//  Cible : iOS 16.
//
import Foundation

enum PhotoPickUri {
    /// `MAX_PUBLIC_PROFILE_PHOTO_URI_LENGTH` : plafond de longueur de la
    /// miniature publiée (12 000 caractères).
    static let maxLength = 12_000

    /// `publicProfilePhotoUri` : rend l'URI si — et seulement si — c'est une
    /// miniature JPEG base64 sous le plafond, sinon `nil`.
    static func publicProfilePhotoUri(_ value: String?) -> String? {
        guard let value else { return nil }
        guard value.count <= maxLength else { return nil }
        guard value.range(
            of: #"^data:image/jpeg;base64,[A-Za-z0-9+/]+={0,2}$"#,
            options: .regularExpression
        ) != nil else { return nil }
        return value
    }
}
