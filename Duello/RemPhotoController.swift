import Combine
import Foundation

// Porté depuis `src/components/remote-photo-connection/useRemotePhotoSender.ts`
// (lot N, photo à distance). Côté téléphone : liaison automatique par compte
// (réclamation de la session PC du même compte toutes les deux secondes), puis
// surveillance de la session — si le PC la ferme, la liaison repart seule. La
// sélection des photos (appareil photo / photothèque) reste à la vue.

/// Contrôleur d'envoi : liaison au PC et dépôt des photos.
@MainActor
final class RemPhotoController: ObservableObject {
    /// `SENDER_LINK_POLL_MS` : 2 s.
    static let linkPollNanoseconds: UInt64 = 2_000_000_000

    @Published private(set) var connected = false
    @Published private(set) var sending: RemPhotoSendingProgress?
    @Published private(set) var notice = ""
    @Published private(set) var error = ""

    private var accountToken: String?
    private var pairingToken: String?
    private var linkTask: Task<Void, Never>?
    private var linking = false

    var isSending: Bool { sending != nil }

    /// Démarre la boucle de liaison (idempotent tant qu'elle tourne).
    func activate(token: String?) {
        accountToken = token
        guard linkTask == nil else { return }
        linkTask = Task { [weak self] in await self?.runLinkLoop() }
    }

    /// Arrête la boucle et efface les messages, comme `useSenderVisibility`.
    func deactivate() {
        linkTask?.cancel()
        linkTask = nil
        notice = ""
        error = ""
    }

    /// `sendPhoto` : dépose une série de photos, progression incluse.
    func send(assets: [RemPhotoAsset]) async {
        guard let pairingToken, sending == nil, !assets.isEmpty else { return }
        error = ""
        notice = ""
        sending = RemPhotoSendingProgress(current: 0, total: assets.count)
        do {
            for (index, asset) in assets.enumerated() {
                sending = RemPhotoSendingProgress(current: index + 1, total: assets.count)
                _ = try await RemPhotoUploads.upload(
                    token: accountToken,
                    pairingToken: pairingToken,
                    asset: asset
                )
            }
            notice = assets.count == 1
                ? "Photo envoyée au PC."
                : "\(assets.count) photos envoyées au PC."
        } catch {
            self.error = RemPhotoError.userMessage(error)
        }
        sending = nil
    }

    /// Remonte une erreur locale (refus de permission, photo illisible…).
    func report(_ error: Error) {
        self.error = RemPhotoError.userMessage(error)
    }

    private func runLinkLoop() async {
        while !Task.isCancelled {
            await step()
            do { try await Task.sleep(nanoseconds: Self.linkPollNanoseconds) }
            catch { return }
        }
    }

    /// `useSenderLinking` + `useSenderStatusWatch` : réclame, puis surveille.
    private func step() async {
        if linking { return }
        linking = true
        defer { linking = false }
        do {
            if pairingToken == nil {
                let session = try await RemPhotoSessions.claim(token: accountToken)
                if let session {
                    pairingToken = session.pairingToken
                    connected = true
                    notice = "Téléphone connecté au PC."
                } else {
                    pairingToken = nil
                    connected = false
                    notice = ""
                }
            } else {
                let session = try await RemPhotoSessions.current(token: accountToken)
                if session == nil {
                    pairingToken = nil
                    connected = false
                    notice = ""
                }
            }
            error = ""
        } catch {
            self.error = RemPhotoError.userMessage(error)
        }
    }
}
