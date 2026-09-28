//
//  AdmAPITransport.swift
//  Duello
//
//  Transport des routes d'administration.
//
//  Fichier source Expo porté : src/admin/adminApi.ts (`adminRequest`).
//
//  L'espace admin n'a pas de transport à lui : il réutilise le relais partagé
//  `DuelloAPI.request(...)`, qui porte déjà l'adresse de base, le jeton
//  `Bearer` et la traduction des erreurs serveur. Seule la **clé d'accès** est
//  propre au compte admin.
//
//  Divergences assumées avec le client Expo :
//    - pas de délai dédié de 10 s (`REQUEST_TIMEOUT`) : le relais partagé
//      applique son propre délai (20 s), et son dépassement est traduit par le
//      message exact du source (`Le serveur admin met trop de temps à répondre.`) ;
//    - le relais partagé pose `Content-Type: application/json` dès qu'un corps
//      est envoyé, là où `adminApi.ts` ne pose que `Accept` + `Authorization`
//      (en-tête bénin, accepté par le serveur) ;
//    - l'adresse de base est celle du relais de développement
//      (`…workers.dev/api`), la source visant l'adresse Tailscale (`…:8445/api`) ;
//    - une clé vide n'ajoute aucun en-tête `Authorization`, comme côté Expo où
//      le serveur décide seul d'exiger `DUELLO_ADMIN_TOKEN`.
//
//  Le libellé du repli HTTP est, lui, **aligné** sur le source : `adminApi.ts`
//  écrit « Serveur indisponible (statut) » et laisse ce défaut quand le corps ne
//  porte pas d'`error` exploitable (`adminUnavailableLabel` ci-dessous), là où
//  le relais partagé écrit « Service indisponible (statut). ».
//
//  Cible : iOS 16. Aucune dépendance externe.
//

import Foundation

/// Erreurs propres à l'espace d'administration.
enum AdmAPIError: LocalizedError {
    /// `Réponse du serveur admin illisible.` (validation de `adminApi.ts`).
    case unreadable
    /// `Le serveur admin met trop de temps à répondre.` (`AbortError` du source).
    case timeout

    var errorDescription: String? {
        switch self {
        case .unreadable: return "Réponse du serveur admin illisible."
        case .timeout: return "Le serveur admin met trop de temps à répondre."
        }
    }
}

/// Client des routes `/admin/*` (`src/admin/adminApi.ts`).
enum AdmAPI {
    /// Requête brute : renvoie les octets de la réponse, ou lève une
    /// `DirectoryError` déjà traduite en français par le relais partagé.
    static func request(
        _ path: String,
        token: String,
        method: String = "GET",
        body: Data? = nil
    ) async throws -> Data {
        let normalized = token.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            return try await DuelloAPI.request(
                path,
                method: method,
                token: normalized.isEmpty ? nil : normalized,
                body: body
            )
        } catch let error as URLError where error.code == .timedOut {
            throw AdmAPIError.timeout
        } catch let error as DirectoryError {
            throw DirectoryError(
                message: adminUnavailableLabel(error.message, status: error.status),
                status: error.status
            )
        }
    }

    /// Requête décodée (`request<T>` de `adminApi.ts`).
    static func request<T: Decodable>(
        _ type: T.Type,
        _ path: String,
        token: String,
        method: String = "GET",
        body: Data? = nil
    ) async throws -> T {
        let data = try await request(path, token: token, method: method, body: body)
        return try DuelloAPI.decoder.decode(T.self, from: data)
    }

    /// `adminApi.ts` (175-183) : sur une réponse non-OK, le repli s'écrit
    /// « Serveur indisponible (statut) » et un `error` vide (ou seulement
    /// espacé) laisse ce défaut. Le relais partagé écrit, lui, « Service
    /// indisponible (statut). » ; on rétablit ici le libellé admin, sans toucher
    /// aux messages réellement fournis par le serveur.
    private static func adminUnavailableLabel(_ message: String, status: Int?) -> String {
        guard let status else { return message }
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || message == "Service indisponible (\(status))." {
            return "Serveur indisponible (\(status))"
        }
        return message
    }
}
