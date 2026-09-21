//
//  CollFlashcards.swift
//  Duello
//
//  Cartes de révision d'un cours : paquets, lecture et écriture, génération
//  locale déterministe.
//
//  Fichiers source Expo portés (libellés repris mot pour mot) :
//    - src/utils/courseFlashcards.ts
//        `CourseFlashcard`, `CourseFlashcardsDocument`, `FlashcardDeckDefinition`,
//        `FLASHCARD_DECKS`, `parseCourseFlashcards`, `serializeCourseFlashcards`,
//        `hasGeneratedCourseFlashcards`, `generateCourseFlashcards`,
//        `courseFlashcardDecks`.
//
//  Cible : iOS 16, aucune dépendance externe.
//
import Foundation

/// Verdict d'une carte (`FlashcardVerdict`).
enum CollFlashcardVerdict: String, Codable, CaseIterable {
    case correct
    case partial
    case wrong
}

/// Origine d'une carte (`CourseFlashcard['origin']`).
enum CollFlashcardOrigin: String, Codable {
    case generated
    case user
}

/// Une carte de révision (`CourseFlashcard`).
struct CollFlashcard: Codable, Equatable, Identifiable {
    var id: String
    /// Clé du paquet (`FlashcardDeck`, une chaîne libre).
    var deck: String
    var question: String
    var answer: String
    var verdict: CollFlashcardVerdict? = nil
    var seenAt: Double? = nil
    var origin: CollFlashcardOrigin? = nil
    /// Position de la notion dans le PDF complet, normalisée entre 0 et 1.
    var sourcePosition: Double? = nil
    /// Série de bonnes réponses en cours dans la session de révision.
    var correctStreak: Int? = nil
    /// Objectif courant : deux réussites, ou trois après un échec.
    var requiredCorrect: Int? = nil
}

/// Définition d'un paquet de cartes (`FlashcardDeckDefinition`).
struct CollDeckDefinition: Codable, Equatable, Identifiable {
    var key: String
    var label: String
    var description: String?

    var id: String { key }
}

/// Contenu persisté des cartes d'un chapitre (`CourseFlashcardsDocument`).
struct CollFlashcardsDocument: Codable, Equatable {
    var version: Int
    var generatedAt: Double
    var sourceName: String
    var cards: [CollFlashcard]
    var decks: [CollDeckDefinition]?
}

/// Banque d'un chapitre, avec le contexte d'une révision transversale
/// (`CourseFlashcardChapterSource`).
struct CollFlashcardChapterSource {
    var chapterId: String
    var chapterName: String
    var subject: String
    var coursePosition: Double
    var document: CollFlashcardsDocument
}

/// Carte qualifiée par son chapitre (`CourseFlashcardReviewEntry`).
struct CollFlashcardReviewEntry: Identifiable {
    var key: String
    var chapterId: String
    var chapterName: String
    var subject: String
    var card: CollFlashcard

    var id: String { key }
}

/// `parseCourseFlashcards`, `serializeCourseFlashcards`,
/// `hasGeneratedCourseFlashcards`, `generateCourseFlashcards` et
/// `courseFlashcardDecks`.
enum CollFlashcards {
    /// `FLASHCARD_DECKS` de la source, dans l'ordre.
    static let standardDecks: [CollDeckDefinition] = [
        CollDeckDefinition(key: "definitions", label: "Définitions", description: "Notions et vocabulaire à connaître."),
        CollDeckDefinition(key: "theorems", label: "Propriétés & théorèmes", description: "Hypothèses, résultats et conditions d’application."),
        CollDeckDefinition(key: "proofs", label: "Démonstrations", description: "Démonstrations à savoir restituer étape par étape."),
    ]

    /// `parseCourseFlashcards` : validation tolérante, les cartes invalides sont
    /// écartées une à une ; `nil` si le document ou toutes les cartes sont refusés.
    static func parse(_ raw: String?) -> CollFlashcardsDocument? {
        guard let raw,
              let data = raw.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data),
              let value = object as? [String: Any],
              (value["version"] as? Int) == 1,
              let generatedAt = value["generatedAt"] as? Double,
              let sourceName = value["sourceName"] as? String,
              let rawCards = value["cards"] as? [Any]
        else { return nil }

        let cards = rawCards.compactMap(card(from:))
        guard !cards.isEmpty else { return nil }
        let decks = (value["decks"] as? [Any])?.compactMap(deck(from:))
        return CollFlashcardsDocument(
            version: 1,
            generatedAt: generatedAt,
            sourceName: sourceName,
            cards: cards,
            decks: (decks?.isEmpty == false) ? decks : nil
        )
    }

    /// Une carte valide, ou `nil` (`filter` de la source).
    private static func card(from raw: Any) -> CollFlashcard? {
        guard let value = raw as? [String: Any],
              let id = value["id"] as? String,
              let deck = value["deck"] as? String,
              !deck.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let question = value["question"] as? String,
              let answer = value["answer"] as? String,
              let verdict = decode(value["verdict"], nullish: true, { text in
                  (text as? String).flatMap(CollFlashcardVerdict.init(rawValue:))
              }),
              let seenAt = decode(value["seenAt"], nullish: true, { $0 as? Double }),
              let origin = decode(value["origin"], nullish: false, { text in
                  (text as? String).flatMap(CollFlashcardOrigin.init(rawValue:))
              }),
              let sourcePosition = decode(value["sourcePosition"], nullish: false, { (raw: Any) -> Double? in
                  guard let number = raw as? Double, number.isFinite,
                        number >= 0, number <= 1 else { return nil }
                  return number
              }),
              let correctStreak = decode(value["correctStreak"], nullish: false, { (raw: Any) -> Int? in
                  guard let number = raw as? Int, number >= 0, number <= 3 else { return nil }
                  return number
              }),
              let requiredCorrect = decode(value["requiredCorrect"], nullish: false, { (raw: Any) -> Int? in
                  guard let number = raw as? Int, number == 2 || number == 3 else { return nil }
                  return number
              })
        else { return nil }
        return CollFlashcard(
            id: id, deck: deck, question: question, answer: answer,
            verdict: verdict, seenAt: seenAt, origin: origin,
            sourcePosition: sourcePosition, correctStreak: correctStreak,
            requiredCorrect: requiredCorrect
        )
    }

    /// Un paquet valide, ou `nil` (`filter` de la source).
    private static func deck(from raw: Any) -> CollDeckDefinition? {
        guard let value = raw as? [String: Any],
              let key = value["key"] as? String,
              !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let label = value["label"] as? String,
              !label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { return nil }
        return CollDeckDefinition(key: key, label: label, description: value["description"] as? String)
    }

    /// `serializeCourseFlashcards` : encodage JSON, `nil` si l'encodage échoue.
    static func serialize(_ value: CollFlashcardsDocument) -> String? {
        guard let data = try? JSONEncoder().encode(value) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// `hasGeneratedCourseFlashcards` : une carte sans origine `user` a été
    /// générée (les anciennes cartes n'avaient pas encore de champ `origin`).
    static func hasGenerated(_ document: CollFlashcardsDocument?) -> Bool {
        document?.cards.contains { $0.origin != .user } ?? false
    }

    /// `generateCourseFlashcards` : génération locale déterministe, disponible
    /// hors connexion.
    static func generate(chapterName: String, sourceName: String) -> CollFlashcardsDocument {
        let trimmed = chapterName.trimmingCharacters(in: .whitespacesAndNewlines)
        let topic = trimmed.isEmpty ? "ce chapitre" : trimmed
        let cards: [CollFlashcard] = [
            CollFlashcard(id: "definition-1", deck: "definitions", question: "Comment définir la notion centrale de « \(topic) » ?", answer: "Donne la définition exacte de \(topic), puis précise les objets et conditions concernés.", verdict: nil, seenAt: nil, origin: .generated),
            CollFlashcard(id: "definition-2", deck: "definitions", question: "Quel vocabulaire faut-il maîtriser dans « \(topic) » ?", answer: "Récite les notions, notations et distinctions introduites dans le cours de \(topic).", verdict: nil, seenAt: nil, origin: .generated),
            CollFlashcard(id: "theorem-1", deck: "theorems", question: "Quelles sont les hypothèses du résultat principal de « \(topic) » ?", answer: "Énonce toutes les hypothèses avant le résultat : ensemble de définition, régularité, bornes et conditions particulières.", verdict: nil, seenAt: nil, origin: .generated),
            CollFlashcard(id: "theorem-2", deck: "theorems", question: "Quel est le théorème ou la propriété à retenir pour « \(topic) » ?", answer: "Énonce le résultat avec ses notations, puis distingue clairement la conclusion des hypothèses.", verdict: nil, seenAt: nil, origin: .generated),
            CollFlashcard(id: "proof-1", deck: "proofs", question: "Quelle démonstration faut-il savoir restituer dans « \(topic) » ?", answer: "Restitue une démonstration du cours étape par étape, avec ses hypothèses et sa conclusion.", verdict: nil, seenAt: nil, origin: .generated),
        ]
        return CollFlashcardsDocument(
            version: 1,
            generatedAt: CollCompletion.now(),
            sourceName: sourceName,
            cards: cards,
            decks: nil
        )
    }

    /// `courseFlashcardDecks` : paquets standards, paquets déclarés, puis clés
    /// trouvées dans les cartes, sans doublon.
    static func deckDefinitions(for document: CollFlashcardsDocument?) -> [CollDeckDefinition] {
        var decks = standardDecks + (document?.decks ?? [])
        for card in document?.cards ?? [] where !decks.contains(where: { $0.key == card.deck }) {
            decks.append(CollDeckDefinition(key: card.deck, label: card.deck, description: nil))
        }
        var seen = Set<String>()
        return decks.filter { seen.insert($0.key).inserted }
    }

    /// Champ facultatif tolérant : `nil` (refus) si la valeur est présente mais
    /// invalide ; `.some(nil)` si elle est absente, ou `null` quand `nullish`.
    private static func decode<T>(
        _ raw: Any?,
        nullish: Bool,
        _ parse: (Any) -> T?
    ) -> T?? {
        guard let raw else { return .some(nil) }
        if raw is NSNull { return nullish ? .some(nil) : nil }
        guard let value = parse(raw) else { return nil }
        return .some(value)
    }
}
