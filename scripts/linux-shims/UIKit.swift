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
    public var safeAreaInsets: UIEdgeInsets { UIEdgeInsets() }
}

open class UIWindowScene: UIScene {
    public var windows: [UIWindow] = []
    /// iOS 15+ : fenêtre principale de la scène.
    public var keyWindow: UIWindow?
}

/// `UIScreen.main.bounds` / `.scale` (iOS 16). Shim no-op.
public enum UIScreen {
    public static let main = Screen()

    public struct Screen {
        public var bounds: CGRect { .zero }
        public var scale: CGFloat { 2 }
    }
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

    /// Forme async du SDK (Xcode 26 la préfère pour `open(url)` en contexte
    /// async — constaté par le build macOS du 2026-09-22). Sans elle, le
    /// contrôle Linux déclare l'appel synchrone et masque l'`await` manquant.
    public func open(_ url: URL, options: [String: Any] = [:]) async -> Bool { false }

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
    public var bounds: CGRect = .zero
    public var isOpaque: Bool = true
    public var backgroundColor: UIColor?
    public var subviews: [UIView] = []
    public var translatesAutoresizingMaskIntoConstraints: Bool = true
    public var safeAreaInsets: UIEdgeInsets { UIEdgeInsets() }

    public func addSubview(_ view: UIView) {}
    public func removeFromSuperview() {}

    // Ancres Auto Layout (surface utilisée par `CoursePdfView`).
    public var trailingAnchor: NSLayoutXAxisAnchor { NSLayoutXAxisAnchor() }
    public var leadingAnchor: NSLayoutXAxisAnchor { NSLayoutXAxisAnchor() }
    public var centerYAnchor: NSLayoutYAxisAnchor { NSLayoutYAxisAnchor() }
    public var centerXAnchor: NSLayoutXAxisAnchor { NSLayoutXAxisAnchor() }
    public var topAnchor: NSLayoutYAxisAnchor { NSLayoutYAxisAnchor() }
    public var bottomAnchor: NSLayoutYAxisAnchor { NSLayoutYAxisAnchor() }
    public var widthAnchor: NSLayoutDimension { NSLayoutDimension() }
    public var heightAnchor: NSLayoutDimension { NSLayoutDimension() }
}

open class UIScrollView: UIView {
    public enum ContentInsetAdjustmentBehavior: Int {
        case automatic, scrollableAxes, never, always
    }

    public var contentInsetAdjustmentBehavior: ContentInsetAdjustmentBehavior = .automatic
    public var contentSize: CGSize = .zero
    public var contentOffset: CGPoint = .zero

    public func setContentOffset(_ contentOffset: CGPoint, animated: Bool) {}
}

/// `CGImage` : seule la surface utilisée par `ImageCache` (coût mémoire d'un
/// bitmap décodé). CoreGraphics n'existe pas sous Linux.
open class CGImage: NSObject {
    public var bytesPerRow: Int = 0
    public var height: Int = 0
    public var width: Int = 0

    /// Rognage dans l'espace pixel (`RemPhotoLibraryPicker.squareCropped`).
    public func cropping(to rect: CGRect) -> CGImage? { nil }
}

/// `UIImage` : compléments utilisés par `PhotoPickService` (recadrage carré).
extension UIImage {
    public var size: CGSize { CGSize(width: 0, height: 0) }
    public var scale: CGFloat { 1 }
    public var imageOrientation: Orientation { .up }
    public func draw(in rect: CGRect) {}
    /// Bitmap décodé (`UIImage.cgImage`), lu par `ImageCache.cacheCost`.
    public var cgImage: CGImage? { nil }

    /// Orientation d'une image (`UIImage.Orientation`).
    public enum Orientation: Int, Sendable {
        case up = 0
        case down = 1
        case left = 2
        case right = 3
        case upMirrored = 4
        case downMirrored = 5
        case leftMirrored = 6
        case rightMirrored = 7
    }

    /// Recadrage carré : reconstruction depuis un bitmap (`CGImage`).
    public convenience init(cgImage: CGImage, scale: CGFloat, orientation: Orientation) {
        self.init()
    }
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

// MARK: - Couleurs et Auto Layout
//
// Surface ajoutée pour `CoursePdfView` (repère rouge posé par contraintes) et
// `RemPhotoLibraryPicker` : `UIColor`, ancres Auto Layout, `NSLayoutConstraint`.

/// Insets de zone sûre (`UIWindow.safeAreaInsets`, `UIView.safeAreaInsets`).
/// Absent de Foundation sous Linux : déclaré ici.
public struct UIEdgeInsets: Sendable {
    public var top: CGFloat
    public var left: CGFloat
    public var bottom: CGFloat
    public var right: CGFloat

    public init(top: CGFloat = 0, left: CGFloat = 0, bottom: CGFloat = 0, right: CGFloat = 0) {
        self.top = top
        self.left = left
        self.bottom = bottom
        self.right = right
    }

    public static let zero = UIEdgeInsets()
}

open class UIColor: NSObject {
    public init(red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) { super.init() }
    public init(white: CGFloat, alpha: CGFloat) { super.init() }

    public static let black = UIColor(white: 0, alpha: 1)
    public static let white = UIColor(white: 1, alpha: 1)
    public static let clear = UIColor(white: 0, alpha: 0)
    public static let red = UIColor(red: 1, green: 0, blue: 0, alpha: 1)
}

open class NSLayoutAnchor<AnchorType: AnyObject>: NSObject {
    public func constraint(equalTo anchor: NSLayoutAnchor<AnchorType>) -> NSLayoutConstraint {
        NSLayoutConstraint()
    }

    public func constraint(equalTo anchor: NSLayoutAnchor<AnchorType>, constant c: CGFloat) -> NSLayoutConstraint {
        NSLayoutConstraint()
    }
}

open class NSLayoutXAxisAnchor: NSLayoutAnchor<NSLayoutXAxisAnchor> {}
open class NSLayoutYAxisAnchor: NSLayoutAnchor<NSLayoutYAxisAnchor> {}

open class NSLayoutDimension: NSLayoutAnchor<NSLayoutDimension> {
    public func constraint(equalToConstant c: CGFloat) -> NSLayoutConstraint { NSLayoutConstraint() }
}

open class NSLayoutConstraint: NSObject {
    public static func activate(_ constraints: [NSLayoutConstraint]) {}
    public static func deactivate(_ constraints: [NSLayoutConstraint]) {}
}

// MARK: - Définition de l'application (`PushNotifAppDelegate`)

public protocol UIApplicationDelegate: NSObjectProtocol {}

extension UIApplication {
    public enum State: Int, Sendable {
        case active = 0
        case inactive = 1
        case background = 2
    }

    public var applicationState: State { .active }

    /// Clés des options de lancement (`UIApplication.LaunchOptionsKey`).
    public struct LaunchOptionsKey: Hashable, RawRepresentable, Sendable {
        public let rawValue: String
        public init(rawValue: String) { self.rawValue = rawValue }

        public static let remoteNotification = LaunchOptionsKey(rawValue: "UIApplicationLaunchOptionsRemoteNotificationKey")
        public static let localNotification = LaunchOptionsKey(rawValue: "UIApplicationLaunchOptionsLocalNotificationKey")
        public static let url = LaunchOptionsKey(rawValue: "UIApplicationLaunchOptionsURLKey")
    }
}

// MARK: - Observation de valeurs (KVO)
//
// `NSKeyValueObservation` (et ses compagnons) appartient à Foundation sur
// Apple mais est ABSENT de Foundation sous Linux (vérifié sur Swift 6.1.2) :
// il est donc déclaré ici, dans le shim UIKit importé par `CoursePdfView`.

public struct NSKeyValueObservingOptions: OptionSet, Sendable {
    public let rawValue: UInt
    public init(rawValue: UInt) { self.rawValue = rawValue }

    public static let new = NSKeyValueObservingOptions(rawValue: 1 << 0)
    public static let old = NSKeyValueObservingOptions(rawValue: 1 << 1)
    public static let initial = NSKeyValueObservingOptions(rawValue: 1 << 2)
    public static let prior = NSKeyValueObservingOptions(rawValue: 1 << 3)
}

public struct NSKeyValueObservedChange<Value> {
    public let newValue: Value?
    public let oldValue: Value?
}

open class NSKeyValueObservation: NSObject {
    public func invalidate() {}
}

extension UIScrollView {
    public func observe<Value>(
        _ keyPath: KeyPath<UIScrollView, Value>,
        options: NSKeyValueObservingOptions = [],
        changeHandler: @escaping (UIScrollView, NSKeyValueObservedChange<Value>) -> Void
    ) -> NSKeyValueObservation { NSKeyValueObservation() }
}
