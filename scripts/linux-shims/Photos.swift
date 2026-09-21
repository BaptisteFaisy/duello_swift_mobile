// Shim de vérification Linux — NE FAIT PAS PARTIE DE L'APP.
//
// `Photos` n'existe pas sous Linux. Un seul appel dans Duello :
// `PHPhotoLibrary.authorizationStatus(for: .readWrite)`
// (`PhotoTranscriptionView.swift`). `PhotosUI.swift` réexporte ce module,
// comme le vrai `PhotosUI` rend `PHPhotoLibrary` visible à ses utilisateurs.
import Foundation

public enum PHAccessLevel: Int, Sendable {
    case addOnly = 1
    case readWrite = 2
}

public enum PHAuthorizationStatus: Int, Sendable {
    case notDetermined = 0
    case restricted = 1
    case denied = 2
    case authorized = 3
    case limited = 4
}

open class PHPhotoLibrary: NSObject {
    public static func shared() -> PHPhotoLibrary { PHPhotoLibrary() }

    public class func authorizationStatus(for accessLevel: PHAccessLevel) -> PHAuthorizationStatus {
        .notDetermined
    }
}
