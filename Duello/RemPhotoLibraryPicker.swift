import PhotosUI
import SwiftUI
import UIKit

// Porté depuis `src/components/remote-photo-connection/useRemotePhotoSender.ts`
// (branche photothèque de `pickRemotePhotos`, lot N, photo à distance).
// `PHPickerViewController` (iOS 14+) : sélection multiple d'images sans
// autorisation préalable, jusqu'à `selectionLimit` clichés convertis en JPEG
// (qualité 0.8), dans l'ordre choisi.

/// Sélecteur de la photothèque, à sélection multiple.
struct RemPhotoLibraryPicker: UIViewControllerRepresentable {
    let selectionLimit: Int
    let onPick: ([RemPhotoAsset]) -> Void

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

    /// Rassemble les images choisies, hors du fil principal.
    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        private let onPick: ([RemPhotoAsset]) -> Void
        private let collector = RemPhotoAssetCollector()

        init(onPick: @escaping ([RemPhotoAsset]) -> Void) {
            self.onPick = onPick
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            guard !results.isEmpty else { return }
            let group = DispatchGroup()
            let collector = self.collector
            for result in results {
                let provider = result.itemProvider
                guard provider.canLoadObject(ofClass: UIImage.self) else { continue }
                group.enter()
                _ = provider.loadObject(ofClass: UIImage.self) { object, _ in
                    defer { group.leave() }
                    guard let image = object as? UIImage,
                          let data = image.jpegData(compressionQuality: 0.8)
                    else { return }
                    let name = provider.suggestedName.map { "\($0).jpg" }
                    collector.append(RemPhotoAsset(data: data, fileName: name, mimeType: "image/jpeg"))
                }
            }
            let onPick = self.onPick
            group.notify(queue: .main) {
                onPick(collector.snapshot())
            }
        }
    }
}

/// Accumulateur d'assets alimenté depuis plusieurs fils.
final class RemPhotoAssetCollector {
    private let lock = NSLock()
    private var assets: [RemPhotoAsset] = []

    func append(_ asset: RemPhotoAsset) {
        lock.lock()
        assets.append(asset)
        lock.unlock()
    }

    func snapshot() -> [RemPhotoAsset] {
        lock.lock()
        defer { lock.unlock() }
        return assets
    }
}
