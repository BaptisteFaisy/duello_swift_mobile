//
//  PlanOllamaConnection.swift
//  Duello
//
//  Écran « Plan » — test de connexion au serveur Ollama de l'élève (ollamaClient.ts), utilisé par les réglages IA.
//  Fichier source Expo porté : src/utils/ollamaClient.ts — testOllamaConnection
//  Cible : iOS 16, aucune dépendance externe.
//
import Foundation

// MARK: - Test de connexion (`testOllamaConnection`)

extension PlanOllamaClient {
    /// `{ ok: boolean; error?: string }` (lignes 92-110) : le résultat du test,
    /// où `error` reste `nil` en cas de succès.
    struct PlanOllamaConnectionResult: Equatable {
        var ok: Bool
        var error: String?
    }

    /// `trimBaseUrl` (lignes 112-114) : espaces retirés en début et fin, puis
    /// tous les `/` finaux. Réimplémenté localement car `trimmed(_:)` de
    /// `PlanOllamaClient` est `private` au fichier et donc inaccessible ici.
    private static func trimmedForConnection(_ baseUrl: String) -> String {
        var value = baseUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        while value.hasSuffix("/") { value.removeLast() }
        return value
    }

    /// `data.models?.some((entry) => entry.name === settings.model)` (ligne 101) :
    /// le modèle est présent si un élément porte exactement ce `name`. Un corps
    /// illisible ou sans `models` équivaut à une liste vide (donc absent).
    private static func hasModel(named model: String, in data: Data) -> Bool {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let models = root["models"] as? [[String: Any]] else {
            return false
        }
        return models.contains { ($0["name"] as? String) == model }
    }

    /// `testOllamaConnection` (lignes 92-110) : interroge `<baseUrl>/api/tags`,
    /// vérifie que le modèle choisi est présent, avec un délai de 6 000 ms.
    /// Ne lance jamais : toute panne devient un `PlanOllamaConnectionResult`
    /// en échec, avec le message d'erreur de la source.
    static func testConnection(settings: PlanOllamaSettings) async -> PlanOllamaConnectionResult {
        let base = trimmedForConnection(settings.baseUrl)
        guard let url = URL(string: base + "/api/tags") else {
            return PlanOllamaConnectionResult(ok: false, error: "Connexion impossible")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 6

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                return PlanOllamaConnectionResult(ok: false, error: "Connexion impossible")
            }
            guard (200..<300).contains(http.statusCode) else {
                return PlanOllamaConnectionResult(
                    ok: false,
                    error: "Serveur injoignable (\(http.statusCode))"
                )
            }
            guard hasModel(named: settings.model, in: data) else {
                return PlanOllamaConnectionResult(
                    ok: false,
                    error: "Modèle \"\(settings.model)\" introuvable sur ce serveur Ollama"
                )
            }
            return PlanOllamaConnectionResult(ok: true, error: nil)
        } catch {
            let message = (error as NSError).localizedDescription
            return PlanOllamaConnectionResult(
                ok: false,
                error: message.isEmpty ? "Connexion impossible" : message
            )
        }
    }
}
