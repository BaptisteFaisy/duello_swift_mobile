import AVFoundation
import SwiftUI
import UIKit

// Porté depuis `src/components/remote-photo-connection/useRemotePhotoSender.ts`
// (branche caméra de `pickRemotePhotos`, lot N, photo à distance) et
// `src/hooks/useRemotePhotoCapturePrompt.ts` (branche caméra de
// `pickRequestedPhoto`). AVFoundation et la présentation de l'appareil photo
// sont isolés dans ce fichier : autorisation `NSCameraUsageDescription`, capture
// d'une image convertie en JPEG. Sur un appareil sans caméra — simulateur — le
// sélecteur retombe sur la photothèque, comme le font les autres écrans.
//
// `quality` et `allowsEditing` reproduisent `ImagePickerOptions` : la demande de
// photo du web (`useRemotePhotoCapturePrompt.ts:110-116`) emploie `quality: 0.82`
// et, pour une photo de profil, `allowsEditing` (recadrage carré 1:1).

/// Sélecteur d'appareil photo (une image → un `RemPhotoAsset` JPEG).
struct RemPhotoCameraPicker: UIViewControllerRepresentable {
    /// Recadrage carré interactif (`allowsEditing` / `aspect [1,1]`).
    var allowsEditing: Bool = false
    /// Qualité JPEG (`quality`). Défaut de l'envoi distant : 0.8.
    var quality: CGFloat = 0.8
    let onPick: ([RemPhotoAsset]) -> Void
    let onError: (Error) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let controller = UIImagePickerController()
        controller.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera)
            ? .camera
            : .photoLibrary
        controller.allowsEditing = allowsEditing
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(allowsEditing: allowsEditing, quality: quality, onPick: onPick, onError: onError)
    }

    /// Convertit l'image capturée en JPEG, hors du fil principal.
    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        private let allowsEditing: Bool
        private let quality: CGFloat
        private let onPick: ([RemPhotoAsset]) -> Void
        private let onError: (Error) -> Void

        init(allowsEditing: Bool, quality: CGFloat, onPick: @escaping ([RemPhotoAsset]) -> Void, onError: @escaping (Error) -> Void) {
            self.allowsEditing = allowsEditing
            self.quality = quality
            self.onPick = onPick
            self.onError = onError
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            picker.dismiss(animated: true)
            // `allowsEditing` : l'image recadrée (carré 1:1) prime sur l'originale.
            let picked = (allowsEditing ? info[.editedImage] as? UIImage : nil) ?? info[.originalImage] as? UIImage
            guard let image = picked,
                  let data = image.jpegData(compressionQuality: quality)
            else {
                onError(RemPhotoError(
                    message: "La photo sélectionnée est vide.",
                    status: 400,
                    code: "empty-photo"
                ))
                return
            }
            onPick([RemPhotoAsset(data: data, fileName: nil, mimeType: "image/jpeg")])
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}

/// Autorisation caméra (`ImagePicker.requestCameraPermissionsAsync`).
enum RemPhotoCameraAccess {
    static func ensure() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .video)
        default:
            return false
        }
    }
}
