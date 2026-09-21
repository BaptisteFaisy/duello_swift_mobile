import Foundation

// Porté depuis `src/utils/remotePhotoCaptureApi.ts` et
// `src/utils/remotePhotoCapture.ts` (lot N, photo à distance).
// L'ordinateur demande une photo au téléphone appairé et attend sa réponse :
// interrogation de la demande toutes les secondes jusqu'à `completed`,
// `cancelled`, `declined` ou `expired`. La photo reçue est ensuite retirée.

/// Photo capturée depuis le téléphone connecté (remplace `RemotePhotoObjectUrl`).
struct RemPhotoCapturedPhoto {
    let data: Data
}

/// Demande de photo annulée localement (`RemotePhotoCaptureCancelled`).
struct RemPhotoCaptureCancelled: Error {}

/// Demande de capture et attente de la photo (côté ordinateur).
enum RemPhotoCapture {
    /// `CAPTURE_POLL_INTERVAL_MS` : 1 s.
    static let pollNanoseconds: UInt64 = 1_000_000_000

    /// `requestRemotePhotoCapture` : crée une demande pour la session appairée.
    static func request(
        token: String?,
        sessionId: String,
        purpose: RemPhotoCapturePurpose = .exerciseCopy
    ) async throws -> RemPhotoCaptureRequest {
        let body = RemPhotoAPI.jsonBody(["sessionId": sessionId, "purpose": purpose.rawValue])
        let data = try await RemPhotoAPI.request(
            path: RemPhotoAPI.captureRequestPath,
            method: "POST",
            token: token,
            headers: ["Content-Type": "application/json"],
            body: body
        )
        let payload = RemPhotoAPI.dictionary(data)
        if let request = RemPhotoProtocol.parseCaptureRequest(payload["request"]) { return request }
        if payload["request"] is NSNull {
            throw RemPhotoError(
                message: "La demande de photo n’a pas été créée.",
                status: nil,
                code: "missing-remote-photo-capture-request"
            )
        }
        throw RemPhotoError(
            message: "Le serveur a renvoyé une demande de photo illisible.",
            status: nil,
            code: "invalid-remote-photo-capture-request"
        )
    }

    /// `fetchRemotePhotoCaptureRequest` : état d'une demande (ou la courante).
    static func fetch(token: String?, requestId: String?) async throws -> RemPhotoCaptureRequest? {
        let query = requestId.map { [URLQueryItem(name: "id", value: $0)] } ?? []
        let data = try await RemPhotoAPI.request(
            path: RemPhotoAPI.captureRequestPath,
            token: token,
            query: query
        )
        let payload = RemPhotoAPI.dictionary(data)
        if let request = RemPhotoProtocol.parseCaptureRequest(payload["request"]) { return request }
        if payload["request"] is NSNull { return nil }
        throw RemPhotoError(
            message: "Le serveur a renvoyé une demande de photo illisible.",
            status: nil,
            code: "invalid-remote-photo-capture-request"
        )
    }

    /// `closeRemotePhotoCaptureRequest` : annule une demande en cours.
    static func close(token: String?, requestId: String) async throws {
        _ = try await RemPhotoAPI.request(
            path: RemPhotoAPI.captureRequestPath,
            method: "DELETE",
            token: token,
            query: [URLQueryItem(name: "id", value: requestId)]
        )
    }

    /// `capturePhotoFromConnectedPhone` : demande puis attend la photo. Renvoie
    /// `nil` si aucun téléphone appairé n'est connecté.
    static func captureFromConnectedPhone(
        token: String?,
        purpose: RemPhotoCapturePurpose = .exerciseCopy
    ) async throws -> RemPhotoCapturedPhoto? {
        let session = try await RemPhotoSessions.current(token: token)
        guard let session, session.isPaired else { return nil }
        let request = try await self.request(
            token: token,
            sessionId: session.sessionId,
            purpose: purpose
        )
        do {
            return try await waitForPhoto(token: token, sessionId: session.sessionId, initial: request)
        } catch is RemPhotoCaptureCancelled {
            try? await close(token: token, requestId: request.id)
            throw RemPhotoCaptureCancelled()
        } catch is CancellationError {
            try? await close(token: token, requestId: request.id)
            throw CancellationError()
        }
    }

    /// `waitForCapturedPhoto` : boucle d'interrogation puis récupération des
    /// octets ; la photo est retirée du serveur après lecture.
    private static func waitForPhoto(
        token: String?,
        sessionId: String,
        initial: RemPhotoCaptureRequest
    ) async throws -> RemPhotoCapturedPhoto {
        var request = initial
        while request.status == .pending {
            try Task.checkCancellation()
            try await Task.sleep(nanoseconds: pollNanoseconds)
            if let next = try await fetch(token: token, requestId: request.id) { request = next }
        }
        if let error = requestError(request) { throw error }
        guard request.status == .completed, let photoId = request.photoId else {
            throw RemPhotoError(
                message: "Le téléphone n’a pas transmis de photo.",
                status: nil,
                code: "capture-photo-missing"
            )
        }
        let data = try await RemPhotoUploads.photoData(
            token: token,
            sessionId: sessionId,
            photoId: photoId
        )
        try? await RemPhotoUploads.remove(token: token, sessionId: sessionId, photoId: photoId)
        return RemPhotoCapturedPhoto(data: data)
    }

    /// `captureRequestError` : traduit un statut terminal en erreur.
    private static func requestError(_ request: RemPhotoCaptureRequest) -> Error? {
        switch request.status {
        case .cancelled:
            return RemPhotoCaptureCancelled()
        case .declined:
            return RemPhotoError(
                message: "La prise de photo a été refusée sur le téléphone.",
                status: 409,
                code: "capture-request-declined"
            )
        case .expired:
            return RemPhotoError(
                message: "La demande de photo a expiré. Réessaie depuis le web.",
                status: 410,
                code: "capture-request-expired"
            )
        default:
            return nil
        }
    }
}
