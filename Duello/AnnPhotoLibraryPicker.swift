import SwiftUI
import PhotosUI
import UIKit

// MARK: - Sélecteurs de photos

/// Sélecteur de la photothèque, à sélection multiple, sans autorisation
/// préalable (`PHPickerViewController`, iOS 14+). Reprend
/// `ImagePicker.launchImageLibraryAsync({ allowsMultipleSelection: true })`.
struct AnnPhotoLibraryPicker: UIViewControllerRepresentable {
    let selectionLimit: Int
    let onPick: ([AnnCopyPage]) -> Void

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
        private let onPick: ([AnnCopyPage]) -> Void
        private let collector = AnnPageCollector()

        init(onPick: @escaping ([AnnCopyPage]) -> Void) {
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
                          let data = image.jpegData(compressionQuality: AnnCopyPage.jpegQuality)
                    else { return }
                    collector.append(AnnCopyPage(
                        imageBase64: data.base64EncodedString(),
                        mimeType: "image/jpeg"
                    ))
                }
            }
            let onPick = self.onPick
            group.notify(queue: .main) {
                onPick(collector.snapshot())
            }
        }
    }
}

/// Accumulateur de pages alimenté depuis plusieurs fils.
final class AnnPageCollector {
    private let lock = NSLock()
    private var pages: [AnnCopyPage] = []

    func append(_ page: AnnCopyPage) {
        lock.lock()
        pages.append(page)
        lock.unlock()
    }

    func snapshot() -> [AnnCopyPage] {
        lock.lock()
        defer { lock.unlock() }
        return pages
    }
}
