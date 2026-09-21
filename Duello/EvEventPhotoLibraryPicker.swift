//
//  EvEventPhotoLibraryPicker.swift
//  Duello
//
//  Sélecteur de la photothèque à sélection multiple, sans autorisation
//  préalable (`PHPickerViewController`, iOS 14+). Reprend
//  `launchImageLibraryAsync({ allowsMultipleSelection: true, selectionLimit: 24 })`
//  du composant Expo : les images choisies sont enregistrées sur disque par
//  `EvEventPhotoStore` et rendues sous forme d'URI de fichier, comme les
//  `photoUris` du brouillon.
//
//  Fichier source Expo porté : `pickPhotos` de
//  `src/components/event/EventPhotoSheet.tsx`.
//
//  Cible : iOS 16.
//
import SwiftUI
import PhotosUI
import UIKit

struct EvEventPhotoLibraryPicker: UIViewControllerRepresentable {
    let selectionLimit: Int
    let onPick: ([String]) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = .images
        configuration.selectionLimit = max(1, selectionLimit)
        let controller = PHPickerViewController(configuration: configuration)
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    /// Rassemble les images choisies, hors du fil principal, puis les rend.
    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        private let onPick: ([String]) -> Void

        init(onPick: @escaping ([String]) -> Void) {
            self.onPick = onPick
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            guard !results.isEmpty else { return }
            let group = DispatchGroup()
            let collector = EvEventPhotoCollector()
            for result in results {
                let provider = result.itemProvider
                guard provider.canLoadObject(ofClass: UIImage.self) else { continue }
                group.enter()
                _ = provider.loadObject(ofClass: UIImage.self) { object, _ in
                    defer { group.leave() }
                    guard let image = object as? UIImage, let uri = EvEventPhotoStore.save(image) else { return }
                    collector.append(uri)
                }
            }
            let onPick = self.onPick
            group.notify(queue: .main) { onPick(collector.snapshot()) }
        }
    }
}

/// Accumulateur d'URI alimenté depuis plusieurs fils.
final class EvEventPhotoCollector {
    private let lock = NSLock()
    private var uris: [String] = []

    func append(_ uri: String) {
        lock.lock()
        uris.append(uri)
        lock.unlock()
    }

    func snapshot() -> [String] {
        lock.lock()
        defer { lock.unlock() }
        return uris
    }
}
