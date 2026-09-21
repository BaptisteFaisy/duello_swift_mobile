import Foundation

// NOTE — `submit` fait 55 lignes et dépasse donc la limite « 50 lignes par
// fonction » des règles Duello. Ce dépassement vient de `AnnalesView.swift`
// d'origine et n'est pas corrigé : ce découpage ne réécrit aucun code (aucun
// type, propriété, méthode ni signature modifié).

// MARK: - Service de correction de copie

/// Envoi et suivi d'une copie, aligné sur `annaleCopyCorrection.ts` et
/// `uploadAnnaleCopyPages.ts`.
enum AnnCopyService {
    /// `MAX_CONCURRENT_COPY_UPLOADS` de `correctionPerformance.ts`.
    static let maxConcurrentUploads = 2
    /// `VISIBLE_COPY_REFRESH_MS` : cadence de rafraîchissement de la fenêtre.
    static let visibleRefreshInterval: TimeInterval = 1.5

    /// Crée le job, envoie les pages puis démarre la correction
    /// (`submitAnnaleCopy`). `onProgress` reçoit l'avancement de l'envoi, en %.
    static func submit(
        attemptKey: String,
        itemId: String,
        title: String,
        partLabel: String,
        subject: String,
        statement: String,
        solution: String?,
        durationMinutes: Int?,
        pages: [AnnCopyPage],
        token: String?,
        onProgress: @escaping (Int) -> Void
    ) async throws -> AnnCopyJob {
        var payload: [String: Any] = [:]
        AnnRelay.put(&payload, "attemptKey", attemptKey)
        AnnRelay.put(&payload, "title", title)
        AnnRelay.put(&payload, "partLabel", partLabel)
        AnnRelay.put(&payload, "subject", subject)
        AnnRelay.put(&payload, "statement", statement)
        AnnRelay.put(&payload, "solution", solution)
        AnnRelay.put(&payload, "durationMinutes", durationMinutes)
        AnnRelay.put(&payload, "pageCount", pages.count)

        let remote = try await AnnRelay.call(AnnRelay.Action.create, payload: payload, token: token)
        var job = merge(
            local: AnnCopyJob(
                jobId: remote.jobId,
                attemptKey: attemptKey,
                itemId: itemId,
                title: title,
                partLabel: partLabel.trimmingCharacters(in: .whitespacesAndNewlines),
                status: remote.status,
                progress: remote.progress,
                estimatedSeconds: remote.estimatedSeconds,
                pageCount: remote.pageCount,
                createdAt: remote.createdAt,
                updatedAt: remote.updatedAt,
                notifyOnReady: false,
                result: remote.result,
                error: remote.error
            ),
            remote: remote
        )
        upsert(job)

        if remote.status == .uploading {
            try await uploadPages(pages, jobId: job.jobId, token: token, onProgress: onProgress)
            var startPayload: [String: Any] = [:]
            AnnRelay.put(&startPayload, "jobId", job.jobId)
            let started = try await AnnRelay.call(AnnRelay.Action.start, payload: startPayload, token: token)
            job = merge(local: job, remote: started)
        }
        upsert(job)
        return job
    }

    /// Relit l'état d'un job côté serveur (`refreshAnnaleCopyJob`).
    static func refresh(job: AnnCopyJob, token: String?) async throws -> AnnCopyJob {
        var payload: [String: Any] = [:]
        AnnRelay.put(&payload, "jobId", job.jobId)
        let remote = try await AnnRelay.call(AnnRelay.Action.refresh, payload: payload, token: token)
        return merge(local: job, remote: remote)
    }

    /// Relance une correction interrompue (`retryAnnaleCopyJob`).
    static func retry(job: AnnCopyJob, token: String?) async throws -> AnnCopyJob {
        var payload: [String: Any] = [:]
        AnnRelay.put(&payload, "jobId", job.jobId)
        let remote = try await AnnRelay.call(AnnRelay.Action.retry, payload: payload, token: token)
        return merge(local: job, remote: remote)
    }

    /// Envoie les pages par groupes de deux (`uploadAnnaleCopyPages`).
    ///
    /// Les pages partent par vagues bornées à `maxConcurrentUploads` : l'Expo
    /// maintient deux envois simultanés pour borner la mémoire et l'occupation
    /// du réseau mobile. Une vague terminée, l'avancement est publié, puis la
    /// vague suivante démarre — un échec interrompt les vagues restantes.
    static func uploadPages(
        _ pages: [AnnCopyPage],
        jobId: String,
        token: String?,
        onProgress: @escaping (Int) -> Void
    ) async throws {
        guard !pages.isEmpty else { return }
        var index = 0
        var completed = 0
        while index < pages.count {
            let end = min(index + maxConcurrentUploads, pages.count)
            let wave = Array(index..<end)
            try await withThrowingTaskGroup(of: Void.self) { group in
                for position in wave {
                    let page = pages[position]
                    group.addTask {
                        var payload: [String: Any] = [:]
                        AnnRelay.put(&payload, "jobId", jobId)
                        AnnRelay.put(&payload, "pageIndex", position)
                        AnnRelay.put(&payload, "image", page.imageBase64)
                        AnnRelay.put(&payload, "mimeType", page.mimeType)
                        try await AnnRelay.callIgnoringResponse(AnnRelay.Action.uploadPage, payload: payload, token: token)
                    }
                }
                for try await _ in group {}
            }
            completed += wave.count
            onProgress(Int((Double(completed) / Double(pages.count) * 100).rounded()))
            index = end
        }
    }

    /// `mergeRelayJob` : la fiche locale garde ce que le relais ne renvoie pas.
    static func merge(local: AnnCopyJob, remote: AnnRelay.JobPayload) -> AnnCopyJob {
        var job = local
        job.status = remote.status
        job.progress = remote.progress
        job.estimatedSeconds = remote.estimatedSeconds
        job.pageCount = remote.pageCount
        job.createdAt = remote.createdAt
        job.updatedAt = remote.updatedAt
        job.result = remote.result
        job.error = remote.error
        return job
    }

    /// Enregistre ou remplace un job dans le stockage local.
    static func upsert(_ job: AnnCopyJob) {
        var jobs = AnnCopyStore.load()
        jobs.removeAll { $0.jobId == job.jobId }
        jobs.insert(job, at: 0)
        AnnCopyStore.save(jobs)
    }
}
