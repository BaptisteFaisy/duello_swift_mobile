//
//  DuelloApiError.swift
//  Duello
//
//  Erreur normalisée de l'API Duello et politique d'URL de runtime.
//
//  Fichiers source Expo portés :
//    - src/utils/duelloApiError.ts
//        `DuelloApiError` (`message`, `status`, `code`, `retryAfterMs`) et
//        `retryAfterMilliseconds` (en-tête `Retry-After` en secondes **ou** en
//        date HTTP).
//    - src/utils/duelloApiUrl.ts
//        `resolveDuelloRuntimeUrl` / `resolveDuelloApiUrl` : une URL distante ne
//        remplace l'origine stable que dans le runtime Metro local ou dans un
//        binaire attaché au canal `development`.
//    - src/utils/duelloApiClient.ts (cartographie d'erreur du transport).
//
//  Ce fichier **complète** `DuelloAPITransport.swift` (fichier partagé, non
//  modifié) : `DirectoryError` reste l'erreur levée par `DuelloAPI.request`,
//  `DuelloApiError` en est la forme normalisée, et `DuelloApiError.from(_:)`
//  fait le pont. Les appelants qui ont besoin du `code` serveur ou du délai de
//  reprise passent par cette forme.
//
//  Cible : iOS 16, aucune dépendance externe.
//
import Foundation

/// Erreur HTTP ou réseau normalisée pour tous les appels à l'API Duello
/// (`DuelloApiError`).
struct DuelloApiError: Error, LocalizedError, Equatable {
    /// Message lisible, déjà en français côté serveur.
    let message: String
    /// Code HTTP, `nil` pour une panne réseau.
    let status: Int?
    /// Code applicatif renvoyé par le serveur, `nil` s'il est absent.
    let code: String?
    /// Délai avant nouvelle tentative, en millisecondes, `nil` si non annoncé.
    let retryAfterMs: Double?

    init(
        message: String,
        status: Int? = nil,
        code: String? = nil,
        retryAfterMs: Double? = nil
    ) {
        self.message = message
        self.status = status
        self.code = code
        self.retryAfterMs = retryAfterMs
    }

    var errorDescription: String? { message }

    /// Panne réseau : aucune réponse HTTP.
    var isNetworkFailure: Bool { status == nil }

    /// Le serveur a refusé la requête (4xx).
    var isClientError: Bool {
        guard let status else { return false }
        return (400..<500).contains(status)
    }

    /// Réponse temporaire : le serveur demande de réessayer (429, 5xx).
    var isRetryable: Bool {
        guard let status else { return true }
        return status == 429 || (500..<600).contains(status)
    }
}

/// Outils de la couche HTTP : `Retry-After` et pont avec `DirectoryError`.
enum DuelloApiErrors {

    /// `retryAfterMilliseconds` : l'en-tête `Retry-After` s'écrit en secondes
    /// **ou** en date HTTP ; toute valeur illisible donne `nil`.
    static func retryAfterMilliseconds(_ value: String?, now: Double) -> Double? {
        guard let value, !value.isEmpty else { return nil }
        if let seconds = Double(value), seconds.isFinite, seconds >= 0 {
            return (seconds * 1000).rounded(.up)
        }
        let parsed = DuelloApiErrors.httpDate(value)
        guard let parsed else { return nil }
        return max(0, parsed - now)
    }

    /// Analyse une date HTTP (`IMF-fixdate`, RFC 1123).
    static func httpDate(_ value: String) -> Double? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        return formatter.date(from: value)?.timeIntervalSince1970
    }

    /// Pont depuis l'erreur levée par `DuelloAPI.request` : le statut est connu,
    /// le code applicatif et le délai de reprise ne le sont pas.
    static func from(_ error: DirectoryError) -> DuelloApiError {
        DuelloApiError(message: error.message, status: error.status)
    }
}

/// Politique d'URL de runtime (`resolveDuelloRuntimeUrl`).
enum DuelloApiUrl {

    /// Une URL distante ne remplace l'origine stable que dans le runtime de
    /// développement ou dans un binaire attaché au canal `development`.
    ///
    /// Sur un binaire natif iOS, `developmentRuntime` est faux et il n'existe
    /// pas de canal de mise à jour : c'est toujours `permanentUrl` qui est
    /// retenue, exactement comme la source.
    static func resolve(
        permanentUrl: String,
        override: String? = nil,
        updateChannel: String? = nil,
        developmentRuntime: Bool = false
    ) -> String {
        let normalized = override?.trimmingCharacters(in: .whitespacesAndNewlines)
        let canUseOverride = developmentRuntime || updateChannel == "development"
        guard canUseOverride, let normalized, !normalized.isEmpty else {
            return permanentUrl
        }
        return normalized
    }
}
