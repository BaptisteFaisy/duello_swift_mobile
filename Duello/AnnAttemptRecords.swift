//
//  AnnAttemptRecords.swift
//  Duello
//
//  Port de `src/utils/annaleAttempt.ts` — bilans :
//  `recordAnnaleScoreSubmission`, `recordAnnaleMetricRank`,
//  `haveSameAnnaleVerdicts` — et de `src/utils/xp.ts`
//  (`questionXpForDifficulty`, consommé par le bilan du lecteur).
//
//  Cible : iOS 16, aucune API iOS 17.
//
import Foundation

/// `questionXpForDifficulty` (`xp.ts`) : gain d'une question juste selon la
/// difficulté du sujet ; une réussite en rejeu en rapporte un cinquième.
///
/// `XP_RULES.questionCorrectByDifficulty` de `xp.ts` n'est porté nulle part
/// ailleurs (`ExGXpFoundation.swift` ne porte que la courbe de niveaux et le
/// barème des bonus) : le barème des questions vit ici, près du bilan qui le
/// consomme (`finishSubmittedBatch`).
func annaleQuestionXp(difficulty: Int, replay: Bool = false) -> Double {
    let byDifficulty: [Int: Double] = [1: 10, 2: 15, 3: 25, 4: 40, 5: 60, 6: 60]
    let initial = byDifficulty[difficulty] ?? byDifficulty[3] ?? 25
    guard replay else { return initial }
    // `Math.round(initial * questionReplayFactor * 10) / 10`.
    return (initial * 0.2 * 10).rounded() / 10
}

/// Variation de note en pourcentage (`improvementPercentage`).
func annaleImprovementPercentage(previous: Double?, next: Double) -> Int? {
    guard let previous else { return nil }
    if previous == 0 { return next == 0 ? 0 : 100 }
    return annJSRound(((next - previous) / previous) * 100)
}

/// Enregistre localement un bilan sans effacer l'historique lors d'une reprise.
func recordAnnaleScoreSubmission(
    attempt: AnnAttempt,
    metrics: AnnScoreMetrics
) -> AnnScoreSubmission {
    let normalizedScore = gradingScore(metrics.score) ?? 0
    let previousScore = gradingScore(attempt.lastSubmittedScore)
    let attemptNumber = positiveCount(attempt.scoreSubmissionCount) + 1
    let previousBest = gradingScore(attempt.bestSubmittedScore)
    let improvesBest = previousBest == nil || normalizedScore > previousBest!
    let bestScore = improvesBest ? normalizedScore : previousBest!
    let entry = AnnMetricHistoryEntry(
        submissionId: metrics.submissionId,
        submittedAt: metrics.submittedAt,
        score: normalizedScore,
        spentSeconds: positiveCount(metrics.spentSeconds),
        wrongAnswers: positiveCount(metrics.wrongAnswers),
        submissionCounts: metrics.submissionCounts,
        xp: finiteNonNegative(metrics.xp),
        firstTry: metrics.firstTry,
        attemptNumber: attemptNumber,
        improvementPercentage: annaleImprovementPercentage(
            previous: previousScore,
            next: normalizedScore
        ),
        rank: nil
    )
    var history = attempt.metricHistory ?? []
    if !history.contains(where: { $0.submissionId == metrics.submissionId }) {
        history.append(entry)
    }
    var updated = attempt
    updated.lastSubmittedScore = normalizedScore
    updated.scoreSubmissionCount = attemptNumber
    updated.bestSubmittedScore = bestScore
    if improvesBest { updated.bestSubmittedAt = metrics.submittedAt }
    updated.metricHistory = history
    updated.updatedAt = metrics.submittedAt
    return AnnScoreSubmission(
        attempt: updated,
        previousScore: previousScore,
        attemptNumber: attemptNumber,
        bestScore: bestScore
    )
}

/// Ajoute au bilan le rang renvoyé après la publication, sans créer de doublon.
func recordAnnaleMetricRank(
    attempt: AnnAttempt,
    submissionId: String,
    rank: Int?
) -> AnnAttempt {
    guard let rank, rank != 0 else { return attempt }
    var changed = false
    let history = (attempt.metricHistory ?? []).map { entry -> AnnMetricHistoryEntry in
        if entry.submissionId != submissionId || entry.rank == rank { return entry }
        changed = true
        var copy = entry
        copy.rank = rank
        return copy
    }
    guard changed else { return attempt }
    var updated = attempt
    updated.metricHistory = history
    return updated
}

/// Vrai si les deux tentatives affichent le même résumé dans la liste des sujets
/// (`haveSameAnnaleVerdicts`).
func haveSameAnnaleVerdicts(previous: AnnAttempt?, next: AnnAttempt?) -> Bool {
    if previous == nil && next == nil { return true }
    guard let previous, let next else { return false }
    if previous.itemId != next.itemId { return false }
    if previous.bestSubmittedScore != next.bestSubmittedScore { return false }

    let previousAnsweredIds = answeredIds(previous.answers)
    let nextAnsweredIds = Set(answeredIds(next.answers))
    if previousAnsweredIds.count != nextAnsweredIds.count { return false }
    if previousAnsweredIds.contains(where: { !nextAnsweredIds.contains($0) }) { return false }

    if previous.reviews.count != next.reviews.count { return false }
    return previous.reviews.allSatisfy { key, review in
        next.reviews[key]?.verdict == review.verdict
    }
}

/// Questions dont la réponse écrite n'est pas vide (`haveSameAnnaleVerdicts`).
func answeredIds(_ answers: [String: String]) -> [String] {
    answers.compactMap { key, value in
        value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : key
    }
}
