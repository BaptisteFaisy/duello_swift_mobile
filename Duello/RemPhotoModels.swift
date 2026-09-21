import Foundation

// Porté depuis l'app Expo (photo à distance, lot N) :
//   src/utils/remotePhotoProtocol.ts        (types + constantes)
//   src/utils/remotePhotoApiClient.ts       (RemotePhotoAsset, RemotePhotoApiError)
//   src/utils/remotePhotoUploads.ts         (validation de taille)
//   src/components/remote-photo-connection/remotePhotoConnectionTypes.ts
// Seuls les types sont déclarés ici ; la logique pure vit dans
// `RemPhotoProtocol`, le réseau dans `RemPhotoAPI` / `RemPhotoSessions` /
// `RemPhotoUploads` / `RemPhotoCapture`.

/// Objectif d'une demande de photo à distance (`RemotePhotoCapturePurpose`).
enum RemPhotoCapturePurpose: String, Codable, CaseIterable {
    case exerciseCopy = "exercise-copy"
    case profilePhoto = "profile-photo"
}

/// État d'une demande de photo (`RemotePhotoCaptureRequestStatus`).
enum RemPhotoCaptureRequestStatus: String, Codable, CaseIterable {
    case pending
    case completed
    case cancelled
    case declined
    case expired
}

/// État d'une session de connexion (`'waiting' | 'paired'`).
enum RemPhotoSessionState: String, Codable {
    case waiting
    case paired
}

/// Métadonnées d'une photo reçue (`RemotePhotoMetadata`).
struct RemPhotoMetadata: Identifiable, Equatable {
    let id: String
    let createdAt: Double
    let fileName: String
    let mimeType: String
    let size: Int

    var sizeLabel: String { RemPhotoProtocol.formatSize(size) }
}

/// Session créée côté ordinateur (`RemotePhotoSessionCreated`).
struct RemPhotoSessionCreated: Equatable {
    let sessionId: String
    let pairingToken: String
    let createdAt: Double
    let expiresAt: Double
}

/// État courant d'une session (`RemotePhotoSessionStatus`).
struct RemPhotoSessionStatus: Equatable {
    let sessionId: String
    let createdAt: Double
    let connectedAt: Double?
    let expiresAt: Double
    let status: RemPhotoSessionState
    let photos: [RemPhotoMetadata]

    var isPaired: Bool { status == .paired }
}

/// Session réclamée par le téléphone (`RemotePhotoClaimedSession`).
struct RemPhotoClaimedSession: Equatable {
    let sessionId: String
    let pairingToken: String
    let connectedAt: Double
    let expiresAt: Double
}

/// Demande de photo (`RemotePhotoCaptureRequest`).
struct RemPhotoCaptureRequest: Identifiable, Equatable {
    let id: String
    let createdAt: Double
    let expiresAt: Double
    let purpose: RemPhotoCapturePurpose
    let status: RemPhotoCaptureRequestStatus
    let photoId: String?
}

/// Photo reçue côté ordinateur, prête à afficher (`ReceivedPhoto`).
struct RemPhotoReceivedPhoto: Identifiable, Equatable {
    let metadata: RemPhotoMetadata
    let data: Data

    var id: String { metadata.id }
    var fileName: String { metadata.fileName }
    var sizeLabel: String { metadata.sizeLabel }
}

/// Photo prête à envoyer : remplace `RemotePhotoAsset` (uri/file/Blob) par des
/// octets déjà chargés.
struct RemPhotoAsset {
    let data: Data
    let fileName: String?
    let mimeType: String?
}

/// Progression d'envoi (`SendingProgress`).
struct RemPhotoSendingProgress: Equatable {
    let current: Int
    let total: Int
}

/// Erreur réseau du protocole photo à distance (`RemotePhotoApiError`).
struct RemPhotoError: LocalizedError, Equatable {
    let message: String
    let status: Int?
    let code: String?

    var errorDescription: String? { message }

    /// `remotePhotoErrorMessage` : message lisible, jamais vide.
    static func userMessage(_ error: Error) -> String {
        if let rem = error as? RemPhotoError,
           !rem.message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return rem.message
        }
        if let localized = (error as? LocalizedError)?.errorDescription,
           !localized.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return localized
        }
        return "La connexion PC est momentanément indisponible."
    }
}
