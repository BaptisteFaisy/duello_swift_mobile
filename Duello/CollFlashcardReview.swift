//
//  CollFlashcardReview.swift
//  Duello
//
//  Règles de révision des cartes d'un cours : cartes vues, objectif de réussite
//  et verdicts.
//
//  Fichiers source Expo portés :
//    - src/utils/courseFlashcards.ts
//        `courseFlashcardsSeenSoFar`, `prepareCourseFlashcardForReview`,
//        `isCourseFlashcardMastered`, `courseFlashcardMasteryPercentage`,
//        `courseFlashcardSessionCounts`, `recordCourseFlashcardVerdict`.
//
//  Cible : iOS 16, aucune dépendance externe.
//
import Foundation

/// Décompte d'une session (`FlashcardSessionCounts`).
struct CollFlashcardSessionCounts: Equatable {
    var correct: Int = 0
    var partial: Int = 0
    var wrong: Int = 0
}

/// `courseFlashcardsSeenSoFar` et les règles d'objectif par carte.
enum CollFlashcardReview {
    /// `courseFlashcardsSeenSoFar` : cartes révisables au point atteint. Les
    /// cartes manuelles et les anciennes cartes sans position restent
    /// accessibles ; si aucune carte positionnée n'est débloquée alors que le
    /// repère est avancé, la première notion estimée est débloquée seule.
    static func seenSoFar(_ cards: [CollFlashcard], coursePosition: Double) -> [CollFlashcard] {
        let position = min(1, max(0, coursePosition))
        let seen = cards.filter { card in
            card.origin == .user || card.sourcePosition == nil || (card.sourcePosition ?? 1) <= position
        }
        let positionedGenerated = cards.filter { $0.origin != .user && $0.sourcePosition != nil }
        let hasPositionedGenerated = seen.contains { $0.origin != .user && $0.sourcePosition != nil }
        if position <= 0 || hasPositionedGenerated || positionedGenerated.isEmpty {
            return seen
        }

        let firstPosition = positionedGenerated.map { $0.sourcePosition ?? 1 }.min() ?? 1
        guard let firstCard = positionedGenerated.first(where: { $0.sourcePosition == firstPosition }),
              !seen.contains(where: { $0.id == firstCard.id })
        else { return seen }
        return seen + [firstCard]
    }

    /// `prepareCourseFlashcardForReview` : remet l'objectif à zéro pour une
    /// nouvelle session.
    static func prepareForReview(_ card: CollFlashcard, forceThreeCorrect: Bool = false) -> CollFlashcard {
        var updated = card
        updated.correctStreak = 0
        updated.requiredCorrect = (forceThreeCorrect || card.verdict == .wrong) ? 3 : 2
        return updated
    }

    /// `isCourseFlashcardMastered`.
    static func isMastered(_ card: CollFlashcard) -> Bool {
        (card.correctStreak ?? 0) >= (card.requiredCorrect ?? 2)
    }

    /// `courseFlashcardMasteryPercentage` : part des cartes réussies, arrondie.
    static func masteryPercentage(_ cards: [CollFlashcard]) -> Int {
        guard !cards.isEmpty else { return 0 }
        let mastered = cards.filter { $0.verdict == .correct }.count
        return Int((Double(mastered) / Double(cards.count) * 100).rounded())
    }

    /// `courseFlashcardSessionCounts` : chaque carte comptée une seule fois.
    static func sessionCounts(_ verdicts: [String: CollFlashcardVerdict]) -> CollFlashcardSessionCounts {
        var counts = CollFlashcardSessionCounts()
        for verdict in verdicts.values {
            switch verdict {
            case .correct: counts.correct += 1
            case .partial: counts.partial += 1
            case .wrong: counts.wrong += 1
            }
        }
        return counts
    }

    /// `recordCourseFlashcardVerdict` : applique une réponse et conserve l'échec
    /// jusqu'à maîtrise complète.
    static func recordVerdict(
        _ card: CollFlashcard,
        verdict: CollFlashcardVerdict,
        seenAt: Double
    ) -> CollFlashcard {
        var updated = card
        updated.seenAt = seenAt
        guard verdict == .correct else {
            updated.verdict = verdict
            updated.correctStreak = 0
            updated.requiredCorrect = 3
            return updated
        }
        let required = card.requiredCorrect ?? (card.verdict == .wrong ? 3 : 2)
        let streak = min(required, (card.correctStreak ?? 0) + 1)
        updated.verdict = streak >= required ? .correct : (card.verdict == .wrong ? .wrong : .partial)
        updated.correctStreak = streak
        updated.requiredCorrect = required
        return updated
    }
}
