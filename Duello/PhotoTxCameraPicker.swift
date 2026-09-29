//
//  PhotoTxCameraPicker.swift
//  Duello
//
//  Sélecteur d'appareil photo de la transcription photo.
//  Découpage de `PhotoTranscriptionView.swift` — aucun changement de comportement
//  (mêmes noms, mêmes corps, mêmes chaînes, mêmes visibilités EFFECTIVES).
//

import SwiftUI
import UIKit

// MARK: - Sélecteur d'appareil photo

/// Appareil photo (`ImagePicker.launchCameraAsync`) encapsulé dans
/// `UIImagePickerController`. La présentation exige la clé `NSCameraUsageDescription`
/// dans `Info.plist`. Sur un appareil sans appareil photo — le simulateur, par
/// exemple — l'appelant n'ouvre pas ce sélecteur et affiche « La photo n’a pas pu
/// être récupérée. Réessaie. ».
struct PhotoTxCameraPicker: UIViewControllerRepresentable {
    let onPick: (UIImage) -> Void
    let onCancel: () -> Void
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let controller = UIImagePickerController()
        controller.sourceType = .camera
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
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            guard let image = info[.originalImage] as? UIImage else { onCancel(); return }
            onPick(image)
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { onCancel() }
    }
}
