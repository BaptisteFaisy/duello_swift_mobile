// Shim de vérification Linux — NE FAIT PAS PARTIE DE L'APP.
//
// `PhotosUI` n'existe pas sous Linux. Couvre les 4 sélecteurs de photothèque
// (`AnnPhotoLibraryPicker`, `RemPhotoLibraryPicker`, `EvEventPhotoLibraryPicker`,
// `PhotoTranscriptionView`) : `PHPickerViewController`, `PHPickerConfiguration`,
// `PHPickerResult`, `PhotosPickerItem`.
//
// Deux compromis assumés :
//   * `@_exported import Photos` — le code appelle
//     `PHPickerConfiguration(photoLibrary: .shared())` en n'important que
//     `PhotosUI` : `PHPhotoLibrary` doit donc être visible depuis ce module ;
//   * `NSItemProvider` est déclaré ici car Linux Foundation ne le fournit pas
//     (vérifié), alors que le vrai type vient de Foundation. `Transferable`
//     n'est pas déclaré : `loadTransferable` reste générique non contraint.
import Foundation
import UIKit
@_exported import Photos

// MARK: - Item de sélection (PhotosPicker)

public struct PhotosPickerItem: Hashable, Sendable {
    public func loadTransferable<T>(type: T.Type) async throws -> T? { nil }
}

// MARK: - Configuration du sélecteur

public struct PHPickerFilter: Hashable, Sendable {
    public static let images = PHPickerFilter()
    public static let videos = PHPickerFilter()
    public static let livePhotos = PHPickerFilter()
    public static let screenshots = PHPickerFilter()
    public static let any = PHPickerFilter()
}

open class PHPickerConfiguration: NSObject {
    public init(photoLibrary: PHPhotoLibrary) { super.init() }
    public override init() { super.init() }

    public var filter: PHPickerFilter?
    public var selectionLimit: Int = 0
}

// MARK: - Résultat et sélecteur

open class NSItemProvider: NSObject {
    public var suggestedName: String?

    public func canLoadObject(ofClass aClass: Any.Type) -> Bool { false }

    @discardableResult
    public func loadObject(
        ofClass aClass: Any.Type,
        completionHandler: @escaping (Any?, Error?) -> Void
    ) -> Progress {
        Progress(totalUnitCount: 1)
    }
}

public struct PHPickerResult {
    public let itemProvider: NSItemProvider
}

public protocol PHPickerViewControllerDelegate: NSObjectProtocol {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult])
}

open class PHPickerViewController: UIViewController {
    public init(configuration: PHPickerConfiguration) { super.init() }
    public override init() { super.init() }

    public weak var delegate: PHPickerViewControllerDelegate?
}
