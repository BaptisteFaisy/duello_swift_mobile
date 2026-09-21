import Foundation

// Porté depuis `src/components/remote-photo-connection/remotePhotoConnectionUtils.ts`
// (lot 7-I, photo à distance — côté récepteur). Logique pure : message
// d'erreur, formatage de taille, repérage des photos à charger et assemblage
// des photos reçues. L'équivalent iOS des `objectUrl` du navigateur est un
// cache `[photoId: Data]` : les octets téléchargés remplacent les URL d'objet,
// qui n'existent pas hors du web.

/// `remotePhotoConnectionUtils`.
enum RemPhotoRxUtils {
    /// `remotePhotoErrorMessage` : message lisible, jamais vide. Le repli
    /// `fallback` couvre la variante de `useRemotePhotoCapturePrompt` (message
    /// propre à l'envoi d'une photo).
    static func errorMessage(
        _ error: Error,
        fallback: String = "La connexion PC est momentanément indisponible."
    ) -> String {
        if let rem = error as? RemPhotoError {
            let trimmed = rem.message.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return trimmed }
        }
        if let localized = (error as? LocalizedError)?.errorDescription {
            let trimmed = localized.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return trimmed }
        }
        return fallback
    }

    /// `formatRemotePhotoSize` : « 812 Ko » ou « 3.4 Mo ».
    static func formatSize(_ bytes: Int) -> String {
        RemPhotoProtocol.formatSize(bytes)
    }

    /// `loadMissingPhotoUrls` : identifiants sans octets en cache, dans l'ordre
    /// de la session (l'ordre d'affichage suit celui du serveur).
    static func missingPhotoIds(
        status: RemPhotoSessionStatus,
        cached: Set<String>
    ) -> [String] {
        status.photos.map(\.id).filter { !cached.contains($0) }
    }

    /// `removeStalePhotoUrls` : identifiants en cache absents de l'état courant.
    static func stalePhotoIds(
        status: RemPhotoSessionStatus,
        cached: Set<String>
    ) -> [String] {
        let live = Set(status.photos.map(\.id))
        return cached.subtracting(live).sorted()
    }

    /// `syncRemotePhotoUrls` (assemblage) : photos affichables depuis le cache.
    /// Une photo sans octets encore chargés est simplement omise, comme le web
    /// omet une entrée dépourvue d'`objectUrl`.
    static func receivedPhotos(
        status: RemPhotoSessionStatus,
        cache: [String: Data]
    ) -> [RemPhotoReceivedPhoto] {
        status.photos.compactMap { photo in
            cache[photo.id].map { RemPhotoReceivedPhoto(metadata: photo, data: $0) }
        }
    }
}
