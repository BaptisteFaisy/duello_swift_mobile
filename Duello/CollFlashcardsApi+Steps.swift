//
//  CollFlashcardsApi+Steps.swift
//  Duello
//
//  Port de src/utils/courseFlashcardsApi.ts (RN) — étapes de la génération :
//  création du job, téléversement par morceaux, démarrage et suivi.
//
//  Découpage de `CollFlashcardsApi.swift` (aucune fonction > 50 lignes) : les
//  étapes restent des fonctions statiques de `CollFlashcardsApi`, appelées par
//  `CollFlashcardsApi+Generate.swift`.
//
//  Cible : iOS 16, aucune dépendance externe.
//

import Foundation

extension CollFlashcardsApi {

    // MARK: - Création du job

    /// `create-course-flashcards-job` : envoie l'identité du document et le
    /// nombre de morceaux, puis persiste le job naissant.
    static func createJob(
        chapterName: String,
        document: CtdStoredCourseDocument,
        pdfBase64: String,
        storage: CollFlashcardJobStorage,
        token: String?,
        options: CollFlashcardGenerationOptions
    ) async throws -> CollStoredFlashcardJob {
        let totalChunks = chunkCount(forBase64Length: pdfBase64.count)
        let result = try await CollFlashcardRelay.post([
            "action": "create-course-flashcards-job",
            "chapter": chapterName,
            "sourceMimeType": document.mimeType.rawValue,
            "totalChunks": totalChunks,
        ], token: token)
        guard result.ok, let jobId = result.data.jobId, !jobId.isEmpty else {
            throw CollFlashcardGenerationError.relay(
                result.data.error ?? "Téléversement indisponible (\(result.status))"
            )
        }
        let job = CollStoredFlashcardJob(
            version: 1, jobId: jobId, sourceUploadedAt: document.uploadedAt,
            chapterName: chapterName, totalChunks: totalChunks, uploadedChunks: 0,
            phase: .uploading, updatedAt: CollCompletion.now()
        )
        saveJob(job, storage: storage, key: options.jobStorageKey)
        return job
    }

    // MARK: - Téléversement puis démarrage

    /// Phase `uploading` : téléverse les morceaux restants puis démarre l'analyse.
    static func uploadAndStart(
        job: CollStoredFlashcardJob,
        pdfBase64: String,
        storage: CollFlashcardJobStorage,
        token: String?,
        options: CollFlashcardGenerationOptions
    ) async throws -> CollStoredFlashcardJob {
        let uploaded = try await uploadChunks(
            job: job, pdfBase64: pdfBase64,
            storage: storage, token: token, options: options
        )
        return try await startJob(
            job: uploaded, storage: storage, token: token, options: options
        )
    }

    /// `for (let chunkIndex = job.uploadedChunks; …)` : envoie chaque morceau
    /// restant et persiste la progression après chacun.
    static func uploadChunks(
        job: CollStoredFlashcardJob,
        pdfBase64: String,
        storage: CollFlashcardJobStorage,
        token: String?,
        options: CollFlashcardGenerationOptions
    ) async throws -> CollStoredFlashcardJob {
        let totalChunks = chunkCount(forBase64Length: pdfBase64.count)
        guard totalChunks == job.totalChunks else {
            clearJob(storage: storage, key: options.jobStorageKey)
            throw CollExpiredFlashcardJobError()
        }
        var current = job
        report(options, phase: .uploading, fraction: fraction(current))
        for index in current.uploadedChunks..<current.totalChunks {
            let result = try await CollFlashcardRelay.post([
                "action": "upload-course-flashcards-chunk",
                "jobId": current.jobId,
                "chunkIndex": index,
                "chunkBase64": chunk(of: pdfBase64, at: index),
            ], token: token)
            if result.status == 404 { throw CollExpiredFlashcardJobError() }
            guard result.ok else {
                throw CollFlashcardGenerationError.relay(
                    result.data.error ?? "Téléversement indisponible (\(result.status))"
                )
            }
            current.uploadedChunks = index + 1
            current.updatedAt = CollCompletion.now()
            saveJob(current, storage: storage, key: options.jobStorageKey)
            report(options, phase: .uploading, fraction: fraction(current))
        }
        return current
    }

    /// `start-course-flashcards-job` : lance l'analyse et passe le job en attente.
    static func startJob(
        job: CollStoredFlashcardJob,
        storage: CollFlashcardJobStorage,
        token: String?,
        options: CollFlashcardGenerationOptions
    ) async throws -> CollStoredFlashcardJob {
        let result = try await CollFlashcardRelay.post([
            "action": "start-course-flashcards-job",
            "jobId": job.jobId,
        ], token: token)
        if result.status == 404 { throw CollExpiredFlashcardJobError() }
        guard result.ok else {
            throw CollFlashcardGenerationError.relay(
                result.data.error ?? "Analyse indisponible (\(result.status))"
            )
        }
        var current = job
        current.phase = .pending
        current.updatedAt = CollCompletion.now()
        saveJob(current, storage: storage, key: options.jobStorageKey)
        report(options, phase: result.data.phase == "analyzing" ? .analyzing : .queued, fraction: nil)
        return current
    }

    // MARK: - Suivi

    /// `for (;;)` de la source : interroge le job toutes les 1,5 s jusqu'aux
    /// cartes ; un `202 pending` republie l'avancement et continue.
    static func pollUntilCards(
        job: CollStoredFlashcardJob,
        document: CtdStoredCourseDocument,
        storage: CollFlashcardJobStorage,
        token: String?,
        options: CollFlashcardGenerationOptions
    ) async throws -> CollFlashcardsDocument {
        while true {
            try await pollDelay()
            let result = try await CollFlashcardRelay.post([
                "action": "get-course-flashcards-job",
                "jobId": job.jobId,
            ], token: token)
            if result.status == 404 { throw CollExpiredFlashcardJobError() }
            if result.status == 202 && result.data.status == "pending" {
                report(options, phase: result.data.phase == "analyzing" ? .analyzing : .queued, fraction: nil)
                continue
            }
            guard result.ok else {
                clearJob(storage: storage, key: options.jobStorageKey)
                throw CollFlashcardGenerationError.relay(
                    result.data.error ?? "Génération indisponible (\(result.status))"
                )
            }
            let generated = try generatedDocument(result.data, document: document)
            clearJob(storage: storage, key: options.jobStorageKey)
            return generated
        }
    }

    // MARK: - Utilitaires internes

    /// `await new Promise(resolve => setTimeout(resolve, 1500))` : une annulation
    /// de l'appelant devient `.cancelled`.
    private static func pollDelay() async throws {
        do {
            try await Task.sleep(nanoseconds: 1_500_000_000)
        } catch {
            throw CollFlashcardGenerationCancelledError()
        }
    }

    /// Publie l'avancement auprès de l'appelant (partagé avec
    /// `CollFlashcardsApi+Generate.swift`, donc `internal`).
    static func report(
        _ options: CollFlashcardGenerationOptions,
        phase: CollFlashcardGenerationProgress.Phase,
        fraction: Double?
    ) {
        options.onProgress?(CollFlashcardGenerationProgress(phase: phase, fraction: fraction))
    }

    /// Fraction `uploadedChunks / totalChunks`.
    private static func fraction(_ job: CollStoredFlashcardJob) -> Double {
        Double(job.uploadedChunks) / Double(job.totalChunks)
    }

    /// `Math.ceil(base64.length / COURSE_UPLOAD_CHUNK_CHARS)`.
    private static func chunkCount(forBase64Length length: Int) -> Int {
        let chars = CollFlashcardApiLimits.uploadChunkChars
        return (length + chars - 1) / chars
    }

    /// `base64.slice(index * CHUNK, (index + 1) * CHUNK)`.
    private static func chunk(of base64: String, at index: Int) -> String {
        let chars = CollFlashcardApiLimits.uploadChunkChars
        let start = index * chars
        let end = min(base64.count, start + chars)
        guard start < end else { return "" }
        let from = base64.index(base64.startIndex, offsetBy: start)
        let to = base64.index(base64.startIndex, offsetBy: end)
        return String(base64[from..<to])
    }
}
