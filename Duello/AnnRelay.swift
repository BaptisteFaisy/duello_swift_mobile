import Foundation

// MARK: - Relais (endpoint local)

/// Appels au relais Duello pour la correction de copie.
///
/// L'application Expo passe par `resolveRelayEndpoint` (`utils/mathOcr.ts`) et
/// `utils/annaleCopyCorrection.ts`. Le chemin par défaut est `/relay` sur
/// l'origine de l'API, ce que `DuelloAPI.request("relay", …)` reproduit ; le
/// jeton de session Duello authentifie l'appel et sert le quota. Aucune clé de
/// fournisseur n'est utilisée côté client.
enum AnnRelay {
    /// Réponse du relais à toute action (`RelayJobPayload`).
    struct JobPayload: Decodable {
        var jobId: String
        var status: AnnCopyStatus
        var progress: Double
        var estimatedSeconds: Double
        var pageCount: Int
        var createdAt: Double
        var updatedAt: Double
        var result: AnnCopyResult?
        var error: String?
    }

    /// Actions du relais, mot pour mot des valeurs envoyées par Expo.
    enum Action {
        static let create = "create-annale-copy-job"
        static let uploadPage = "upload-annale-copy-page"
        static let start = "start-annale-copy-job"
        static let refresh = "get-annale-copy-job"
        static let retry = "retry-annale-copy-job"
    }

    /// Envoie une action au relais et décode la fiche de correction.
    static func call(
        _ action: String,
        payload: [String: Any] = [:],
        token: String?
    ) async throws -> JobPayload {
        var body = payload
        body["action"] = action
        let data: Data
        do {
            data = try JSONSerialization.data(withJSONObject: body, options: [])
        } catch {
            throw DirectoryError(message: "La copie n’a pas pu être envoyée.")
        }
        return try await DuelloAPI.request(JobPayload.self, "relay", method: "POST", token: token, body: data)
    }

    /// Ajoute une entrée au corps seulement lorsqu'elle porte une valeur :
    /// `JSONSerialization` refuse les valeurs absentes.
    static func put(_ payload: inout [String: Any], _ key: String, _ value: Any?) {
        guard let value else { return }
        payload[key] = value
    }

    /// Envoie une action dont la réponse n'est pas lue.
    ///
    /// Le dépôt d'une page ne renseigne rien : l'app Expo ignore le corps de la
    /// réponse et suit l'avancement en local. Seul le code HTTP compte donc ici,
    /// ce qui évite de faire échouer un envoi réussi sur une forme de réponse
    /// inattendue.
    static func callIgnoringResponse(
        _ action: String,
        payload: [String: Any] = [:],
        token: String?
    ) async throws {
        var body = payload
        body["action"] = action
        let data: Data
        do {
            data = try JSONSerialization.data(withJSONObject: body, options: [])
        } catch {
            throw DirectoryError(message: "La copie n’a pas pu être envoyée.")
        }
        _ = try await DuelloAPI.request("relay", method: "POST", token: token, body: data)
    }
}
