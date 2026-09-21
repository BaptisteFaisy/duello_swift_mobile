// Shim de vérification Linux — NE FAIT PAS PARTIE DE L'APP.
//
// Déclare le strict minimum d'UIKit utilisé par les fichiers portables de
// Duello. UIKit n'existe pas sous Linux : ce shim ne sert qu'à satisfaire le
// vérificateur de types. Aucune de ces méthodes n'est exécutée.
import Foundation

open class UIImage: NSObject {
    public init?(data: Data) { super.init() }
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
}

open class UIApplication: NSObject {
    public static let shared = UIApplication()
    public var connectedScenes: Set<UIScene> = []

    public func open(
        _ url: URL,
        options: [String: Any],
        completionHandler: ((Bool) -> Void)?
    ) {}
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
