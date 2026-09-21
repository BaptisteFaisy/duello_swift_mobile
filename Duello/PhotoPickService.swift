//
//  PhotoPickService.swift
//  Duello
//
//  Sélection, recadrage et publication de la photo de profil — port de
//  `src/components/profile-photo/useProfilePhotoPicker.ts` (sélection et
//  phases), `src/utils/profilePhoto.ts` (`profilePhotoDataUri`, variantes de
//  miniature) et `src/utils/socialApi.ts` (`publishSocialProfile` /
//  `publicProfile`, publication à l'annuaire).
//
//  Toute la mécanique native de sélection (`UIImagePickerController`,
//  `PhotosUI`) est isolée dans `PhotoPickImagePicker.swift` ; ce service ne
//  garde que le choix de la source, le recadrage carré, la compression et
//  l'envoi. La capture depuis un téléphone lié (`capturePhotoFromConnectedPhone`
//  de `src/utils/remotePhotoCapture.ts`) relève du portage « photo à distance »
//  (lot N) : elle est reçue ici par une fermeture, jamais appelée directement.
//
//  Cible : iOS 16.
//
import Foundation
import UIKit
import AVFoundation

/// Source locale d'une photo de profil (`ImagePicker` : caméra ou photothèque).
enum PhotoPickSource: String, Identifiable {
    case camera, library

    var id: String { rawValue }
}

/// Erreurs de préparation d'une photo de profil, libellés mot pour mot de la
/// source Expo.
enum PhotoPickError: LocalizedError {
    case cameraPermissionDenied
    case tooLarge
    case incompleteProfile

    var message: String {
        switch self {
        case .cameraPermissionDenied:
            return "Autorise Duello à utiliser l’appareil photo pour prendre ta photo de profil."
        case .tooLarge:
            return "La photo reste trop volumineuse après compression."
        case .incompleteProfile:
            return "Complète ton nom et ton e-mail pour publier ta photo."
        }
    }

    var errorDescription: String? { message }
}

enum PhotoPickService {
    /// Variantes de miniature, de la plus lisible à la plus légère
    /// (`PROFILE_PHOTO_VARIANTS` de `profilePhoto.ts`).
    static let variants: [(edge: CGFloat, compress: CGFloat)] = [
        (edge: 144, compress: 0.65),
        (edge: 112, compress: 0.52),
        (edge: 88, compress: 0.42),
    ]

    /// Source UIKit retenue : la caméra quand elle existe, sinon la
    /// photothèque (même repli que `AnnCameraPicker` / `EvEventCameraPicker`).
    static func resolvedSource(_ source: PhotoPickSource) -> UIImagePickerController.SourceType {
        guard source == .camera,
              UIImagePickerController.isSourceTypeAvailable(.camera) else { return .photoLibrary }
        return .camera
    }

    /// Brique de sélection : sélecteur natif (caméra ou photothèque) avec
    /// recadrage carré, équivalent de `launchCameraAsync` / `launchImageLibraryAsync`
    /// avec `allowsEditing: true` et `aspect: [1, 1]`.
    static func picker(
        source: PhotoPickSource,
        onPick: @escaping (UIImage) -> Void,
        onCancel: @escaping () -> Void
    ) -> PhotoPickImagePicker {
        PhotoPickImagePicker(source: source, onPick: onPick, onCancel: onCancel)
    }

    /// `requestCameraPermissionsAsync` : la permission caméra n'est demandée
    /// qu'avant une prise de vue, jamais pour la photothèque.
    static func ensureCameraAccess() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: return true
        case .notDetermined: return await AVCaptureDevice.requestAccess(for: .video)
        default: return false
        }
    }

    /// Recadre en carré puis compresse par paliers jusqu'à tenir sous le
    /// plafond de publication. Port de `profilePhotoDataUri`.
    static func dataUri(from image: UIImage) throws -> String {
        for variant in variants {
            let square = squareImage(image, edge: variant.edge)
            guard let data = square.jpegData(compressionQuality: variant.compress) else { continue }
            let dataUri = "data:image/jpeg;base64,\(data.base64EncodedString())"
            if dataUri.count <= PhotoPickUri.maxLength { return dataUri }
        }
        throw PhotoPickError.tooLarge
    }

    /// Publie la photo à l'annuaire (`PUT /profiles`, port de
    /// `publishSocialProfile`) : seule la miniature validée part, jamais une
    /// URI locale. `nil` retire la photo. L'annuaire ne reçoit que les champs
    /// portés par `UserProfile` ; la performance, l'emploi du temps et les
    /// détails premium relèvent du portage du profil public (autre lot).
    static func upload(photoUri: String?, profile: UserProfile, token: String?) async throws {
        let email = profile.email.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayName = profile.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !email.isEmpty, !displayName.isEmpty else { throw PhotoPickError.incompleteProfile }
        let body = PhotoPickPublicBody(
            id: DuelloAPI.publicProfileId(email: email),
            displayName: displayName,
            prepName: profile.prepName.trimmingCharacters(in: .whitespacesAndNewlines),
            className: profile.className.trimmingCharacters(in: .whitespacesAndNewlines),
            track: profile.track,
            year: profile.year,
            targetSchool: profile.targetSchool.trimmingCharacters(in: .whitespacesAndNewlines),
            photoUri: PhotoPickUri.publicProfilePhotoUri(photoUri),
            isPublic: true
        )
        let data = try DuelloAPI.encodeBody(body)
        _ = try await DuelloAPI.request("/profiles", method: "PUT", token: token, body: data)
    }

    /// Recadrage carré centré (aspect-fill), puis mise à l'échelle `edge` —
    /// équivalent de `resize({ width, height })` de `expo-image-manipulator`.
    private static func squareImage(_ image: UIImage, edge: CGFloat) -> UIImage {
        let side = min(image.size.width, image.size.height)
        guard side > 0 else { return image }
        let scale = edge / side
        let drawSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let origin = CGPoint(x: (edge - drawSize.width) / 2, y: (edge - drawSize.height) / 2)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: CGSize(width: edge, height: edge), format: format)
            .image { _ in image.draw(in: CGRect(origin: origin, size: drawSize)) }
    }
}

/// Corps minimal du profil public envoyé à l'annuaire (`publicProfile` de
/// `socialApi.ts`, limité aux champs déclarés dans `UserProfile`).
private struct PhotoPickPublicBody: Encodable {
    let id: String
    let displayName: String
    let prepName: String
    let className: String
    let track: String
    let year: String
    let targetSchool: String
    let photoUri: String?
    let isPublic: Bool
}
