import Foundation

// Porté depuis `src/utils/remotePhotoProtocol.ts` (lot N, photo à distance).
// Logique pure : constantes, validation du jeton d'appairage, lecture
// défensive des charges utiles JSON et formatage des tailles. Aucun accès
// réseau ni état mutable — testable telle quelle.

/// Protocole filaire de la connexion photo à distance.
enum RemPhotoProtocol {
    /// `REMOTE_PHOTO_MAX_BYTES` : 8 Mio.
    static let maxBytes = 8 * 1024 * 1024

    static let purposes: [RemPhotoCapturePurpose] = RemPhotoCapturePurpose.allCases
    static let statuses: [RemPhotoCaptureRequestStatus] = RemPhotoCaptureRequestStatus.allCases

    /// `validPairingToken` : 32 à 128 caractères `[A-Za-z0-9_-]`.
    static func isValidPairingToken(_ value: Any?) -> Bool {
        guard let text = value as? String else { return false }
        return text.range(of: "^[a-zA-Z0-9_-]{32,128}$", options: .regularExpression) != nil
    }

    /// `parseRemotePhotoMetadata`.
    static func parseMetadata(_ value: Any?) -> RemPhotoMetadata? {
        guard let dict = value as? [String: Any],
              let id = dict["id"] as? String,
              let createdAt = number(dict["createdAt"]),
              let fileName = dict["fileName"] as? String,
              let mimeType = dict["mimeType"] as? String,
              let size = number(dict["size"]),
              size > 0, size <= Double(maxBytes)
        else { return nil }
        return RemPhotoMetadata(
            id: id,
            createdAt: createdAt,
            fileName: fileName,
            mimeType: mimeType,
            size: Int(size)
        )
    }

    /// `parseRemotePhotoCaptureRequest` (l'objectif vaut `exercise-copy` par défaut).
    static func parseCaptureRequest(_ value: Any?) -> RemPhotoCaptureRequest? {
        guard let dict = value as? [String: Any],
              let id = dict["id"] as? String,
              let createdAt = number(dict["createdAt"]),
              let expiresAt = number(dict["expiresAt"])
        else { return nil }
        let purpose: RemPhotoCapturePurpose
        if dict["purpose"] == nil {
            purpose = .exerciseCopy
        } else if let raw = dict["purpose"] as? String, let parsed = RemPhotoCapturePurpose(rawValue: raw) {
            purpose = parsed
        } else {
            return nil
        }
        guard let statusRaw = dict["status"] as? String,
              let status = RemPhotoCaptureRequestStatus(rawValue: statusRaw)
        else { return nil }
        guard let photoId = dict["photoId"] else { return nil }
        if !(photoId is NSNull), !(photoId is String) { return nil }
        return RemPhotoCaptureRequest(
            id: id,
            createdAt: createdAt,
            expiresAt: expiresAt,
            purpose: purpose,
            status: status,
            photoId: photoId as? String
        )
    }

    /// `parseRemotePhotoSessionCreated` (statut imposé : `waiting`).
    static func parseSessionCreated(_ value: Any?) -> RemPhotoSessionCreated? {
        guard let dict = value as? [String: Any],
              let sessionId = dict["sessionId"] as? String,
              let pairingToken = dict["pairingToken"] as? String,
              isValidPairingToken(pairingToken),
              let createdAt = number(dict["createdAt"]),
              let expiresAt = number(dict["expiresAt"]),
              dict["status"] as? String == "waiting"
        else { return nil }
        return RemPhotoSessionCreated(
            sessionId: sessionId,
            pairingToken: pairingToken,
            createdAt: createdAt,
            expiresAt: expiresAt
        )
    }

    /// `parseRemotePhotoClaimedSession` (statut imposé : `paired`).
    static func parseClaimedSession(_ value: Any?) -> RemPhotoClaimedSession? {
        guard let dict = value as? [String: Any],
              let sessionId = dict["sessionId"] as? String,
              let pairingToken = dict["pairingToken"] as? String,
              isValidPairingToken(pairingToken),
              let connectedAt = number(dict["connectedAt"]),
              let expiresAt = number(dict["expiresAt"]),
              dict["status"] as? String == "paired"
        else { return nil }
        return RemPhotoClaimedSession(
            sessionId: sessionId,
            pairingToken: pairingToken,
            connectedAt: connectedAt,
            expiresAt: expiresAt
        )
    }

    /// `parseRemotePhotoSessionStatus` (photos toutes valides, sinon `nil`).
    static func parseSessionStatus(_ value: Any?) -> RemPhotoSessionStatus? {
        guard let dict = value as? [String: Any],
              let sessionId = dict["sessionId"] as? String,
              let createdAt = number(dict["createdAt"]),
              let expiresAt = number(dict["expiresAt"]),
              let statusRaw = dict["status"] as? String,
              let status = RemPhotoSessionState(rawValue: statusRaw),
              let rawPhotos = dict["photos"] as? [Any]
        else { return nil }
        guard let connectedAtValue = dict["connectedAt"] else { return nil }
        if !(connectedAtValue is NSNull), number(connectedAtValue) == nil {
            return nil
        }
        var photos: [RemPhotoMetadata] = []
        for raw in rawPhotos {
            guard let photo = parseMetadata(raw) else { return nil }
            photos.append(photo)
        }
        return RemPhotoSessionStatus(
            sessionId: sessionId,
            createdAt: createdAt,
            connectedAt: number(dict["connectedAt"]),
            expiresAt: expiresAt,
            status: status,
            photos: photos
        )
    }

    /// `formatRemotePhotoSize` : « 812 Ko » ou « 3.4 Mo ».
    static func formatSize(_ bytes: Int) -> String {
        if bytes < 1024 * 1024 {
            return "\(max(1, Int((Double(bytes) / 1024).rounded()))) Ko"
        }
        return String(format: "%.1f Mo", Double(bytes) / (1024 * 1024))
    }

    private static func number(_ value: Any?) -> Double? {
        (value as? NSNumber)?.doubleValue
    }
}
