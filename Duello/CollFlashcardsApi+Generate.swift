//
//  CollFlashcardsApi+Generate.swift
//  Duello
//
//  Port de src/utils/courseFlashcardsApi.ts (RN) — entrée publique de la
//  génération et orchestration de la reprise.
//
//  Découpage de `CollFlashcardsApi.swift` : l'entrée, la clé de dédoublonnage,
//  la reprise et l'attente partagée vivent ici ; les étapes (création du job,
//  téléversement, démarrage, suivi) sont dans `CollFlashcardsApi+Steps.swift`.
//
//  Notes datées (24/09/2026) :
//    - `AbortSignal` (web) → annulation structurée de `Task` : un appelant
//      annulé lève `CollFlashcardGenerationCancelledError` à la prochaine
//      vérification, sans interrompre la génération partagée (la reprise du job
//      la poursuit), comme `detachGenerationWhenAborted`.
//    - `document.size` absent dans la clé de dédoublonnage rend `"null"` (même
//      `join(':')` que la source).
//
//  Cible : iOS 16, aucune dépendance externe.
//

import Foundation

extension CollFlashcardsApi {

    /// `generateCourseFlashcardsFromPdf` : une seule génération en vol par
    /// document et par chapitre ; les appelants concurrents partagent la même
    /// tâche. Un job interrompu est repris (le téléversement continue là où il
    /// s'était arrêté).
    static func generateCourseFlashcardsFromPdf(
        accountId: String,
        document: CtdStoredCourseDocument,
        chapterName: String,
        storage: CollFlashcardJobStorage,
        token: String?,
        options: CollFlashcardGenerationOptions = CollFlashcardGenerationOptions()
    ) async throws -> CollFlashcardsDocument {
        if Task.isCancelled { throw CollFlashcardGenerationCancelledError() }
        let key = dedupKey(accountId: accountId, document: document, chapterName: chapterName)
        let task = CollFlashcardGenerationPool.shared.shared(forKey: key) {
            Task {
                try await once(
                    document: document, chapterName: chapterName,
                    storage: storage, token: token, options: options
                )
            }
        }
        return try await detached(task)
    }

    /// `generateCourseFlashcardsFromPdfOnce` : une seule reprise complète après
    /// un job périmé (`ExpiredCourseFlashcardJobError`), puis abandon.
    static func once(
        document: CtdStoredCourseDocument,
        chapterName: String,
        storage: CollFlashcardJobStorage,
        token: String?,
        options: CollFlashcardGenerationOptions
    ) async throws -> CollFlashcardsDocument {
        for attempt in 0..<2 {
            do {
                return try await attemptGeneration(
                    document: document, chapterName: chapterName,
                    storage: storage, token: token, options: options
                )
            } catch {
                guard error is CollExpiredFlashcardJobError, attempt == 0 else { throw error }
                clearJob(storage: storage, key: options.jobStorageKey)
            }
        }
        throw CollFlashcardGenerationError.resumeFailed
    }

    /// `generateCourseFlashcardsFromPdfAttempt` : autorisation IA, job (créé ou
    /// repris), téléversement puis suivi jusqu'aux cartes.
    static func attemptGeneration(
        document: CtdStoredCourseDocument,
        chapterName: String,
        storage: CollFlashcardJobStorage,
        token: String?,
        options: CollFlashcardGenerationOptions
    ) async throws -> CollFlashcardsDocument {
        guard CtdAiConsent.isGranted else { throw CollFlashcardGenerationError.consentRequired }
        let storedRaw = options.jobStorageKey.flatMap { storage.getItem($0) }
        var job = parseStoredJob(storedRaw, document: document, chapterName: chapterName)
        if storedRaw != nil && job == nil { clearJob(storage: storage, key: options.jobStorageKey) }

        var pdfBase64: String?
        if job == nil {
            report(options, phase: .preparing, fraction: nil)
            let base64 = try base64FromDocument(document)
            pdfBase64 = base64
            job = try await createJob(
                chapterName: chapterName, document: document, pdfBase64: base64,
                storage: storage, token: token, options: options
            )
        }
        guard var current = job else { throw CollFlashcardGenerationError.resumeFailed }
        if current.phase == .uploading {
            let base64: String
            if let pdfBase64 { base64 = pdfBase64 } else { base64 = try base64FromDocument(document) }
            current = try await uploadAndStart(
                job: current, pdfBase64: base64,
                storage: storage, token: token, options: options
            )
        }
        return try await pollUntilCards(
            job: current, document: document,
            storage: storage, token: token, options: options
        )
    }

    /// `[storage.accountId, uploadedAt, size, chapterName].join(':')`.
    private static func dedupKey(
        accountId: String,
        document: CtdStoredCourseDocument,
        chapterName: String
    ) -> String {
        let size = document.size.map { "\($0)" } ?? "null"
        return [accountId, "\(document.uploadedAt)", size, chapterName].joined(separator: ":")
    }

    /// `detachGenerationWhenAborted` : l'annulation de l'appelant lève
    /// `.cancelled` sans annuler la génération partagée.
    private static func detached(
        _ task: Task<CollFlashcardsDocument, Error>
    ) async throws -> CollFlashcardsDocument {
        if Task.isCancelled { throw CollFlashcardGenerationCancelledError() }
        do {
            return try await task.value
        } catch is CancellationError {
            throw CollFlashcardGenerationCancelledError()
        }
    }
}
