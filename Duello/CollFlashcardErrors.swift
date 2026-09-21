//
//  CollFlashcardErrors.swift
//  Duello
//
//  Page « Mes erreurs » du chapitre : cartes échouées, récurrence par type et
//  classement.
//
//  Fichiers source Expo portés :
//    - src/utils/courseFlashcards.ts
//        `CourseErrorSort`, `courseFlashcardErrors`,
//        `courseFlashcardErrorCounts`, `courseFlashcardErrorsOfDeck`,
//        `sortCourseFlashcardErrors`.
//
//  Cible : iOS 16, aucune dépendance externe.
//
import Foundation

/// Classements proposés dans « Mes erreurs » (`CourseErrorSort`).
enum CollErrorSort: String, CaseIterable {
    case recent
    case type
    case recurrence
}

/// `courseFlashcardErrors` et son classement.
enum CollFlashcardErrors {
    /// `courseFlashcardErrors` : cartes échouées.
    static func errors(_ cards: [CollFlashcard]) -> [CollFlashcard] {
        cards.filter { $0.verdict == .wrong }
    }

    /// `courseFlashcardErrorCounts` : nombre d'erreurs par type, qui mesure la
    /// récurrence du type chez l'élève.
    static func errorCounts(_ cards: [CollFlashcard]) -> [String: Int] {
        var counts: [String: Int] = [:]
        for card in errors(cards) {
            counts[card.deck, default: 0] += 1
        }
        return counts
    }

    /// `courseFlashcardErrorsOfDeck` : erreurs d'un seul type, ou toutes, sans
    /// changer l'ordre reçu.
    static func errorsOfDeck(_ cards: [CollFlashcard], deck: String?) -> [CollFlashcard] {
        errors(cards).filter { deck == nil || $0.deck == deck }
    }

    /// `sortCourseFlashcardErrors` : les plus récentes d'abord, par type dans
    /// l'ordre des paquets, ou par récurrence du type. Les égalités gardent
    /// l'ordre d'origine.
    static func sorted(
        _ cards: [CollFlashcard],
        sort: CollErrorSort,
        deckOrder: [String] = []
    ) -> [CollFlashcard] {
        let list = errors(cards)
        let counts = errorCounts(cards)
        var positions: [String: Int] = [:]
        for (index, card) in list.enumerated() { positions[card.id] = index }

        return list.sorted { left, right in
            if sort != .recent {
                if sort == .recurrence {
                    let gap = (counts[right.deck] ?? 0) - (counts[left.deck] ?? 0)
                    if gap != 0 { return gap > 0 }
                }
                let rankGap = deckRank(left.deck, order: deckOrder) - deckRank(right.deck, order: deckOrder)
                if rankGap != 0 { return rankGap < 0 }
                if left.deck != right.deck { return left.deck < right.deck }
            }
            let dateGap = (right.seenAt ?? 0) - (left.seenAt ?? 0)
            if dateGap != 0 { return dateGap > 0 }
            return (positions[left.id] ?? 0) < (positions[right.id] ?? 0)
        }
    }

    /// `deckRank` : rang d'un paquet dans l'ordre fourni ; les paquets inconnus
    /// ferment la marche.
    private static func deckRank(_ deck: String, order: [String]) -> Int {
        order.firstIndex(of: deck) ?? order.count
    }
}
