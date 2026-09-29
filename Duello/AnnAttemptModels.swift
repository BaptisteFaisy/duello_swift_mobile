//
//  AnnAttemptModels.swift
//  Duello
//
//  Port de `src/utils/annaleAttempt.ts` — types et fabrique.
//
//  Adaptations imposées :
//  - `AnnaleQuestionVerdict` réutilise `AnnVerdict` (`AnnAnnalesModels.swift`,
//    perfect/correct/partial/incorrect, `isValidated` = perfect|correct).
//  - `AnnaleQuestionReview` → `AnnQuestionReview`, `AnnaleMetricHistoryEntry` →
//    `AnnMetricHistoryEntry`, `AnnaleAttempt` → `AnnAttempt`,
//    `AnnaleAttemptMap` → `AnnAttemptMap`,
//    `AnnaleScoreSubmission`/`AnnaleScoreMetrics` → `AnnScoreSubmission`/
//    `AnnScoreMetrics`.
//  - `AnnaleQuestion` porte `legacyId` ET `previousId` ; `StmtQuestion`
//    (`StmtModels.swift`) ne porte que `legacyId` : `AnnAttemptQuestionRef`
//    rassemble les deux pour `migrateAnnaleAttemptQuestionIds`.
//
//  Cible : iOS 16, aucune API iOS 17.
//
import Foundation

// MARK: - Revue

/// Origine d'une revue (`AnnaleQuestionReview.source`).
enum AnnReviewSource: String, Codable {
    case automatic
    case `self`
}

/// Revue d'une question d'annale (`AnnaleQuestionReview`).
struct AnnQuestionReview: Codable, Equatable {
    var verdict: AnnVerdict
    var feedback: String
    /// Corrigé ciblé sur cette question, dévoilé indépendamment des autres.
    var correction: String?
    var source: AnnReviewSource
    var reviewedAt: String
}

// MARK: - Métriques

/// Métriques figées lors d'un bilan terminé, conservées sans limite par compte.
struct AnnMetricHistoryEntry: Codable, Equatable {
    /// Identifiant idempotent de la soumission qui a produit ce bilan.
    var submissionId: String
    var submittedAt: String
    var score: Double
    var spentSeconds: Int
    var wrongAnswers: Int
    var submissionCounts: [String: Int]
    var xp: Double
    var firstTry: Bool
    var attemptNumber: Int
    var improvementPercentage: Int?
    var rank: Int?
}

// MARK: - Tentative

/// Copie d'un sujet d'annale (`AnnaleAttempt`).
struct AnnAttempt: Codable, Equatable {
    var itemId: String
    /// Vrai lorsque la copie a été remise à zéro après une réussite complète.
    var replay: Bool?
    var answers: [String: String]
    var reviews: [String: AnnQuestionReview]
    var updatedAt: String
    /// Temps de travail cumulé sur ce sujet, à travers les sessions.
    var spentSeconds: Int?
    /// Verdicts non justes déjà rendus sur ce sujet, questions confondues.
    var wrongAnswers: Int?
    /// Nombre de corrections effectivement rendues, question par question.
    var submissionCounts: [String: Int]?
    /// Note du dernier bilan terminé, utilisée pour comparer deux corrections.
    var lastSubmittedScore: Double?
    /// Nombre de bilans complets envoyés pour ce sujet.
    var scoreSubmissionCount: Int?
    /// Meilleure note locale, le classement partagé restant l'autorité publique.
    var bestSubmittedScore: Double?
    /// Date d'obtention de la meilleure note locale.
    var bestSubmittedAt: String?
    /// Tous les bilans successifs, du plus ancien au plus récent.
    var metricHistory: [AnnMetricHistoryEntry]?
}

typealias AnnAttemptMap = [String: AnnAttempt]

/// Référence de question pour la migration des identifiants
/// (`AnnaleQuestion` côté Expo porte `legacyId` ET `previousId`).
struct AnnAttemptQuestionRef {
    var id: String
    var legacyId: String?
    var previousId: String?
}

/// Résultat d'un enregistrement de bilan (`AnnaleScoreSubmission`).
struct AnnScoreSubmission {
    var attempt: AnnAttempt
    var previousScore: Double?
    var attemptNumber: Int
    var bestScore: Double
}

/// Métriques d'une soumission de bilan (`AnnaleScoreMetrics`).
struct AnnScoreMetrics {
    var submissionId: String
    var submittedAt: String
    var score: Double
    var spentSeconds: Int
    var wrongAnswers: Int
    var submissionCounts: [String: Int]
    var xp: Double
    var firstTry: Bool
}

// MARK: - Fabrique et utilitaires

/// Tentative vide (`emptyAnnaleAttempt`).
func emptyAnnaleAttempt(itemId: String) -> AnnAttempt {
    AnnAttempt(
        itemId: itemId,
        replay: false,
        answers: [:],
        reviews: [:],
        updatedAt: annNowISOString(),
        spentSeconds: 0,
        wrongAnswers: 0,
        submissionCounts: [:],
        scoreSubmissionCount: 0,
        metricHistory: []
    )
}

/// Horodatage ISO 8601 en UTC, forme de `new Date().toISOString()`.
func annNowISOString(_ date: Date = Date()) -> String {
    let formatter = ISO8601DateFormatter()
    formatter.timeZone = TimeZone(identifier: "UTC")
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter.string(from: date)
}

/// Lit un nombre JSON quel que soit son type numérique (`NSNumber` bridgé).
func annNumber(_ value: Any?) -> Double? {
    // `typeof value === 'number'` : un booléen JSON n'est pas un nombre, et ne
    // doit donc pas valoir 1 (ce que ferait le pont `NSNumber`).
    if value is Bool { return nil }
    if let number = value as? NSNumber { return number.doubleValue }
    if let double = value as? Double { return double }
    if let int = value as? Int { return Double(int) }
    return nil
}

/// Arrondi de `Math.round` : la moitié va vers +∞, pas vers le zéro le plus
/// proche (les améliorations négatives en dépendent).
func annJSRound(_ value: Double) -> Int {
    Int((value + 0.5).rounded(.down))
}
