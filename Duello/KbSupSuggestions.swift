//
//  KbSupSuggestions.swift
//  Duello
//
//  Touches proposées en tête du clavier maths pour l'exercice ouvert.
//
//  Fichiers source Expo portés :
//    - `src/utils/mathKeySuggestions.ts` — `MathKeySuggestionInput`,
//      `MATH_KEY_SUGGESTION_LIMIT`, `suggestMathKeys` ;
//    - `src/utils/mathKeySections.ts` — `MATH_KEYS`, `findMathKey` ;
//    - `src/data/mathKeySuggestions.generated.ts` — la table des chapitres,
//      portée dans `KbSupChapterAlphabet` ;
//    - `src/utils/mathKeyVocabulary.ts` — le comptage, porté dans
//      `KbSupVocabulary`.
//
//  Le but est de faire gagner du temps sans souffler la solution d'un exercice.
//  Pour un exercice, la fonction ne reçoit que deux choses : l'énoncé (ce que
//  l'élève a déjà sous les yeux ; le lui proposer en touche ne lui apprend rien)
//  et l'alphabet de son chapitre — les symboles communs aux *autres* exercices
//  du même chapitre, calculés hors ligne, donc muets sur celui qui est ouvert.
//  Le corrigé, le barème et les commentaires ne lui sont jamais transmis ; une
//  flashcard, elle, peut fournir son verso comme `expectedAnswer`, pour épingler
//  les notations réellement utiles à cette carte.
//
//  L'ordre suit la fréquence dans l'énoncé, jamais l'utilité supposée pour la
//  résolution : classer par « ce dont tu vas avoir besoin » redirait la méthode.
//
//  Cible : iOS 16, aucune dépendance externe.
//

import Foundation

// MARK: - Entrée

/// Contexte autorisé d'un exercice (`MathKeySuggestionInput`).
struct KbSupInput {
    /// Énoncé de l'exercice ouvert, seule source qui lui soit propre.
    var statement: String?
    /// Verso d'une flashcard, prioritaire ; ne jamais y passer un corrigé
    /// d'exercice.
    var expectedAnswer: String?
    /// Chapitre porteur, qui donne l'alphabet commun à ses autres exercices.
    var chapterId: String?
    /// Alphabet du chapitre imposé, pour les tests. Sinon il est lu dans
    /// `KbSupChapterAlphabet`, qui n'inscrit un symbole qu'à partir de quatre
    /// exercices distincts : en retirer un, celui qui est ouvert, ne change donc
    /// jamais la liste.
    var chapterKeys: [String]?

    init(
        statement: String? = nil,
        expectedAnswer: String? = nil,
        chapterId: String? = nil,
        chapterKeys: [String]? = nil
    ) {
        self.statement = statement
        self.expectedAnswer = expectedAnswer
        self.chapterId = chapterId
        self.chapterKeys = chapterKeys
    }
}

// MARK: - Suggestions

/// `mathKeySuggestions.ts` : clés suggérées selon le contexte de saisie.
enum KbSupSuggestions {

    /// `MATH_KEY_SUGGESTION_LIMIT` : une rangée, que le pouce parcourt d'un
    /// geste.
    static let limit = 12

    /// Touches à épingler pour cet exercice : d'abord les symboles de son
    /// énoncé, du plus fréquent au plus rare, puis l'alphabet de son chapitre
    /// pour compléter (`suggestMathKeys`).
    ///
    /// Les libellés qui ne correspondent à aucune touche du clavier sont
    /// écartés : la table du chapitre vient du corpus, pas du clavier.
    static func suggest(_ input: KbSupInput, limit: Int = KbSupSuggestions.limit) -> [MathKbKey] {
        labels(input, limit: limit).compactMap { label in key(for: label) }
    }

    /// Les libellés retenus, dans l'ordre : verso, énoncé, alphabet du chapitre,
    /// sans doublon et bornés à `limit`.
    static func labels(_ input: KbSupInput, limit: Int = KbSupSuggestions.limit) -> [String] {
        let fromExpectedAnswer = KbSupVocabulary.rankLabels(
            KbSupVocabulary.countLabels(input.expectedAnswer ?? "")
        )
        let fromStatement = KbSupVocabulary.rankLabels(
            KbSupVocabulary.countLabels(input.statement ?? "")
        )
        let fromChapter = input.chapterKeys
            ?? KbSupChapterAlphabet.alphabet(chapterId: input.chapterId)

        var retained: [String] = []
        for label in fromExpectedAnswer + fromStatement + fromChapter {
            if retained.count >= limit { break }
            if !retained.contains(label) { retained.append(label) }
        }
        return retained
    }

    /// Retrouve une touche par son libellé (`findMathKey`).
    static func key(for label: String) -> MathKbKey? {
        mathKeys.first { $0.label == label }
    }

    /// `MATH_KEYS` : toutes les touches du mode mathématique, sans doublon de
    /// libellé, dans l'ordre des sections — un libellé repris par deux sections
    /// garde la première touche rencontrée.
    private static let mathKeys: [MathKbKey] = {
        var seen = Set<String>()
        var keys: [MathKbKey] = []
        for section in MathKbLayout.mathSections {
            for key in section.keys where !seen.contains(key.label) {
                seen.insert(key.label)
                keys.append(key)
            }
        }
        return keys
    }()
}
