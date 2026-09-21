// Shim de vérification Linux — NE FAIT PAS PARTIE DE L'APP.
//
// Déclare le strict minimum d'UIKit utilisé par les fichiers portables de
// Duello. UIKit n'existe pas sous Linux : ce shim ne sert qu'à satisfaire le
// vérificateur de types. Aucune de ces méthodes n'est exécutée.
import Foundation

open class UIImage: NSObject {
    public init?(data: Data) { super.init() }
    public init?(named: String) { super.init() }
    public init?(contentsOfFile: String) { super.init() }
    public override init() { super.init() }
    public func jpegData(compressionQuality: CGFloat) -> Data? { nil }
}

open class UIViewController: NSObject {
    public var presentedViewController: UIViewController?
}

open class UIScene: NSObject {}

open class UIWindow: NSObject {
    public var isKeyWindow: Bool = true
    public var rootViewController: UIViewController?
}

open class UIWindowScene: UIScene {
    public var windows: [UIWindow] = []
    /// iOS 15+ : fenêtre principale de la scène.
    public var keyWindow: UIWindow?
}

open class UIDevice: NSObject {
    public static let current = UIDevice()
    public var identifierForVendor: UUID?
    public var systemVersion: String = "16.0"
    public var name: String = "iPhone"
}

open class UIApplication: NSObject {
    public static let shared = UIApplication()
    public var connectedScenes: Set<UIScene> = []

    /// `options` et `completionHandler` ont une valeur par défaut dans le SDK :
    /// Duello appelle `open(_:)`, `open(_:options:)` et la forme complète.
    public func open(
        _ url: URL,
        options: [String: Any] = [:],
        completionHandler: ((Bool) -> Void)? = nil
    ) {}

    /// Cible de réglages de l'app (`UIApplication.openSettingsURLString`).
    public static let openSettingsURLString = "app-settings:"
}

open class UIPasteboard: NSObject {
    public static let general = UIPasteboard()
    public var string: String?
}

/// `UIAccessibility.Notification` : seul `.announcement` est utilisé ici.
public enum UIAccessibilityNotification {
    case announcement
}

open class UIAccessibility: NSObject {
    public static func post(notification: UIAccessibilityNotification, argument: Any?) {}
}

// MARK: - Surface complémentaire — shims secondaires (AJOUT ADDITIF)
//
// Ajouté pour que les fichiers qui n'importent que UIKit plus un framework
// secondaire (`AVFoundation`, `UserNotifications`, `AuthenticationServices`,
// `MessageUI`, `PhotosUI`, `WebKit`, `PDFKit`) passent le contrôle de types :
// vues représentables, sélecteur d'image, rendu d'image, enregistrement APNs.
// Aucune de ces méthodes n'est exécutée.

open class UIView: NSObject {
    public var frame: CGRect = .zero
    public var isOpaque: Bool = true
}

open class UIScrollView: UIView {
    public enum ContentInsetAdjustmentBehavior: Int {
        case automatic, scrollableAxes, never, always
    }

    public var contentInsetAdjustmentBehavior: ContentInsetAdjustmentBehavior = .automatic
}

/// `UIImage` : compléments utilisés par `PhotoPickService` (recadrage carré).
extension UIImage {
    public var size: CGSize { CGSize(width: 0, height: 0) }
    public func draw(in rect: CGRect) {}
}

/// `UIViewController.dismiss(animated:)` : hérité du vrai UIKit, absent d'ici.
extension UIViewController {
    public func dismiss(animated flag: Bool) {}
}

extension UIApplication {
    public func registerForRemoteNotifications() {}
    public func unregisterForRemoteNotifications() {}
}

extension UIWindow {
    public var keyWindow: Bool { false }
}

// MARK: - Sélecteur d'image

public protocol UINavigationControllerDelegate: NSObjectProtocol {}

public protocol UIImagePickerControllerDelegate: NSObjectProtocol {
    func imagePickerController(
        _ picker: UIImagePickerController,
        didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
    )
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController)
}

open class UIActivityViewController: UIViewController {
    public nonisolated init(activityItems: [Any], applicationActivities: [UIActivity]?) { super.init() }
}

/// Classe de base des activités partagées (`UIActivity`).
open class UIActivity: NSObject {}

open class UIImagePickerController: UIViewController {
    public enum CameraDevice: Int { case rear, front }
    public var allowsEditing: Bool = false
    public var cameraDevice: CameraDevice = .rear
    public enum SourceType: Int {
        case photoLibrary, camera, savedPhotosAlbum
    }

    public struct InfoKey: Hashable, RawRepresentable, Sendable {
        public let rawValue: String
        public init(rawValue: String) { self.rawValue = rawValue }
        public static let originalImage = InfoKey(rawValue: "UIImagePickerControllerOriginalImage")
        public static let editedImage = InfoKey(rawValue: "UIImagePickerControllerEditedImage")
    }

    public var sourceType: SourceType = .photoLibrary
    public var delegate: (UIImagePickerControllerDelegate & UINavigationControllerDelegate)?

    public class func isSourceTypeAvailable(_ sourceType: SourceType) -> Bool { false }
}

// MARK: - Rendu d'image

open class UIGraphicsImageRendererContext: NSObject {}

open class UIGraphicsImageRendererFormat: NSObject {
    public var scale: CGFloat = 1
    public var opaque: Bool = false

    public class func `default`() -> UIGraphicsImageRendererFormat { UIGraphicsImageRendererFormat() }
}

open class UIGraphicsImageRenderer: NSObject {
    public init(size: CGSize, format: UIGraphicsImageRendererFormat) {
        super.init()
    }

    public func image(actions: (UIGraphicsImageRendererContext) -> Void) -> UIImage {
        UIImage()
    }
}
