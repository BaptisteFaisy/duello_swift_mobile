//
//  ExGGradingScore.swift
//  Duello
//
//  Notation pondérée d'un exercice ou d'une annale (`utils/gradingScore.ts`).
//
//  Fichiers source Expo portés (libellés repris mot pour mot) :
//    - src/utils/gradingScore.ts
//        `ScoredVerdict`, `ScoredQuestion`, `calculateScore` (regroupement par
//        `groupId ?? id`, meilleur coefficient), `calculateAnnaleScore`
//        (dédup des choix alternatifs d'un même `alternativeGroupId`) et
//        `gradeEvolutionTone`.
//
//  Déjà portés ailleurs (non repris ici) : `VERDICT_SCORE_COEFFICIENT`
//  (`CollVerdict.scoreCoefficient`), `GradingScore` réduit (`CollGradingScore`),
//  `formatGradingScore` (`ExGFormat.score`), `gradingScoreRemark` et
//  `roundScore` (`ExGGrading`), `calculateColleScore` (`CollGradingScore.colle`).
//
//  Cible : iOS 16, aucune dépendance externe.
//
import Foundation

// MARK: - Verdicts notés

/// `ScoredVerdict` de `utils/gradingScore.ts`.
enum ExGScoredVerdict: String {
    case perfect, correct, partial, incorrect

    /// `VERDICT_SCORE_COEFFICIENT` : parfait 1, correct 0,8, partiel 0,4,
    /// incorrect 0.
    var coefficient: Double {
        switch self {
        case .perfect: return 1
        case .correct: return 0.8
        case .partial: return 0.4
        case .incorrect: return 0
        }
    }
}

// MARK: - Entrée et résultat

/// `ScoredQuestion` de `utils/gradingScore.ts` : question réduite à ce que la
/// note pondérée consomme.
struct ExGScoredQuestion {
    var id: String
    var groupId: String?
    var points: Double?
    var verdict: ExGScoredVerdict?
    var complete: Bool
}

/// `GradingScore` : note pondérée sur 20, ou `nil` sans question corrigée.
struct ExGGradingScore: Equatable {
    var scoreOn20: Double?
    var earnedPoints: Double
    var possiblePoints: Double
    var gradedPoints: Double
    var totalQuestions: Int
    var gradedQuestions: Int
    var complete: Bool
}

// MARK: - Calculs

/// `calculateScore` et `calculateAnnaleScore` de `utils/gradingScore.ts`.
enum ExGGradingScoreCalculator {
    /// `calculateScore` : les choix alternatifs d'un même groupe comptent pour
    /// une seule question ; le meilleur coefficient corrigé l'emporte.
    static func calculate(_ questions: [ExGScoredQuestion]) -> ExGGradingScore {
        var groups: [String: [ExGScoredQuestion]] = [:]
        var order: [String] = []
        for question in questions {
            let key = question.groupId ?? question.id
            if groups[key] == nil { order.append(key) }
            groups[key, default: []].append(question)
        }

        var earnedPoints = 0.0
        var possiblePoints = 0.0
        var gradedPoints = 0.0
        var gradedQuestions = 0
        var complete = !groups.isEmpty

        for key in order {
            let group = groups[key] ?? []
            let points = group.map { positivePoints($0.points) }.max() ?? 1
            let graded = group.filter { $0.verdict != nil }
            let coefficient = bestCoefficient(graded)
            let groupComplete = group.contains { $0.complete }
                || group.allSatisfy { $0.verdict != nil }
            possiblePoints += points
            earnedPoints += points * coefficient
            if !graded.isEmpty {
                gradedPoints += points
                gradedQuestions += 1
            }
            complete = complete && groupComplete
        }

        return ExGGradingScore(
            scoreOn20: gradedPoints > 0 && possiblePoints > 0
                ? roundScore((earnedPoints / possiblePoints) * 20)
                : nil,
            earnedPoints: earnedPoints,
            possiblePoints: possiblePoints,
            gradedPoints: gradedPoints,
            totalQuestions: groups.count,
            gradedQuestions: gradedQuestions,
            complete: complete
        )
    }

    /// `calculateAnnaleScore` : note d'une annale ; les variantes d'un même
    /// `alternativeGroupId` comptent pour une seule question.
    static func annale(attempt: AnnAttempt?, questions: [AnnQuestion]) -> ExGGradingScore {
        let scored = questions.map { question -> ExGScoredQuestion in
            let review = attempt?.reviews[question.id]
            let answered = isAnswered(attempt?.answers[question.id])
            let key = question.alternativeGroupId ?? question.id
            let members = questions.filter { ($0.alternativeGroupId ?? $0.id) == key }
            let validated = members.contains { candidate in
                candidate.id != question.id
                    ? (attempt?.reviews[candidate.id]?.verdict.isValidated ?? false)
                    : (review?.verdict.isValidated ?? false)
            }
            let groupComplete = validated || members.allSatisfy { candidate in
                isAnswered(attempt?.answers[candidate.id])
                    && attempt?.reviews[candidate.id] != nil
            }
            let verdict = review.flatMap { ExGScoredVerdict(rawValue: $0.verdict.rawValue) }
            return ExGScoredQuestion(
                id: question.id,
                groupId: question.alternativeGroupId,
                points: question.points,
                verdict: verdict,
                complete: answered && groupComplete
            )
        }
        return calculate(scored)
    }

    /// `positivePoints` : barème strictement positif, sinon un point.
    private static func positivePoints(_ value: Double?) -> Double {
        guard let value, value.isFinite, value > 0 else { return 1 }
        return value
    }

    /// `bestCoefficient` : meilleur coefficient parmi les questions corrigées,
    /// `0` quand aucune ne l'est.
    private static func bestCoefficient(_ group: [ExGScoredQuestion]) -> Double {
        group.compactMap { $0.verdict?.coefficient }.max() ?? 0
    }

    /// `roundScore` : note bornée `[0, 20]`, arrondie au dixième.
    private static func roundScore(_ value: Double) -> Double {
        guard value.isFinite else { return 0 }
        return (min(20, max(0, value)) * 10).rounded() / 10
    }

    /// Une réponse blanche vaut non répondue (`Boolean(answer?.trim())`).
    private static func isAnswered(_ answer: String?) -> Bool {
        !(answer ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

// MARK: - Ton d'évolution

/// `gradeEvolutionTone` de `utils/gradingScore.ts` : sens d'un taux
/// d'évolution, qui décide de la couleur de son badge.
enum ExGGradeEvolutionTone: String {
    case rising, steady, falling
}

/// `gradeEvolutionTone` : pile à zéro, la note n'a ni progressé ni reculé — le
/// badge reste neutre au lieu de sonner l'alarme.
func exgGradeEvolutionTone(_ percentage: Double) -> ExGGradeEvolutionTone {
    if percentage == 0 { return .steady }
    return percentage > 0 ? .rising : .falling
}
