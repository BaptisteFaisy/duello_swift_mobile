//
//  PlanOllamaClient.swift
//  Duello
//
//  Écran « Plan » — analyse IA locale via le serveur Ollama de l'élève (ollamaClient.ts), repli sur l'analyseur standard.
//
import Foundation

// MARK: - Analyse IA locale (`ollamaClient.ts`)

/// Portage de `parseTaskDumpWithOllama` (ollamaClient.ts lignes 131-183).
///
/// L'appel vise le serveur Ollama **de l'élève** (réseau local), pas l'API
/// Duello : il n'entre donc pas dans `DuelloAPI.request`. Deux limites
/// assumées : l'URL est en `http://` (ATS peut la refuser) et les réglages sont
/// désactivés par défaut — l'analyseur local reste le chemin normal.
enum PlanOllamaClient {
    enum PlanOllamaError: Error {
        case badURL
        case status(Int)
        case malformedResponse
    }

    /// `SYSTEM_PROMPT` (lignes 33-44), verbatim.
    static let systemPrompt = """
    Tu es l'assistant de planification de Duello. Tu transformes la dictée en vrac d'un étudiant de classe préparatoire en une liste de tâches structurées, en JSON uniquement.

    Règles :
    - Une tâche par action distincte mentionnée dans le texte.
    - "subject" doit être choisi parmi exactement ces valeurs : Mathématiques, Physique, Chimie, Informatique, Anglais, Français-philo, Histoire-géographie, Biologie, Général. Utilise "Général" si aucune ne correspond clairement.
    - "priority" vaut "haute" si l'étudiant dit urgent / impératif / très important / absolument, "basse" si secondaire / pas urgent / si j'ai le temps, sinon "moyenne".
    - "deadline" est une échéance courte en français ("Aujourd'hui", "Demain", "Vendredi", "Avant le 12/05"...) ou null si rien n'est précisé.
    - "estimatedDuration" est une durée en minutes (entier). Si rien n'est précisé, estime une durée raisonnable pour la tâche (45 par défaut).
    - Convertis systématiquement toute expression mathématique dictée en notation symbolique correcte dans "title", avec ces équivalences et toute autre notation standard équivalente :
      "x carré" -> x², "x cube" -> x³, "puissance n" -> ^n, "racine de" / "racine carrée de" -> √(), "pi" -> π, "plus ou moins" -> ±, "infini" -> ∞, "intégrale de a à b" -> ∫[a,b], "somme" -> ∑, "appartient à" -> ∈, "inclus dans" -> ⊂, "inférieur ou égal" -> ≤, "supérieur ou égal" -> ≥, "différent de" -> ≠, "dérivée de f" -> f'(), "a sur b" (fraction) -> a/b, "fois" -> ×, "divisé par" -> ÷, "delta" -> Δ, "theta" -> θ, "lambda" -> λ.
      Exemple : "réviser x carré plus deux x moins trois égal zéro" devient le titre "Réviser x² + 2x − 3 = 0".
    - Garde les titres courts et lisibles, en français, sans texte ni commentaire en dehors du JSON demandé.
    """

    /// `TASK_RESPONSE_SCHEMA` (lignes 46-65), transmis tel quel à Ollama.
    private static let responseSchema = """
    {"type":"object","properties":{"tasks":{"type":"array","items":{"type":"object","properties":{"title":{"type":"string"},"subject":{"type":"string"},"priority":{"type":"string","enum":["haute","moyenne","basse"]},"deadline":{"type":["string","null"]},"estimatedDuration":{"type":"integer"}},"required":["title","subject","priority"]}}},"required":["tasks"]}
    """

    /// `trimBaseUrl` (lignes 112-114).
    private static func trimmed(_ baseUrl: String) -> String {
        var value = baseUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        while value.hasSuffix("/") { value.removeLast() }
        return value
    }

    /// `clampDuration` (lignes 116-120) : 10 à 240 minutes, 45 par défaut.
    private static func clampDuration(_ value: Any?) -> Int {
        let parsed: Double
        if let number = value as? Double {
            parsed = number
        } else if let number = value as? Int {
            parsed = Double(number)
        } else if let text = value as? String, let number = Double(text) {
            parsed = number
        } else {
            return 45
        }
        guard parsed.isFinite else { return 45 }
        return min(240, max(10, Int(parsed.rounded())))
    }

    /// `normalizePriority` (lignes 122-124).
    private static func normalizePriority(_ value: Any?) -> PlanPriority {
        guard let text = value as? String else { return .moyenne }
        return PlanPriority(rawValue: text.lowercased()) ?? .moyenne
    }

    /// `normalizeSubject` (lignes 126-129).
    private static func normalizeSubject(_ value: Any?) -> String {
        guard let text = (value as? String)?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
            return "Général"
        }
        return PlanSubjects.names.first { $0.lowercased() == text.lowercased() } ?? "Général"
    }

    /// `parseTaskDumpWithOllama` : `POST <baseUrl>/api/chat`, réponse JSON
    /// stricte, une tâche vide est ignorée.
    static func parse(transcript: String, settings: PlanOllamaSettings) async throws -> [PlanTask] {
        let base = trimmed(settings.baseUrl)
        guard let url = URL(string: base + "/api/chat") else { throw PlanOllamaError.badURL }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var body: [String: Any] = [
            "model": settings.model,
            "stream": false,
            "options": ["temperature": 0.2],
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": transcript],
            ],
        ]
        if let schema = try? JSONSerialization.jsonObject(with: Data(responseSchema.utf8)) {
            body["format"] = schema
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw PlanOllamaError.malformedResponse }
        guard (200..<300).contains(http.statusCode) else { throw PlanOllamaError.status(http.statusCode) }

        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let message = root["message"] as? [String: Any],
              let content = message["content"] as? String,
              let contentData = content.data(using: .utf8),
              let parsed = try? JSONSerialization.jsonObject(with: contentData) as? [String: Any],
              let rawTasks = parsed["tasks"] as? [[String: Any]] else {
            throw PlanOllamaError.malformedResponse
        }

        let stamp = Int(Date().timeIntervalSince1970 * 1000)
        return rawTasks.enumerated().compactMap { index, raw in
            let title = (raw["title"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !title.isEmpty else { return nil }
            let deadline = (raw["deadline"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            return PlanTask(
                id: "task-ollama-\(stamp)-\(index)",
                title: title,
                subject: normalizeSubject(raw["subject"]),
                priority: normalizePriority(raw["priority"]),
                deadline: (deadline?.isEmpty ?? true) ? nil : deadline,
                estimatedDuration: clampDuration(raw["estimatedDuration"])
            )
        }
    }
}
