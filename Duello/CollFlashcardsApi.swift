//
//  CollFlashcardsApi.swift
//  Duello
//
//  Port de src/utils/courseFlashcardsApi.ts (RN) — génération des cartes de
//  révision d'un cours par le relais Duello : types, erreurs, lecture du
//  document et utilitaires purs. L'entrée et les étapes vivent dans
//  `CollFlashcardsApi+Generate.swift` et `CollFlashcardsApi+Steps.swift`, la
//  couche réseau dans `CollFlashcardsApiRelay.swift`, le stockage du job dans
//  `CollFlashcardJobStorage.swift`, le dédoublonnage dans
//  `CollFlashcardGenerationPool.swift`.
//
//  Fichiers source Expo portés (libellés repris mot pour mot) :
//    - src/utils/courseFlashcardsApi.ts
//        `COURSE_UPLOAD_CHUNK_CHARS`, `MAX_COURSE_DOCUMENT_BASE64_CHARS`,
//        `GeneratedCard`, `StoredCourseFlashcardJob`,
//        `CourseFlashcardGenerationProgress`, `CourseFlashcardGenerationOptions`,
//        `CourseFlashcardAuthenticationError`,
//        `isCourseFlashcardAuthenticationError`, `ExpiredCourseFlashcardJobError`,
//        `CourseFlashcardGenerationCancelledError`, `courseFlashcardGenerationError`,
//        `base64FromDocument`, `parseStoredJob`, `generatedDocument`, `saveJob`,
//        `clearJob`, `generateCourseFlashcardsFromPdf`.
//
//  Notes datées (24/09/2026) :
//    - `requireAiDataSharingConsent(storage)` : la fenêtre d'autorisation est
//      portée par la vue (comme `CourseTdView`) ; ici, un accord absent lève
//      `CollFlashcardGenerationError.consentRequired`.
//    - `loadMathOcrSettings`/`resolveRelayEndpoint` : adresse et jeton ne sont
//      plus relus du stockage — l'appelant fournit `token` (session Duello) et
//      le relais reste `/relay` sur `DuelloAPI.baseURL` (cf. la couche réseau).
//    - `generatedDocument` : une `sourcePosition` absente vaut 0 (la source
//      calculerait `NaN`) ; les valeurs restent bornées `[0, 1]`.
//
//  Cible : iOS 16, aucune dépendance externe.
//

import Foundation

// MARK: - Constantes

/// Réglages de la génération, mot pour mot de la source.
enum CollFlashcardApiLimits {
    /// `COURSE_UPLOAD_CHUNK_CHARS` : taille d'un morceau de PDF téléversé.
    static let uploadChunkChars = 512 * 1024
    /// `MAX_COURSE_DOCUMENT_BASE64_CHARS` : taille maximale du PDF en base64.
    static let maxDocumentBase64Chars = 23 * 1024 * 1024
}

// MARK: - Types persistés et publiés

/// Job de génération persisté entre deux tentatives
/// (`StoredCourseFlashcardJob`).
struct CollStoredFlashcardJob: Codable, Equatable {
    /// `'uploading' | 'pending'`.
    enum Phase: String, Codable {
        case uploading
        case pending
    }

    var version: Int
    var jobId: String
    var sourceUploadedAt: Double
    var chapterName: String
    var totalChunks: Int
    var uploadedChunks: Int
    var phase: Phase
    var updatedAt: Double
}

/// Avancement publié à l'écran (`CourseFlashcardGenerationProgress`).
struct CollFlashcardGenerationProgress: Equatable {
    /// `'preparing' | 'uploading' | 'queued' | 'analyzing'`.
    enum Phase: String, Equatable {
        case preparing
        case uploading
        case queued
        case analyzing
    }

    var phase: Phase
    /// Avancement du téléversement, ou `nil` quand il n'est pas mesurable.
    var fraction: Double?
}

/// Options de génération (`CourseFlashcardGenerationOptions`).
struct CollFlashcardGenerationOptions {
    var jobStorageKey: String?
    var onProgress: ((CollFlashcardGenerationProgress) -> Void)?

    init(
        jobStorageKey: String? = nil,
        onProgress: ((CollFlashcardGenerationProgress) -> Void)? = nil
    ) {
        self.jobStorageKey = jobStorageKey
        self.onProgress = onProgress
    }
}

// MARK: - Erreurs

/// Session Duello expirée pendant l'analyse
/// (`CourseFlashcardAuthenticationError`).
struct CollFlashcardAuthenticationError: LocalizedError {
    var errorDescription: String? {
        "Ta session Duello a expiré. Reconnecte-toi avec ton mot de passe ou avec Google pour relancer l’analyse."
    }
}

/// `isCourseFlashcardAuthenticationError`.
func isCourseFlashcardAuthenticationError(_ error: Error) -> Bool {
    error is CollFlashcardAuthenticationError
}

/// Job périmé côté relais (`ExpiredCourseFlashcardJobError`) : une seule reprise
/// complète est tentée.
struct CollExpiredFlashcardJobError: Error {}

/// Génération annulée (`CourseFlashcardGenerationCancelledError`).
struct CollFlashcardGenerationCancelledError: Error {}

/// Erreurs de génération portées par le relais ou la source.
enum CollFlashcardGenerationError: LocalizedError {
    /// Refus ou panne du relais, message déjà rédigé par le serveur.
    case relay(String)
    /// Reprise impossible après un job périmé (`once`).
    case resumeFailed
    /// Autorisation de partage avec l'IA manquante.
    case consentRequired

    var errorDescription: String? {
        switch self {
        case .relay(let message):
            return message
        case .resumeFailed:
            return "Le téléversement du cours n’a pas pu être repris."
        case .consentRequired:
            return CtdAiConsent.declinedLabel
        }
    }
}

// MARK: - API

/// `courseFlashcardsApi.ts` : utilitaires de la génération.
enum CollFlashcardsApi {

    /// `AbortError` de la source : « La connexion a pris trop de temps… ».
    static let timeoutMessage = "La connexion a pris trop de temps. La prochaine tentative reprendra le téléversement."
    /// Repli de la source (`courseFlashcardGenerationError`).
    static let fallbackMessage = "Les flashcards n’ont pas pu être générées. Réessaie."

    /// `courseFlashcardGenerationError` : message affichable pour une panne de
    /// génération (délai dépassé, serveur injoignable, message du relais).
    static func generationErrorMessage(_ error: Error) -> String {
        if error is CollFlashcardGenerationCancelledError { return timeoutMessage }
        if let urlError = error as? URLError {
            return urlError.code == .timedOut ? timeoutMessage : CollFlashcardRelay.offlineMessage
        }
        if let text = (error as? LocalizedError)?.errorDescription?
            .trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty {
            return text
        }
        return fallbackMessage
    }

    /// `base64FromDocument` : lit le document (`data:` ou fichier), refuse
    /// au-delà de `MAX_COURSE_DOCUMENT_BASE64_CHARS` et un document vide.
    static func base64FromDocument(_ document: CtdStoredCourseDocument) throws -> String {
        let base64: String
        if document.uri.hasPrefix("data:") {
            let separator = document.uri.firstIndex(of: ",")
            base64 = separator.map { String(document.uri[document.uri.index(after: $0)...]) } ?? ""
        } else {
            guard let data = FileManager.default.contents(atPath: document.uri) else {
                throw CollFlashcardGenerationError.relay("Ce document est vide ou illisible.")
            }
            base64 = data.base64EncodedString()
        }
        if base64.count > CollFlashcardApiLimits.maxDocumentBase64Chars {
            throw CollFlashcardGenerationError.relay("Ce document est trop volumineux pour générer les flashcards.")
        }
        if base64.isEmpty { throw CollFlashcardGenerationError.relay("Ce document est vide ou illisible.") }
        return base64
    }

    /// `parseStoredJob` : relit un job persisté, `nil` s'il ne correspond plus au
    /// document ou au chapitre (validation tolérante de la source).
    static func parseStoredJob(
        _ raw: String?,
        document: CtdStoredCourseDocument,
        chapterName: String
    ) -> CollStoredFlashcardJob? {
        guard let raw,
              let data = raw.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data),
              let value = object as? [String: Any],
              intValue(value["version"]) == 1,
              let jobId = value["jobId"] as? String, !jobId.isEmpty,
              doubleValue(value["sourceUploadedAt"]) == document.uploadedAt,
              value["chapterName"] as? String == chapterName,
              let totalChunks = intValue(value["totalChunks"]), totalChunks >= 1,
              let uploadedChunks = intValue(value["uploadedChunks"]),
              uploadedChunks >= 0, uploadedChunks <= totalChunks,
              let phaseRaw = value["phase"] as? String,
              let phase = CollStoredFlashcardJob.Phase(rawValue: phaseRaw),
              let updatedAt = doubleValue(value["updatedAt"])
        else { return nil }
        return CollStoredFlashcardJob(
            version: 1, jobId: jobId, sourceUploadedAt: document.uploadedAt,
            chapterName: chapterName, totalChunks: totalChunks,
            uploadedChunks: uploadedChunks, phase: phase, updatedAt: updatedAt
        )
    }

    /// `generatedDocument` : construit le document de cartes depuis la réponse du
    /// relais. Les positions sont bornées `[0, 1]` ; une position absente vaut 0.
    static func generatedDocument(
        _ response: CollFlashcardRelayResponse,
        document: CtdStoredCourseDocument
    ) throws -> CollFlashcardsDocument {
        guard let rawCards = response.cards else {
            throw CollFlashcardGenerationError.relay("Le relais n’a renvoyé aucune carte.")
        }
        let cards = rawCards.enumerated().map { index, card in
            CollFlashcard(
                id: "\(card.deck)-\(index + 1)",
                deck: card.deck,
                question: card.question,
                answer: card.answer,
                verdict: nil,
                seenAt: nil,
                origin: .generated,
                sourcePosition: min(1, max(0, card.sourcePosition ?? 0))
            )
        }
        guard !cards.isEmpty else {
            throw CollFlashcardGenerationError.relay("Le relais n’a renvoyé aucune carte.")
        }
        return CollFlashcardsDocument(
            version: 1,
            generatedAt: CollCompletion.now(),
            sourceName: document.name,
            cards: cards,
            decks: nil
        )
    }

    /// `saveJob` : enregistre le job sous sa clé, s'il y en a une.
    static func saveJob(_ job: CollStoredFlashcardJob, storage: CollFlashcardJobStorage, key: String?) {
        guard let key,
              let data = try? JSONEncoder().encode(job),
              let raw = String(data: data, encoding: .utf8)
        else { return }
        storage.setItem(key, raw)
    }

    /// `clearJob` : efface le job, s'il y a une clé.
    static func clearJob(storage: CollFlashcardJobStorage, key: String?) {
        guard let key else { return }
        storage.removeItem(key)
    }

    // MARK: Utilitaires

    /// `typeof value === 'number'` (entier) : `Int` ou `Double` JSON.
    private static func intValue(_ value: Any?) -> Int? {
        if let number = value as? Int { return number }
        if let number = value as? Double { return Int(number) }
        return nil
    }

    /// `typeof value === 'number'` (flottant).
    private static func doubleValue(_ value: Any?) -> Double? {
        if let number = value as? Double { return number }
        if let number = value as? Int { return Double(number) }
        return nil
    }
}
