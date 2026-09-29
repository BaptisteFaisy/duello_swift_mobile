//
//  AnnAttemptSanitize.swift
//  Duello
//
//  Port de `src/utils/annaleAttempt.ts` — assainissement :
//  `sanitizeMetricHistoryEntry`, `sanitizeAttempt`, `parseAnnaleAttempts`.
//
//  Cible : iOS 16, aucune API iOS 17.
//
import Foundation

/// Chaîne présente et parsable comme date, `nil` sinon.
func annParsableDateString(_ value: Any?) -> String? {
    guard let string = value as? String, isParsableDate(string) else { return nil }
    return string
}

/// Assainit une entrée d'historique de métriques (`sanitizeMetricHistoryEntry`).
func sanitizeMetricHistoryEntry(_ value: Any?) -> AnnMetricHistoryEntry? {
    guard let candidate = value as? [String: Any] else { return nil }
    guard let rawSubmissionId = candidate["submissionId"] as? String else { return nil }
    let submissionId = rawSubmissionId.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !submissionId.isEmpty else { return nil }
    guard let score = gradingScore(candidate["score"]) else { return nil }
    guard let submittedAt = annParsableDateString(candidate["submittedAt"]) else { return nil }
    var improvementPercentage: Int? = nil
    if let raw = annNumber(candidate["improvementPercentage"]), raw.isFinite {
        improvementPercentage = annJSRound(raw)
    }
    var rank: Int? = nil
    if let raw = annNumber(candidate["rank"]),
       raw.isFinite, raw > 0, raw == raw.rounded() {
        rank = Int(raw)
    }
    return AnnMetricHistoryEntry(
        submissionId: String(submissionId.prefix(240)),
        submittedAt: submittedAt,
        score: score,
        spentSeconds: positiveCount(candidate["spentSeconds"]),
        wrongAnswers: positiveCount(candidate["wrongAnswers"]),
        submissionCounts: positiveCountMap(candidate["submissionCounts"]),
        xp: finiteNonNegative(candidate["xp"]),
        firstTry: (candidate["firstTry"] as? Bool) == true,
        attemptNumber: max(1, positiveCount(candidate["attemptNumber"])),
        improvementPercentage: improvementPercentage,
        rank: rank
    )
}

/// Historique assaini, entrées invalides écartées (`metricHistory`).
func metricHistory(_ value: Any?) -> [AnnMetricHistoryEntry] {
    guard let array = value as? [Any] else { return [] }
    return array.compactMap { sanitizeMetricHistoryEntry($0) }
}

/// Assainit une tentative (`sanitizeAttempt`).
func sanitizeAttempt(_ itemId: String, _ value: Any?) -> AnnAttempt {
    guard let candidate = value as? [String: Any] else {
        return emptyAnnaleAttempt(itemId: itemId)
    }
    return AnnAttempt(
        itemId: itemId,
        replay: (candidate["replay"] as? Bool) == true,
        answers: stringMap(candidate["answers"]),
        reviews: reviewMap(candidate["reviews"]),
        updatedAt: (candidate["updatedAt"] as? String) ?? annNowISOString(),
        // Les brouillons enregistrés avant la mesure du temps repartent de zéro.
        spentSeconds: positiveCount(candidate["spentSeconds"]),
        wrongAnswers: positiveCount(candidate["wrongAnswers"]),
        submissionCounts: positiveCountMap(candidate["submissionCounts"]),
        lastSubmittedScore: gradingScore(candidate["lastSubmittedScore"]),
        scoreSubmissionCount: positiveCount(candidate["scoreSubmissionCount"]),
        bestSubmittedScore: gradingScore(candidate["bestSubmittedScore"]),
        bestSubmittedAt: annParsableDateString(candidate["bestSubmittedAt"]),
        metricHistory: metricHistory(candidate["metricHistory"])
    )
}

/// Relit sans erreur l'instantané sérialisé (`parseAnnaleAttempts`).
func parseAnnaleAttempts(raw: String?) -> AnnAttemptMap {
    guard let raw, !raw.isEmpty, let data = raw.data(using: .utf8) else { return [:] }
    guard let parsed = try? JSONSerialization.jsonObject(with: data),
          let object = parsed as? [String: Any]
    else { return [:] }
    var result: AnnAttemptMap = [:]
    for (itemId, attempt) in object {
        result[itemId] = sanitizeAttempt(itemId, attempt)
    }
    return result
}
