import Foundation

// Découpage de `DuelloAPI.swift` — correcteur IA (relais) : notation d'une
// copie, quotas et refus côté serveur. Aucun type, membre ni signature renommé.

extension DuelloAPI {
    // MARK: Correcteur IA (relais)

    enum GradingError: Error {
        /// Le quota serveur est un refus produit, jamais une panne à masquer
        /// localement. `nextFreeAt` arrive en millisecondes.
        case quota(String, nextFreeAt: Double?)
        case refused(String)
    }

    struct RelayGradingResponse: Decodable {
        var score: Double?
        var note: String?
        var error: String?
        var nextFreeAt: Double?
    }

    /// `POST /relay` avec `action: "grade-duel-copy"` — fait noter une copie
    /// par l'IA, exactement comme `gradeCopyWithAi` (Expo). Le jeton de
    /// session Duello authentifie l'appel et sert le quota ; l'application
    /// n'appelle jamais OpenAI ni Anthropic directement.
    static func gradeCopyWithAi(
        subject: String,
        prompt: String,
        solution: String?,
        copy: String,
        durationMinutes: Int,
        operationKey: String,
        token: String
    ) async throws -> ProductionAssessment {
        struct Body: Encodable {
            var action: String
            var subject: String
            var prompt: String
            var solution: String?
            var copy: String
            var durationMinutes: Int
            var operationKey: String
        }
        let body = try encodeBody(Body(
            action: "grade-duel-copy",
            subject: subject,
            prompt: prompt,
            solution: solution,
            copy: copy,
            durationMinutes: durationMinutes,
            operationKey: operationKey
        ))

        let request = relayGradingRequest(body: body, token: token)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw DirectoryError(message: "Le correcteur est injoignable.")
        }
        let payload = try? decoder.decode(RelayGradingResponse.self, from: data)
        try relayRejection(payload, status: http.statusCode)
        return try relayAssessment(from: payload)
    }

    /// Requête de `gradeCopyWithAi` : aucun minuteur applicatif — l'effort
    /// maximal du correcteur peut légitimement dépasser trente secondes.
    private static func relayGradingRequest(body: Data, token: String) -> URLRequest {
        var request = URLRequest(url: baseURL.appendingPathComponent("relay"))
        request.httpMethod = "POST"
        request.timeoutInterval = 180
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = body
        return request
    }

    /// Statuts de refus du relais : 402 = quota épuisé, 401/403 = accès
    /// refusé (refus produit), tout autre non-2xx = panne du service.
    private static func relayRejection(_ payload: RelayGradingResponse?, status: Int) throws {
        if status == 402 {
            throw GradingError.quota(
                payload?.error ?? "Quota de défis épuisé",
                nextFreeAt: payload?.nextFreeAt
            )
        }
        if status == 401 || status == 403 {
            throw GradingError.refused("Accès à la notation refusé")
        }
        guard (200..<300).contains(status) else {
            throw DirectoryError(
                message: payload?.error ?? "Notation indisponible (\(status)).",
                status: status
            )
        }
    }

    /// Note exploitable du correcteur, bornée à 0…100.
    private static func relayAssessment(from payload: RelayGradingResponse?) throws -> ProductionAssessment {
        let note = (payload?.note ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !note.isEmpty, let score = payload?.score, score.isFinite else {
            throw DirectoryError(message: "Réponse inattendue du correcteur.")
        }
        return ProductionAssessment(score: min(100, max(0, Int(score.rounded()))), note: note)
    }
}
