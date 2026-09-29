//
//  CollGradingRequest.swift
//  Duello
//
//  Entrée riche de la notation d'une réponse, boucle de retentative, garde de
//  consentement IA, annulation et enregistrement de la durée
//  (`utils/mathAnswerGrading.ts`).
//
//  Fichier source Expo porté (libellés repris mot pour mot) :
//    - src/utils/mathAnswerGrading.ts
//        `GradeMathAnswerInput`, `RETRY_DELAY_MS`, `isTransientCorrectionError`,
//        `requestGrade` (deux tentatives, `AbortSignal`), `gradeMathAnswer`
//        (`requireAiDataSharingConsent` + `recordCorrectionDuration`).
//
//  Le transport (`post`) et la lecture du verdict vivent dans
//  `CollGradingService.swift` ; ce fichier n'orchestre que la politique.
//  Cible : iOS 16, aucune dépendance externe.
//
import Foundation

/// `ExerciseGradingGuidance` de `data/chapterItems.ts` : conventions fiables de
/// la banque de sujets, transmises au correcteur.
struct CollGradingGuidance: Equatable {
    /// Étapes dont l'absence constitue réellement un trou logique.
    var requiredJustifications: [String]?
    /// Résultats ou gestes de cours admis sans démonstration détaillée.
    var acceptedWithoutDetailedJustification: [String]?
    /// Méthodes ou propriétés hors programme tolérées par le jury, à justifier.
    var acceptedExtraSyllabusFacts: [String]?
    /// Méthodes hors programme acceptées par le jury sans justification.
    var acceptedExtraSyllabusMethodsWithoutJustification: [String]?
    /// Propriétés hors programme acceptées par le jury sans justification.
    var acceptedExtraSyllabusPropertiesWithoutJustification: [String]?

    /// Forme JSON, les listes absentes n'étant pas sérialisées.
    var jsonObject: [String: Any] {
        var object: [String: Any] = [:]
        if let value = requiredJustifications {
            object["requiredJustifications"] = value
        }
        if let value = acceptedWithoutDetailedJustification {
            object["acceptedWithoutDetailedJustification"] = value
        }
        if let value = acceptedExtraSyllabusFacts {
            object["acceptedExtraSyllabusFacts"] = value
        }
        if let value = acceptedExtraSyllabusMethodsWithoutJustification {
            object["acceptedExtraSyllabusMethodsWithoutJustification"] = value
        }
        if let value = acceptedExtraSyllabusPropertiesWithoutJustification {
            object["acceptedExtraSyllabusPropertiesWithoutJustification"] = value
        }
        return object
    }
}

/// `GradeMathAnswerInput` de `utils/mathAnswerGrading.ts`.
struct CollGradeAnswerInput {
    var exercise: String
    var question: String
    var answer: String
    /// Filière, année et option dont le programme borne les méthodes admises.
    var program: String?
    /// Énoncé retranscrit, quand l'exercice n'a pas de corrigé en PDF.
    var statement: String?
    var statementImage: String?
    /// Page de corrigé rendue en image ; absente pour les énoncés retranscrits.
    var correctionImage: String?
    /// Corrigé retranscrit en texte, privilégié sur l'image de corrigé.
    var correction: String?
    var gradingGuidance: CollGradingGuidance?
}

/// Jeton d'annulation (`AbortSignal` de la source) : une soumission quittée ne
/// doit pas continuer à occuper le relais.
final class CollGradingCancellation {
    private(set) var isCancelled = false

    /// `controller.abort()` : marque la notation comme arrêtée.
    func cancel() { isCancelled = true }
}

/// `requestGrade` / `gradeMathAnswer` : politique de la notation d'une réponse.
enum CollGradingRequest {
    /// `RETRY_DELAY_MS` : délai avant la seconde et dernière tentative.
    static let retryDelayMilliseconds = 700

    /// `isTransientCorrectionError` : une panne réseau ou un 502/503 est
    /// retenté une fois ; un délai dépassé ne l'est jamais.
    static func isTransient(_ error: CollGradingError) -> Bool {
        switch error {
        case .relay(_, let status): return status == 502 || status == 503
        case .offline: return true
        default: return false
        }
    }

    /// `requestGrade` : deux tentatives au plus. Un délai dépassé n'est jamais
    /// retenté ; une panne transitoire qui persiste devient `offline`.
    static func run(
        body: Data,
        token: String?,
        cancellation: CollGradingCancellation? = nil
    ) async throws -> CollMathGrade {
        for attempt in 0..<2 {
            if cancellation?.isCancelled == true { throw CollGradingError.cancelled }
            do {
                let data = try await CollGradingService.post(body: body, token: token)
                return try CollGradingService.readResponse(data)
            } catch let error as CollGradingError {
                if cancellation?.isCancelled == true { throw CollGradingError.cancelled }
                guard isTransient(error) else { throw error }
                if attempt == 0 {
                    try? await Task.sleep(nanoseconds: UInt64(retryDelayMilliseconds) * 1_000_000)
                    continue
                }
                throw CollGradingError.offline
            }
        }
        throw CollGradingError.relay(
            "Correction automatique indisponible. Réessaie dans un instant.", status: nil
        )
    }

    /// `gradeMathAnswer` : exige l'accord de partage IA, note la réponse, puis
    /// enregistre la durée réelle (retentative comprise).
    static func gradeAnswer(
        input: CollGradeAnswerInput,
        token: String?,
        cancellation: CollGradingCancellation? = nil
    ) async throws -> CollMathGrade {
        guard CtdAiConsent.isGranted else { throw CollGradingError.consent }
        let body = try CollGradingService.requestBody(input)
        let startedAt = Date().timeIntervalSince1970
        let grade = try await run(body: body, token: token, cancellation: cancellation)
        ConsentCorrectionSeconds.record(seconds: Date().timeIntervalSince1970 - startedAt)
        return grade
    }
}
