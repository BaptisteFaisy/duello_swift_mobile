//
//  EvEventCameraPicker.swift
//  Duello
//
//  Appareil photo du bouton « Photo » d'un champ de réponse
//  (`launchCameraAsync`). La cible est iOS : la présentation exige
//  `NSCameraUsageDescription` dans l'Info.plist et l'autorisation de
//  l'utilisateur. Sur un appareil sans appareil photo — le simulateur, par
//  exemple — le sélecteur retombe sur la photothèque.
//
//  Fichier source Expo porté : `pickAnswerPhoto` de
//  `src/utils/eventPhotoTranscription.ts`.
//
//  Cible : iOS 16.
//
import SwiftUI
import UIKit

struct EvEventCameraPicker: UIViewControllerRepresentable {
    /// Rend la photo choisie encodée en JPEG base64, prête pour le relais.
    let onPick: (String) -> Void
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let controller = UIImagePickerController()
        controller.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera)
            ? .camera
            : .photoLibrary
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick, onCancel: onCancel) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        private let onPick: (String) -> Void
        private let onCancel: () -> Void

        init(onPick: @escaping (String) -> Void, onCancel: @escaping () -> Void) {
            self.onPick = onPick
            self.onCancel = onCancel
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            picker.dismiss(animated: true)
            guard let image = info[.originalImage] as? UIImage,
                  let data = image.jpegData(compressionQuality: EvEventPhotoStore.jpegQuality)
            else { return }
            onPick(data.base64EncodedString())
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
            onCancel()
        }
    }
}
