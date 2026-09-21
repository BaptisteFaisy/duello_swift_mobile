import AVFoundation
import SwiftUI
import UIKit

// Porté depuis `src/components/remote-photo-connection/useRemotePhotoSender.ts`
// (branche caméra de `pickRemotePhotos`, lot N, photo à distance).
// AVFoundation et la présentation de l'appareil photo sont isolés dans ce
// fichier : autorisation `NSCameraUsageDescription`, capture d'une image
// convertie en JPEG (qualité 0.8). Sur un appareil sans caméra — simulateur —
// le sélecteur retombe sur la photothèque, comme le font les autres écrans.

/// Sélecteur d'appareil photo (une image → un `RemPhotoAsset` JPEG).
struct RemPhotoCameraPicker: UIViewControllerRepresentable {
    let onPick: ([RemPhotoAsset]) -> Void
    let onError: (Error) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let controller = UIImagePickerController()
        controller.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera)
            ? .camera
            : .photoLibrary
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick, onError: onError) }

    /// Convertit l'image capturée en JPEG, hors du fil principal.
    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        private let onPick: ([RemPhotoAsset]) -> Void
        private let onError: (Error) -> Void

        init(onPick: @escaping ([RemPhotoAsset]) -> Void, onError: @escaping (Error) -> Void) {
            self.onPick = onPick
            self.onError = onError
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            picker.dismiss(animated: true)
            guard let image = info[.originalImage] as? UIImage,
                  let data = image.jpegData(compressionQuality: 0.8)
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
