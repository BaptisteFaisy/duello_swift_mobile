//
//  PhotoPickImagePicker.swift
//  Duello
//
//  Pont UIKit du sélecteur de photo de profil : caméra ou photothèque, avec
//  recadrage carré natif (`allowsEditing`, équivalent de `allowsEditing: true`
//  et `aspect: [1, 1]`) et caméra frontale par défaut (`cameraType: front`).
//  Reprend la mécanique des sélecteurs déjà portés (`AnnCameraPicker`,
//  `EvEventCameraPicker`), sans les modifier.
//
//  Fichier source Expo porté : `pickLocalProfilePhoto` de
//  `src/components/profile-photo/useProfilePhotoPicker.ts`.
//
//  Cible : iOS 16. `UIImagePickerController` est isolé ici : ce fichier est le
//  seul du lot à dépendre de la mécanique de sélection native.
//
import SwiftUI
import UIKit

struct PhotoPickImagePicker: UIViewControllerRepresentable {
    let source: PhotoPickSource
    let onPick: (UIImage) -> Void
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let controller = UIImagePickerController()
        controller.sourceType = PhotoPickService.resolvedSource(source)
        controller.allowsEditing = true
        if source == .camera { controller.cameraDevice = .front }
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick, onCancel: onCancel) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        private let onPick: (UIImage) -> Void
        private let onCancel: () -> Void

        init(onPick: @escaping (UIImage) -> Void, onCancel: @escaping () -> Void) {
            self.onPick = onPick
            self.onCancel = onCancel
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            picker.dismiss(animated: true)
            // L'image recadrée prime sur l'originale (`allowsEditing`).
            guard let image = (info[.editedImage] as? UIImage) ?? (info[.originalImage] as? UIImage) else {
                onCancel()
                return
            }
            onPick(image)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
            onCancel()
        }
    }
}
