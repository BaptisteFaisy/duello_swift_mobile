import Foundation

// Porté depuis `src/utils/remotePhotoUploads.ts` (lot N, photo à distance).
// Envoi et retrait des photos : le téléphone dépose ses clichés dans la session
// du compte (`X-Duello-Pairing-Token`) ou répond à une demande de capture
// (`X-Duello-Capture-Request`) ; l'ordinateur lit et supprime les photos.

/// Envoi, lecture et suppression des photos d'une session.
enum RemPhotoUploads {
    /// `uploadRemotePhoto` : le téléphone pousse une photo appairée.
    static func upload(
        token: String?,
        pairingToken: String,
        asset: RemPhotoAsset
    ) async throws -> RemPhotoMetadata {
        try await uploadAsset(
            token: token,
            path: RemPhotoAPI.photoPath,
            identifier: [RemPhotoAPI.pairingHeader: pairingToken],
            asset: asset
        )
    }

    /// `uploadRemotePhotoCapture` : réponse à une demande de photo ciblée.
    static func uploadCapture(
        token: String?,
        requestId: String,
        asset: RemPhotoAsset
    ) async throws -> RemPhotoMetadata {
        try await uploadAsset(
            token: token,
            path: RemPhotoAPI.capturePhotoPath,
            identifier: [RemPhotoAPI.captureHeader: requestId],
            asset: asset
        )
    }

    /// `fetchRemotePhotoBlob` : octets d'une photo de la session.
    static func photoData(token: String?, sessionId: String, photoId: String) async throws -> Data {
        try await RemPhotoAPI.request(
            path: RemPhotoAPI.photoPath,
            token: token,
            query: [
                URLQueryItem(name: "sessionId", value: sessionId),
                URLQueryItem(name: "photoId", value: photoId),
            ]
        )
    }

    /// `removeRemotePhoto` : suppression définitive côté serveur.
    static func remove(token: String?, sessionId: String, photoId: String) async throws {
        _ = try await RemPhotoAPI.request(
            path: RemPhotoAPI.photoPath,
            method: "DELETE",
            token: token,
            query: [
                URLQueryItem(name: "sessionId", value: sessionId),
                URLQueryItem(name: "photoId", value: photoId),
            ]
        )
    }

    /// `uploadRemotePhotoAsset` : valide les octets, poste, lit la confirmation.
    private static func uploadAsset(
        token: String?,
        path: String,
        identifier: [String: String],
        asset: RemPhotoAsset
    ) async throws -> RemPhotoMetadata {
        let data = try validatedData(asset)
        var headers = identifier
        headers["Content-Type"] = asset.mimeType ?? "image/jpeg"
        headers[RemPhotoAPI.photoNameHeader] = encodeName(
            asset.fileName ?? "photo-duello-\(Int(Date().timeIntervalSince1970 * 1000)).jpg"
        )
        let payload = try await RemPhotoAPI.request(
            path: path,
            method: "POST",
            token: token,
            headers: headers,
            body: data,
            timeout: RemPhotoAPI.uploadTimeout
        )
        if let photo = RemPhotoProtocol.parseMetadata(RemPhotoAPI.dictionary(payload)["photo"]) {
            return photo
        }
        throw RemPhotoError(
            message: "Le serveur n’a pas confirmé la photo.",
            status: nil,
            code: "invalid-remote-photo-upload"
        )
    }

    /// `validatedAssetBlob` : refuse une photo vide ou au-delà de 8 Mio.
    private static func validatedData(_ asset: RemPhotoAsset) throws -> Data {
        let size = asset.data.count
        if size > 0 && size <= RemPhotoProtocol.maxBytes { return asset.data }
        let tooLarge = size > RemPhotoProtocol.maxBytes
        throw RemPhotoError(
            message: tooLarge ? "La photo dépasse la limite de 8 Mio." : "La photo sélectionnée est vide.",
            status: tooLarge ? 413 : 400,
            code: tooLarge ? "photo-too-large" : "empty-photo"
        )
    }

    /// Équivalent local de `encodeURIComponent` pour l'en-tête de nom.
    private static func encodeName(_ name: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_.!~*'()"))
        return name.addingPercentEncoding(withAllowedCharacters: allowed) ?? name
    }
}
