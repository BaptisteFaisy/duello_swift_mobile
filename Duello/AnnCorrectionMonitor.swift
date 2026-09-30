import SwiftUI

// MARK: - Moniteur de correction

/// Maintient les corrections actives à jour même lorsque l'élève quitte
/// l'annale (`AnnaleCorrectionMonitor.tsx`).
///
/// Le moniteur relit toutes les 15 s les corrections encore actives et publie
/// les nouvelles fiches prêtes. Côté Expo, la fin d'une correction déclenche en
/// plus une notification « correction prête » (`withCorrectionReadyNotification`
/// + `saveNotifications`, `utils/notifications.ts:73-86`) et une ligne
/// d'historique de note. Ici les fiches prêtes sont exposées dans
/// `readyNotices`, que la liste affiche en bandeau, **et** la notification est
/// ajoutée au magasin partagé (`AcctNotificationsStore.addCorrectionReady`,
/// `AnnaleCorrectionMonitor.tsx:85-94`) — la ligne d'historique de note n'est
/// pas portée (voir `AnnCopyCorrection…`).
final class AnnCorrectionMonitor: ObservableObject {
    /// Sonde **globale** partagée : une seule boucle de fond pour toute l'app,
    /// montée à la racine (`App.tsx:2650`), au lieu d'une instance par vue
    /// (écart 06#9). L'`init` reste accessible : les vues rattachées
    /// (`MainTabView`, `TrainingCatalogView+Entry`) continuent de l'appeler et
    /// seront rabattues sur `shared` par leur propre lot.
    static let shared = AnnCorrectionMonitor()

    /// Cadence de re-synchronisation de fond (`AnnaleCorrectionMonitor.tsx`).
    static let backgroundInterval: TimeInterval = 15

    @Published private(set) var jobs: [AnnCopyJob] = []
    /// Corrections terminées depuis le dernier accusé de réception.
    @Published private(set) var readyNotices: [AnnCopyJob] = []

    private var token: String?
    private var pollingTask: Task<Void, Never>?

    /// Jeton de session utilisé par le relais.
    func configure(token: String?) {
        self.token = token
    }

    /// Recharge les fiches conservées localement.
    func load() {
        jobs = AnnCopyStore.load()
    }

    /// Corrections d'une annale donnée, la plus récente d'abord.
    func jobs(for itemId: String) -> [AnnCopyJob] {
        jobs.filter { $0.itemId == itemId }.sorted { $0.updatedAt > $1.updatedAt }
    }

    /// Enregistre une fiche et signale celles qui viennent d'aboutir.
    func upsert(_ job: AnnCopyJob) {
        let previous = jobs.first { $0.jobId == job.jobId }
        jobs.removeAll { $0.jobId == job.jobId }
        jobs.insert(job, at: 0)
        AnnCopyStore.save(jobs)
        if job.status == .ready, previous?.status != .ready {
            readyNotices.insert(job, at: 0)
            publishCorrectionReady(job)
        }
    }

    /// `withCorrectionReadyNotification` + `saveNotifications`
    /// (`AnnaleCorrectionMonitor.tsx:85-94`) : une fiche prête (et seulement une
    /// fiche dotée d'un résultat) entre dans le magasin de notifications, une
    /// seule fois par `jobId`. Le magasin est isolé au fil principal : l'appel
    /// lui est relayé.
    private func publishCorrectionReady(_ job: AnnCopyJob) {
        guard let result = job.result else { return }
        let jobId = job.jobId
        let itemId = job.itemId
        let title = "\(job.title) — \(job.partLabel)"
        let score = result.score
        Task { @MainActor in
            AcctNotificationsStore.shared.addCorrectionReady(
                jobId: jobId,
                itemId: itemId,
                title: title,
                score: score
            )
        }
    }

    /// Accuse réception d'un bandeau de correction prête.
    func dismissNotice(_ job: AnnCopyJob) {
        readyNotices.removeAll { $0.jobId == job.jobId }
    }

    /// Démarre la boucle de fond : une lecture à la fois, jamais deux.
    func start() {
        guard pollingTask == nil else { return }
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.synchronize()
                try? await Task.sleep(nanoseconds: UInt64(AnnCorrectionMonitor.backgroundInterval * 1_000_000_000))
            }
        }
    }

    /// Arrête la boucle de fond.
    func stop() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    /// Relit une fois chaque correction encore active. Un échec réseau ne
    /// change rien : le travail du serveur continue (`refreshAnnaleCopyJob`).
    func synchronize() async {
        let active = jobs.filter { $0.isActive }
        guard !active.isEmpty else { return }
        var updated: [AnnCopyJob] = []
        for job in active {
            if let refreshed = try? await AnnCopyService.refresh(job: job, token: token) {
                updated.append(refreshed)
            } else {
                updated.append(job)
            }
        }
        for job in updated {
            upsert(job)
        }
    }
}
