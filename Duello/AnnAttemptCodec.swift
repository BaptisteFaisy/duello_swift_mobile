//
//  AnnAttemptCodec.swift
//  Duello
//
//  Port de `src/utils/annaleAttempt.ts` — primitives de lecture tolérante :
//  `positiveCount`, `finiteNonNegative`, `gradingScore`, `isReview` et les
//  filtres de dictionnaires (`answers`, `reviews`, `submissionCounts`).
//
//  Cible : iOS 16, aucune API iOS 17.
//
import Foundation

/// Entier strictement positif, arrondi, `0` sinon (`positiveCount`).
func positiveCount(_ value: Any?) -> Int {
    guard let number = annNumber(value), number.isFinite, number > 0 else { return 0 }
    return annJSRound(number)
}

/// Nombre fini et positif, `0` sinon (`finiteNonNegative`).
func finiteNonNegative(_ value: Any?) -> Double {
    guard let number = annNumber(value), number.isFinite, number >= 0 else { return 0 }
    return number
}

/// Vrai si la chaîne est une date ISO parsable (`Number.isFinite(Date.parse(s))`).
func isParsableDate(_ value: Any?) -> Bool {
    guard let string = value as? String else { return false }
    let withFraction = ISO8601DateFormatter()
    withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if withFraction.date(from: string) != nil { return true }
    let plain = ISO8601DateFormatter()
    plain.formatOptions = [.withInternetDateTime]
    return plain.date(from: string) != nil
}

/// Note bornée à `0..20`, arrondie au dixième, `nil` sinon (`gradingScore`).
func gradingScore(_ value: Any?) -> Double? {
    guard let number = annNumber(value),
          number.isFinite, number >= 0, number <= 20
    else { return nil }
    return Double(annJSRound(number * 10)) / 10
}

/// Construit une revue si la forme est valide (`AnnaleQuestionReview`).
func parseReview(_ value: Any?) -> AnnQuestionReview? {
    guard let dict = value as? [String: Any] else { return nil }
    guard let rawVerdict = dict["verdict"] as? String,
          let verdict = AnnVerdict(rawValue: rawVerdict),
          let feedback = dict["feedback"] as? String
    else { return nil }
    var correction: String? = nil
    if let rawCorrection = dict["correction"] {
        guard let text = rawCorrection as? String else { return nil }
        correction = text
    }
    guard let rawSource = dict["source"] as? String,
          let source = AnnReviewSource(rawValue: rawSource),
          let reviewedAt = dict["reviewedAt"] as? String
    else { return nil }
    return AnnQuestionReview(
        verdict: verdict,
        feedback: feedback,
        correction: correction,
        source: source,
        reviewedAt: reviewedAt
    )
}

/// Valide une revue (`isReview`), en réutilisant `parseReview`.
func isReview(_ value: Any?) -> Bool {
    parseReview(value) != nil
}

/// Dictionnaire de chaînes, entrées non textuelles écartées.
func stringMap(_ value: Any?) -> [String: String] {
    guard let dict = value as? [String: Any] else { return [:] }
    var result: [String: String] = [:]
    for (key, raw) in dict {
        if let text = raw as? String { result[key] = text }
    }
    return result
}

/// Compteurs positifs par question, entrées nulles écartées
/// (`submissionCounts`).
func positiveCountMap(_ value: Any?) -> [String: Int] {
    guard let dict = value as? [String: Any] else { return [:] }
    var result: [String: Int] = [:]
    for (key, raw) in dict {
        let count = positiveCount(raw)
        if count > 0 { result[key] = count }
    }
    return result
}

/// Revues valides par question, entrées invalides écartées.
func reviewMap(_ value: Any?) -> [String: AnnQuestionReview] {
    guard let dict = value as? [String: Any] else { return [:] }
    var result: [String: AnnQuestionReview] = [:]
    for (key, raw) in dict {
        if let review = parseReview(raw) { result[key] = review }
    }
    return result
}
