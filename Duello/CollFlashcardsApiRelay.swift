//
//  CollFlashcardsApiRelay.swift
//  Duello
//
//  Port de src/utils/courseFlashcardsApi.ts (RN) — couche réseau de la
//  génération des cartes de cours : appel `POST /relay` et lecture de la
//  réponse, avec détection du refus de session (401/403).
//
//  Fichiers source Expo portés (libellés repris mot pour mot) :
//    - src/utils/courseFlashcardsApi.ts
//        `GeneratedCard`, `FlashcardRelayResponse`, `readRelayResponse`,
//        `postRelay`, `RELAY_REQUEST_TIMEOUT_MS`.
//    - src/utils/relayEndpoint.ts — `resolveRelayEndpoint` : le chemin du relais
//        reste `/relay` sur l'origine de l'API (ici `DuelloAPI.baseURL`), comme
//        `CtdAnalysisService` et `CollGradingService`. Une adresse dédiée
//        (`settings.endpoint`) n'est pas reprise : le client partagé `DuelloAPI`
//        n'est pas modifié.
//
//  Notes datées (24/09/2026) :
//    - `fetch` → `URLSession.shared.data(for:)` avec `timeoutInterval` de 30 s
//      (au lieu de l'`AbortController` de la source).
//    - `invalidateServerSession()` n'est pas appelé : sur 401/403, l'erreur
//      d'authentification remonte à l'appelant, qui décide de la reconnexion
//      (même contrat que `CollGradingService`).
//
//  Cible : iOS 16, aucune dépendance externe.
//

import Foundation

/// Carte produite par le relais (`GeneratedCard`).
struct CollGeneratedCard {
    var deck: String
    var question: String
    var answer: String
    /// Position de la notion dans le PDF, normalisée entre 0 et 1.
    var sourcePosition: Double?

    /// Lecture tolérante d'un objet de la réponse : un champ absent devient une
    /// chaîne vide (comme le `undefined` de la source).
    init(dictionary: [String: Any]) {
        deck = dictionary["deck"] as? String ?? ""
        question = dictionary["question"] as? String ?? ""
        answer = dictionary["answer"] as? String ?? ""
        sourcePosition = dictionary["sourcePosition"] as? Double
    }
}

/// Réponse du relais à toute action (`FlashcardRelayResponse`).
struct CollFlashcardRelayResponse {
    var cards: [CollGeneratedCard]?
    /// `'uploading' | 'pending'` (statut du job).
    var status: String?
    /// `'queued' | 'analyzing'` (phase d'analyse).
    var phase: String?
    var jobId: String?
    var uploadedChunks: Int?
    var totalChunks: Int?
    var error: String?

    init() {}

    /// Corps vide (`readRelayResponse` renvoie `{}`).
    init(dictionary: [String: Any]) {
        cards = (dictionary["cards"] as? [[String: Any]])?.map(CollGeneratedCard.init(dictionary:))
        status = dictionary["status"] as? String
        phase = dictionary["phase"] as? String
        jobId = dictionary["jobId"] as? String
        uploadedChunks = dictionary["uploadedChunks"] as? Int
        totalChunks = dictionary["totalChunks"] as? Int
        error = dictionary["error"] as? String
    }
}

/// Résultat d'un appel au relais : code HTTP et corps décodé.
struct CollFlashcardRelayResult {
    var status: Int
    var data: CollFlashcardRelayResponse

    /// `response.ok` : 2xx.
    var ok: Bool { (200..<300).contains(status) }
}

/// Relais Duello pour la génération des cartes (`POST /relay`).
enum CollFlashcardRelay {
    /// `RELAY_REQUEST_TIMEOUT_MS` de la source.
    static let requestTimeout: TimeInterval = 30

    /// `postRelay` : envoie une action et lit la réponse. Un refus de session
    /// (401/403) devient une `CollFlashcardAuthenticationError`.
    static func post(_ payload: [String: Any], token: String?) async throws -> CollFlashcardRelayResult {
        let body: Data
        do {
            body = try JSONSerialization.data(withJSONObject: payload, options: [])
        } catch {
            throw CollFlashcardGenerationError.relay("Les flashcards n’ont pas pu être générées. Réessaie.")
        }
        let (data, status) = try await send(body: body, token: token)
        let decoded = try readResponse(data: data, status: status)
        if status == 401 || status == 403 { throw CollFlashcardAuthenticationError() }
        return CollFlashcardRelayResult(status: status, data: decoded)
    }

    /// Requête HTTP brute. Le délai dépassé (`URLError.timedOut`) est rejeté tel
    /// quel : `generationErrorMessage` le traduit en message de reprise.
    private static func send(body: Data, token: String?) async throws -> (Data, Int) {
        var request = URLRequest(url: DuelloAPI.baseURL.appendingPathComponent("relay"))
        request.httpMethod = "POST"
        request.timeoutInterval = requestTimeout
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = body
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw CollFlashcardGenerationError.relay(offlineMessage)
            }
            return (data, http.statusCode)
        } catch let error as CollFlashcardGenerationError {
            throw error
        } catch let error as URLError where error.code == .timedOut {
            throw error
        } catch {
            throw CollFlashcardGenerationError.relay(offlineMessage)
        }
    }

    /// `readRelayResponse` : corps JSON objet, `{}` s'il est vide ; une réponse
    /// illisible est une panne (message selon le code HTTP).
    static func readResponse(data: Data, status: Int) throws -> CollFlashcardRelayResponse {
        guard !data.isEmpty else { return CollFlashcardRelayResponse() }
        guard let object = try? JSONSerialization.jsonObject(with: data),
              let dictionary = object as? [String: Any]
        else {
            throw CollFlashcardGenerationError.relay((200..<300).contains(status)
                ? "Le serveur a renvoyé une réponse illisible."
                : "Le serveur est momentanément indisponible (\(status)).")
        }
        return CollFlashcardRelayResponse(dictionary: dictionary)
    }

    /// Message partagé du serveur injoignable (`courseFlashcardGenerationError`).
    static let offlineMessage = "Le serveur est injoignable. Le téléversement reprendra après reconnexion."
}
