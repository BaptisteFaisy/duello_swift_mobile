//
//  CollFlashcardSession.swift
//  Duello
//
//  Construction d'une session de révision : sélection des cartes, ordre,
//  mélange et réunion de plusieurs chapitres.
//
//  Fichiers source Expo portés :
//    - src/utils/courseFlashcards.ts
//        `orderCourseFlashcards`, `shuffledCopy`, `courseFlashcardReviewEntryKey`,
//        `courseFlashcardReviewSessionForChapters`, `pendingCourseFlashcards`,
//        `courseFlashcardReviewSession`.
//
//  Cible : iOS 16, aucune dépendance externe.
//
import Foundation

/// `orderCourseFlashcards`, `pendingCourseFlashcards` et
/// `courseFlashcardReviewSession`.
enum CollFlashcardSession {
    /// `orderCourseFlashcards` : paquet `nil` = toutes les cartes.
    static func order(_ cards: [CollFlashcard], deck: String?, shuffle: Bool) -> [CollFlashcard] {
        let selected = cards.filter { deck == nil || $0.deck == deck }
        return shuffle ? shuffled(selected) : selected
    }

    /// `courseFlashcardReviewEntryKey` : identité stable d'une carte dans une
    /// session qui peut réunir plusieurs chapitres (`JSON.stringify([id, card])`).
    static func reviewEntryKey(chapterId: String, cardId: String) -> String {
        "[\"\(chapterId)\",\"\(cardId)\"]"
    }

    /// `courseFlashcardReviewSessionForChapters` : réunit les cartes révisables
    /// des chapitres choisis, dans l'ordre du programme, sans perdre leur origine.
    static func reviewSessionForChapters(
        sources: [CollFlashcardChapterSource],
        selectedChapterIds: [String],
        deck: String?,
        shuffle: Bool
    ) -> [CollFlashcardReviewEntry] {
        let selected = Set(selectedChapterIds)
        let entries = sources.flatMap { source -> [CollFlashcardReviewEntry] in
            guard selected.contains(source.chapterId) else { return [] }
            return CollFlashcardReview.seenSoFar(source.document.cards, coursePosition: source.coursePosition)
                .filter { deck == nil || $0.deck == deck }
                .map { card in
                    CollFlashcardReviewEntry(
                        key: reviewEntryKey(chapterId: source.chapterId, cardId: card.id),
                        chapterId: source.chapterId,
                        chapterName: source.chapterName,
                        subject: source.subject,
                        card: card
                    )
                }
        }
        return shuffle ? shuffled(entries) : entries
    }

    /// `pendingCourseFlashcards` : une session continue jusqu'à ce que toutes les
    /// cartes sélectionnées soient réussies.
    static func pending(_ cards: [CollFlashcard], deck: String?, shuffle: Bool) -> [CollFlashcard] {
        order(cards, deck: deck, shuffle: shuffle).filter { $0.verdict != .correct }
    }

    /// `courseFlashcardReviewSession` : démarre une révision avec toute la
    /// sélection du cours déjà vu.
    static func reviewSession(_ cards: [CollFlashcard], deck: String?, shuffle: Bool) -> [CollFlashcard] {
        order(cards, deck: deck, shuffle: shuffle)
    }

    /// `shuffledCopy` : mélange de Fisher-Yates, sans dépendance externe.
    static func shuffled<Value>(_ values: [Value]) -> [Value] {
        var result = values
        guard result.count > 1 else { return result }
        for index in stride(from: result.count - 1, through: 1, by: -1) {
            result.swapAt(index, Int.random(in: 0...index))
        }
        return result
    }
}
