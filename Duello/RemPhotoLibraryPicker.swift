import PhotosUI
import SwiftUI
import UIKit

// Porté depuis `src/components/remote-photo-connection/useRemotePhotoSender.ts`
// (branche photothèque de `pickRemotePhotos`, lot N, photo à distance) et
// `src/hooks/useRemotePhotoCapturePrompt.ts` (branche photothèque de
// `pickRequestedPhoto`). `PHPickerViewController` (iOS 14+) : sélection multiple
// d'images sans autorisation préalable, jusqu'à `selectionLimit` clichés
// convertis en JPEG, dans l'ordre choisi.
//
// `quality` et `cropSquare` reproduisent `ImagePickerOptions` : la demande de
// photo du web (`useRemotePhotoCapturePrompt.ts:110-116`) emploie `quality: 0.82`
// et, pour une photo de profil, `allowsEditing` + `aspect [1,1]` — `PHPicker` ne
// propose pas ce recadrage, l'image est donc rognée en carré centré avant envoi.

/// Sélecteur de la photothèque, à sélection multiple.
struct RemPhotoLibraryPicker: UIViewControllerRepresentable {
    var selectionLimit: Int
    /// Recadrage carré centré 1:1 (`allowsEditing` + `aspect [1,1]` de la source).
    var cropSquare: Bool = false
    /// Qualité JPEG (`quality`). Défaut de l'envoi distant : 0.8.
    var quality: CGFloat = 0.8
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

    func makeCoordinator() -> Coordinator {
        Coordinator(cropSquare: cropSquare, quality: quality, onPick: onPick)
    }

    /// Rassemble les images choisies, hors du fil principal.
    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        private let cropSquare: Bool
        private let quality: CGFloat
        private let onPick: ([RemPhotoAsset]) -> Void
        private let collector = RemPhotoAssetCollector()

        init(cropSquare: Bool, quality: CGFloat, onPick: @escaping ([RemPhotoAsset]) -> Void) {
            self.cropSquare = cropSquare
            self.quality = quality
            self.onPick = onPick
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            guard !results.isEmpty else { return }
            let group = DispatchGroup()
            let collector = self.collector
            let cropSquare = self.cropSquare
            let quality = self.quality
            for result in results {
                let provider = result.itemProvider
                guard provider.canLoadObject(ofClass: UIImage.self) else { continue }
                group.enter()
                _ = provider.loadObject(ofClass: UIImage.self) { object, _ in
                    defer { group.leave() }
                    guard let image = object as? UIImage else { return }
                    let final = cropSquare ? Coordinator.squareCropped(image) : image
                    guard let data = final.jpegData(compressionQuality: quality) else { return }
                    let name = provider.suggestedName.map { "\($0).jpg" }
                    collector.append(RemPhotoAsset(data: data, fileName: name, mimeType: "image/jpeg"))
                }
            }
            let onPick = self.onPick
            group.notify(queue: .main) {
                onPick(collector.snapshot())
            }
        }

        /// Rognage carré centré dans l'espace pixel de l'image (`aspect [1,1]`).
        static func squareCropped(_ image: UIImage) -> UIImage {
            guard let cg = image.cgImage else { return image }
            let width = CGFloat(cg.width)
            let height = CGFloat(cg.height)
            let side = min(width, height)
            guard side > 0 else { return image }
            let rect = CGRect(x: (width - side) / 2, y: (height - side) / 2, width: side, height: side)
            guard let cropped = cg.cropping(to: rect) else { return image }
            return UIImage(cgImage: cropped, scale: image.scale, orientation: image.imageOrientation)
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
