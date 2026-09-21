import Combine
import Foundation

// Porté depuis `src/components/remote-photo-connection/useRemotePhotoReceiver.ts`
// (lot 7-I, photo à distance — côté récepteur). Contrôleur de la session côté
// « propriétaire » : création de la session, interrogation toutes les deux
// secondes, téléchargement des photos reçues, retrait et fermeture.
//
// Dans la source, cette logique ne tourne que sur le web (`Platform.OS === 'web'`) ;
// sur iOS l'application tient le rôle du téléphone (`RemPhotoController`). Le
// contrôleur est fourni pour parité, avec un démarrage explicite (`start()`),
// sans la création automatique propre au web (`useReceiverAutoStart`).

/// `RemotePhotoReceiverController` (branche « propriétaire » de la session).
@MainActor
final class RemPhotoRxReceiver: ObservableObject {
    /// `RECEIVER_POLL_MS` : 2 s.
    static let pollNanoseconds: UInt64 = 2_000_000_000

    @Published private(set) var session: RemPhotoSessionCreated?
    @Published private(set) var status: RemPhotoSessionStatus?
    @Published private(set) var photos: [RemPhotoReceivedPhoto] = []
    @Published private(set) var creating = false
    @Published private(set) var notice = ""
    @Published private(set) var error = ""

    private var accountToken: String?
    private var photoCache: [String: Data] = [:]
    private var pollTask: Task<Void, Never>?
    private var polling = false

    init() {}

    /// Démarre la boucle d'interrogation (idempotent tant qu'elle tourne).
    /// `useReceiverAutoStart` n'est pas repris : la création reste explicite.
    func activate(token: String?) {
        accountToken = token
        guard pollTask == nil else { return }
        pollTask = Task { [weak self] in await self?.runPollLoop() }
    }

    /// Arrête la boucle d'interrogation (équivalent du nettoyage d'effet).
    func deactivate() {
        pollTask?.cancel()
        pollTask = nil
    }

    /// `start` : ouvre une session en attente d'appairage.
    func start() async {
        creating = true
        error = ""
        notice = ""
        defer { creating = false }
        do {
            let next = try await RemPhotoSessions.create(token: accountToken)
            clearPhotos()
            status = nil
            session = next
        } catch {
            self.error = RemPhotoRxUtils.errorMessage(error)
        }
    }

    /// `disconnect` : ferme la session locale puis prévient le serveur.
    func disconnect() async {
        let sessionId = session?.sessionId
        session = nil
        status = nil
        clearPhotos()
        notice = "Connexion fermée."
        guard let sessionId else { return }
        try? await RemPhotoSessions.disconnectOwner(token: accountToken, sessionId: sessionId)
    }

    /// `deletePhoto` : retire la photo du serveur puis de l'affichage.
    func deletePhoto(_ photo: RemPhotoReceivedPhoto) async {
        guard let sessionId = session?.sessionId else { return }
        do {
            try await RemPhotoUploads.remove(
                token: accountToken, sessionId: sessionId, photoId: photo.id
            )
            photoCache[photo.id] = nil
            photos.removeAll { $0.id == photo.id }
            status = status.map { current in
                RemPhotoSessionStatus(
                    sessionId: current.sessionId,
                    createdAt: current.createdAt,
                    connectedAt: current.connectedAt,
                    expiresAt: current.expiresAt,
                    status: current.status,
                    photos: current.photos.filter { $0.id != photo.id }
                )
            }
        } catch {
            self.error = RemPhotoRxUtils.errorMessage(error)
        }
    }

    /// `downloadPhoto` : l'ancre `download` du web devient un fichier temporaire
    /// partageable (Enregistrer dans Photos, Fichiers…) présenté par la vue.
    func shareURL(for photo: RemPhotoReceivedPhoto) -> URL? {
        RemPhotoShareSheet.writeTemporaryFile(photo)
    }

    private func runPollLoop() async {
        while !Task.isCancelled {
            await refresh()
            do { try await Task.sleep(nanoseconds: Self.pollNanoseconds) } catch { return }
        }
    }

    /// `useReceiverRefresh` : état de la session, photos synchronisées. Une
    /// session fermée (`session-not-found`) remet le contrôleur à zéro.
    private func refresh() async {
        guard let sessionId = session?.sessionId, !polling else { return }
        polling = true
        defer { polling = false }
        do {
            let next = try await RemPhotoSessions.fetch(token: accountToken, sessionId: sessionId)
            status = next
            error = ""
            let missing = RemPhotoRxUtils.missingPhotoIds(status: next, cached: Set(photoCache.keys))
            for photoId in missing {
                photoCache[photoId] = try await RemPhotoUploads.photoData(
                    token: accountToken, sessionId: sessionId, photoId: photoId
                )
            }
            for stale in RemPhotoRxUtils.stalePhotoIds(status: next, cached: Set(photoCache.keys)) {
                photoCache[stale] = nil
            }
            photos = RemPhotoRxUtils.receivedPhotos(status: next, cache: photoCache)
        } catch {
            self.error = RemPhotoRxUtils.errorMessage(error)
            if let rem = error as? RemPhotoError, rem.code == "session-not-found" {
                session = nil
                status = nil
                clearPhotos()
                self.error = ""
            }
        }
    }

    /// `clearRemotePhotoUrls` : vide le cache d'octets et la liste affichée.
    private func clearPhotos() {
        photoCache.removeAll()
        photos = []
    }
}
