//
//  CollGradingService.swift
//  Duello
//
//  Notation d'une question de colle par le relais Duello, et note pondérée de la
//  colle entière.
//
//  Fichiers source Expo portés (libellés repris mot pour mot) :
//    - src/utils/mathAnswerGrading.ts
//        action `grade-answer`, clés du corps (dont `statementImage`,
//        `correctionImage`, `correction`, `gradingGuidance`), lecture de la
//        réponse et messages d'erreur (`CorrectionAuthenticationError`,
//        correcteur indisponible).
//    - src/utils/gradingScore.ts
//        `calculateColleScore`, `GradingScore`, `positivePoints`, `roundScore`.
//
//  Le client partagé `DuelloAPI` n'est pas modifié : la requête reprend
//  `DuelloAPI.baseURL` et le délai de la source (95 s), comme `CtdAnalysisService`.
//  Le corps d'une notation (`grade-answer`) est assemblé ici ; la boucle de
//  retentative, la garde de consentement IA, l'annulation et l'enregistrement de
//  la durée vivent dans `CollGradingRequest.swift`.
//  Cible : iOS 16, aucune dépendance externe.
//
import Foundation

/// Note pondérée d'une colle (`GradingScore` de `utils/gradingScore.ts`).
struct CollGradingScore: Equatable {
    /// Note sur 20, ou `nil` lorsqu'aucune question n'est notée.
    var scoreOn20: Double?
    var earnedPoints: Double
    var possiblePoints: Double
    var gradedPoints: Double
    var totalQuestions: Int
    var gradedQuestions: Int
    var complete: Bool

    /// `calculateColleScore` : les questions d'une colle sont équipondérées par
    /// défaut (une question sans barème vaut un point). La colle n'a pas de choix
    /// alternatifs, chaque question est donc son propre groupe.
    static func colle(_ questions: [CollRemainingQuestion]) -> CollGradingScore {
        var earned = 0.0
        var possible = 0.0
        var gradedPoints = 0.0
        var gradedQuestions = 0
        var complete = !questions.isEmpty

        for question in questions {
            let points = positivePoints(question.points)
            possible += points
            earned += points * (question.grade?.verdict.scoreCoefficient ?? 0)
            if question.grade != nil {
                gradedPoints += points
                gradedQuestions += 1
            }
            complete = complete && question.grade != nil
        }

        let scoreOn20 = gradedPoints > 0 && possible > 0
            ? roundScore((earned / possible) * 20)
            : nil
        return CollGradingScore(
            scoreOn20: scoreOn20,
            earnedPoints: earned,
            possiblePoints: possible,
            gradedPoints: gradedPoints,
            totalQuestions: questions.count,
            gradedQuestions: gradedQuestions,
            complete: complete
        )
    }

    /// `positivePoints` : barème strictement positif, sinon un point.
    private static func positivePoints(_ value: Double?) -> Double {
        guard let value, value.isFinite, value > 0 else { return 1 }
        return value
    }

    /// `roundScore` : note bornée `[0, 20]`, arrondie au dixième.
    private static func roundScore(_ value: Double) -> Double {
        guard value.isFinite else { return 0 }
        return (min(20, max(0, value)) * 10).rounded() / 10
    }
}

/// Erreur de notation d'une question, alignée sur les erreurs de la source.
enum CollGradingError: LocalizedError {
    /// Session Duello expirée : l'écran doit redemander une connexion.
    case authentication
    /// Accord de partage avec les prestataires d'IA absent
    /// (`AiDataSharingConsentRequiredError`).
    case consent
    /// Notation arrêtée par l'appelant (`AbortSignal` de la source).
    case cancelled
    /// Refus ou panne du relais, message déjà rédigé par le serveur, et statut
    /// HTTP quand il est connu (502/503 sont retentés).
    case relay(String, status: Int?)
    /// Délai du correcteur dépassé.
    case timeout
    /// Correcteur injoignable.
    case offline

    var errorDescription: String? {
        switch self {
        case .authentication:
            return "Ta session Duello a expiré. Reconnecte-toi pour utiliser le correcteur."
        case .consent:
            return CtdAiConsent.declinedLabel
        case .cancelled:
            return "Correction arrêtée"
        case .relay(let message, _):
            return message
        case .timeout:
            return "Le correcteur a mis trop de temps à répondre"
        case .offline:
            return "La connexion au correcteur a été interrompue. Réessaie dans un instant."
        }
    }
}

/// `gradeMathAnswer` : envoie la question et la réponse au relais.
enum CollGradingService {
    /// `QUESTION_CORRECTION_REQUEST_TIMEOUT_MS` de `utils/correctionPerformance.ts`.
    static let requestTimeout: TimeInterval = 95

    /// Notation d'une question de colle. `exercise` porte le chapitre, `program`
    /// borne les méthodes admises.
    static func grade(
        question: CollRemainingQuestion,
        chapterName: String,
        program: String,
        token: String?
    ) async throws -> CollMathGrade {
        let input = CollGradeAnswerInput(
            exercise: "Colle — \(chapterName)",
            question: question.prompt,
            answer: question.answer,
            program: program,
            statement: question.prompt
        )
        return try await CollGradingRequest.gradeAnswer(input: input, token: token)
    }

    /// `gradeRequestBody` : mêmes clés et même échelle que la source.
    static func requestBody(
        exercise: String,
        question: String,
        answer: String,
        program: String
    ) throws -> Data {
        try requestBody(CollGradeAnswerInput(
            exercise: exercise,
            question: question,
            answer: answer,
            program: program,
            statement: question
        ))
    }

    /// `gradeRequestBody` : corps complet, les champs facultatifs absents ne sont
    /// pas sérialisés (comme `JSON.stringify` d'`undefined`).
    static func requestBody(_ input: CollGradeAnswerInput) throws -> Data {
        var payload: [String: Any] = [
            "action": "grade-answer",
            "gradingScaleVersion": 2,
            "exercise": input.exercise,
            "question": input.question,
            "answer": input.answer,
            "mimeType": "image/jpeg",
        ]
        if let program = input.program { payload["program"] = program }
        if let statement = input.statement { payload["statement"] = statement }
        if let image = input.statementImage { payload["statementImage"] = image }
        if let image = input.correctionImage { payload["correctionImage"] = image }
        if let correction = input.correction { payload["correction"] = correction }
        if let guidance = input.gradingGuidance { payload["gradingGuidance"] = guidance.jsonObject }
        do {
            return try JSONSerialization.data(withJSONObject: payload, options: [])
        } catch {
            throw CollGradingError.relay(
                "Correction automatique indisponible. Réessaie.", status: nil
            )
        }
    }

    /// `requestGrade` : `POST /relay`, authentifié par la session Duello.
    static func post(body: Data, token: String?) async throws -> Data {
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
                throw CollGradingError.offline
            }
            return try validate(data: data, status: http.statusCode)
        } catch let error as CollGradingError {
            throw error
        } catch let error as URLError where error.code == .timedOut {
            throw CollGradingError.timeout
        } catch {
            throw CollGradingError.offline
        }
    }

    /// `readGradeResponse` : refus d'authentification, réponse illisible, verdict
    /// inconnu et commentaire de repli, mot pour mot de la source.
    static func readResponse(_ data: Data) throws -> CollMathGrade {
        guard let object = try? JSONSerialization.jsonObject(with: data),
              let payload = object as? [String: Any]
        else { throw CollGradingError.relay("Réponse illisible du correcteur", status: nil) }

        guard let rawVerdict = payload["verdict"] as? String,
              let verdict = CollVerdict(rawValue: rawVerdict)
        else { throw CollGradingError.relay("Réponse inattendue du correcteur", status: nil) }

        let feedback = (payload["feedback"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return CollMathGrade(
            verdict: verdict,
            feedback: feedback.isEmpty
                ? "Le correcteur n’a pas fourni de commentaire."
                : feedback,
            correction: payload["correction"] as? String ?? "",
            reviewedAt: CollCompletion.now()
        )
    }

    /// Statuts et verdict : 401/403 sortent l'élève de session, tout autre non-2xx
    /// est une panne du service, 502/503 seront retentés (`isTransientCorrectionError`).
    private static func validate(data: Data, status: Int) throws -> Data {
        if status == 401 || status == 403 { throw CollGradingError.authentication }
        guard (200..<300).contains(status) else {
            var message = ""
            if let object = try? JSONSerialization.jsonObject(with: data),
               let payload = object as? [String: Any],
               let raw = payload["error"] as? String {
                message = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            throw CollGradingError.relay(
                message.isEmpty ? "Correcteur indisponible (\(status))" : message,
                status: status
            )
        }
        return data
    }
}
