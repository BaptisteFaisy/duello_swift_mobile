import Combine
import Foundation

// Porté depuis `src/hooks/useRemotePhotoCapturePrompt.ts` et
// `src/components/RemotePhotoCaptureCoordinator.tsx` (lot 7-I, photo à
// distance — côté téléphone récepteur). Le téléphone reçoit une demande de
// photo du web, l'affiche, puis renvoie la photo choisie — ou refuse.
//
// `fetchRemotePhotoCaptureRequest` est interrogé toutes les deux secondes tant
// que l'écran est actif. L'écoute des notifications poussées de la source
// (`useCaptureNotificationEvents`) n'est pas reprise ici — elle relève du lot
// PushNotif — l'interrogation suffit à faire apparaître la demande.

/// `RemotePhotoPickerSource` : source de sélection d'une photo.
enum RemPhotoRxPickerSource: String, Identifiable, CaseIterable {
    case camera
    case library

    var id: String { rawValue }
}

/// `useRemotePhotoCapturePrompt` : demande en attente et réponses possibles.
@MainActor
final class RemPhotoRxCaptureCoordinator: ObservableObject {
    /// `CAPTURE_REQUEST_POLL_MS` : 2 s.
    static let pollNanoseconds: UInt64 = 2_000_000_000

    @Published private(set) var request: RemPhotoCaptureRequest?
    @Published private(set) var error = ""
    @Published private(set) var busy = false
    @Published private(set) var busySource: RemPhotoRxPickerSource?
    /// Source dont le sélecteur doit être présenté par la vue hôte.
    @Published var pickingSource: RemPhotoRxPickerSource?

    private var accountToken: String?
    private var pollTask: Task<Void, Never>?
    private var refreshing = false

    init() {}

    /// `useCapturePolling` (démarrage) : interroge la demande courante.
    func activate(token: String?) {
        accountToken = token
        guard pollTask == nil else { return }
        pollTask = Task { [weak self] in await self?.runPollLoop() }
    }

    /// `useCapturePolling` (arrêt) : coupe l'interrogation quand l'app passe en
    /// arrière-plan (`AppState` de la source → `scenePhase` côté vue hôte).
    func deactivate() {
        pollTask?.cancel()
        pollTask = nil
    }

    /// `onSelectPhoto` : contrôle la permission puis réclame le sélecteur. La
    /// photothèque iOS (`PHPickerViewController`) n'exige aucune autorisation.
    func selectPhoto(source: RemPhotoRxPickerSource) async {
        guard request != nil, !busy else { return }
        busy = true
        busySource = source
        error = ""
        if source == .camera {
            let granted = await RemPhotoCameraAccess.ensure()
            guard granted else {
                error = "Autorise l’appareil photo pour répondre à la demande du web."
                busy = false
                busySource = nil
                return
            }
        }
        pickingSource = source
    }

    /// `uploadRemotePhotoCapture` : envoie la photo choisie puis efface la
    /// demande et relance l'interrogation.
    func submit(asset: RemPhotoAsset, source: RemPhotoRxPickerSource) async {
        guard let request, busy else { return }
        busySource = source
        do {
            _ = try await RemPhotoUploads.uploadCapture(
                token: accountToken, requestId: request.id, asset: asset
            )
            self.request = nil
            busy = false
            busySource = nil
            pickingSource = nil
            await refresh()
        } catch {
            report(error)
        }
    }

    /// Le sélecteur a été fermé sans photo.
    func cancelPick() {
        pickingSource = nil
        busy = false
        busySource = nil
    }

    /// `onDecline` : « Pas maintenant », la demande est close côté serveur.
    func decline() async {
        guard let request, !busy else { return }
        busy = true
        error = ""
        do {
            try await RemPhotoCapture.close(token: accountToken, requestId: request.id)
            self.request = nil
        } catch {
            report(error)
        }
        busy = false
    }

    /// Remonte une erreur locale (permission refusée, sélecteur en échec).
    func report(_ error: Error) {
        self.error = RemPhotoRxUtils.errorMessage(
            error, fallback: "La photo n’a pas pu être envoyée au web."
        )
        busy = false
        busySource = nil
        pickingSource = nil
    }

    private func runPollLoop() async {
        while !Task.isCancelled {
            await refresh()
            do { try await Task.sleep(nanoseconds: Self.pollNanoseconds) } catch { return }
        }
    }

    /// `usePendingCaptureRequest` : demande courante, échec silencieux (comme
    /// le `catch(() => undefined)` de la source).
    private func refresh() async {
        guard !refreshing else { return }
        refreshing = true
        defer { refreshing = false }
        do {
            let next = try await RemPhotoCapture.fetch(token: accountToken, requestId: nil)
            request = next
            if next != nil { error = "" }
        } catch {
            return
        }
    }
}
