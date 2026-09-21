import SwiftUI
import UIKit

/// Appareil photo (`ImagePicker.launchCameraAsync`). La cible est iOS : la
/// présentation exige la clé `NSCameraUsageDescription` dans `Info.plist` et
/// l'autorisation de l'utilisateur. Sur un appareil sans appareil photo — le
/// simulateur, par exemple — le sélecteur retombe sur la photothèque.
struct AnnCameraPicker: UIViewControllerRepresentable {
    let onPick: (AnnCopyPage) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let controller = UIImagePickerController()
        controller.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera)
            ? .camera
            : .photoLibrary
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        private let onPick: (AnnCopyPage) -> Void

        init(onPick: @escaping (AnnCopyPage) -> Void) {
            self.onPick = onPick
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            picker.dismiss(animated: true)
            guard let image = info[.originalImage] as? UIImage,
                  let data = image.jpegData(compressionQuality: AnnCopyPage.jpegQuality)
            else { return }
            onPick(AnnCopyPage(imageBase64: data.base64EncodedString(), mimeType: "image/jpeg"))
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}
