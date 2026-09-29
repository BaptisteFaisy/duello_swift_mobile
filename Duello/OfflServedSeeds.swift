//
//  OfflServedSeeds.swift
//  Duello
//
//  Formes minimales d'un sujet servi séparément et contrôles de forme.
//
//  Fichier source Expo porté : `src/content/servedBank.ts`
//  (`ExerciseSeedShape`, `isExerciseSeed`, `isChapterSeedShape`, la constante
//  `DIFFICULTIES` et les entrées de catalogue `ExerciseCatalogItem` /
//  `ExerciseCatalogChapter`).
//
//  Le contrôle de forme appartient à l'appelant : un enregistrement incomplet
//  ferait échouer l'affichage longtemps après son téléchargement, là où
//  l'origine du problème serait invisible. `source` et les liens portent
//  l'attribution exigée par les conditions de réutilisation du corpus.
//
//  Cible : iOS 16, aucune dépendance externe.
//
import Foundation

/// `ExerciseSeedShape` : sujet d'exercice servi séparément.
struct OfflExerciseSeed: Codable, Equatable {
    var key: String
    var chapterId: String
    var title: String
    var difficulty: Int
    var statement: String
    var solution: String?
    var source: String
    var sourceUrl: String
    var solutionUrl: String
    /// Champs de carte lus par le catalogue servi (`notions` / `badges` /
    /// `roles`), facultatifs et non contrôlés par `isExerciseSeed`.
    var notions: [String]?
    var badges: [String]?
    var roles: [String]?
}

/// Forme minimale d'un sujet retranscrit servi par chapitre
/// (`isChapterSeedShape`) : de quoi le ranger, l'afficher et créditer sa source.
struct OfflChapterSeed: Codable, Equatable {
    var key: String
    var chapterId: String
    var title: String
    var statement: String
    var source: String
    var difficulty: Int
}

/// `ExerciseCatalogItem` : fiche légère affichable avant les énoncés.
struct OfflExerciseCatalogItem: Equatable {
    var id: String
    var chapterId: String
    var title: String
    var difficulty: Int
    var notions: [String]?
    var badges: [String]?
    var roles: [String]?
}

/// `ExerciseCatalogChapter` : ce qu'un chapitre propose sans construire d'énoncé.
struct OfflExerciseCatalogChapter: Equatable {
    /// Sujets du chapitre, pour croiser la progression enregistrée.
    var itemIds: [String]
    /// Fiches légères affichables avant l'arrivée des énoncés.
    var items: [OfflExerciseCatalogItem]
    var withSolution: Int
}

/// Contrôles de forme et conversions JSON de `servedBank.ts`.
enum OfflServedSeeds {
    /// `DIFFICULTIES` : niveaux acceptés (1 à 6).
    static let difficulties: Set<Int> = [1, 2, 3, 4, 5, 6]

    /// `isExerciseSeed` : sujet servi complet, ou `nil` si un champ manque.
    static func isExerciseSeed(_ value: Any) -> OfflExerciseSeed? {
        guard let seed = value as? [String: Any] else { return nil }
        guard let key = nonEmptyString(seed["key"]),
              let chapterId = nonEmptyString(seed["chapterId"]),
              let title = seed["title"] as? String,
              let statement = nonEmptyString(seed["statement"]),
              seed["solution"] == nil || seed["solution"] is String,
              let source = nonEmptyString(seed["source"]),
              seed["sourceUrl"] is String,
              seed["solutionUrl"] is String,
              let difficulty = difficulty(seed["difficulty"]) else { return nil }
        return OfflExerciseSeed(
            key: key,
            chapterId: chapterId,
            title: title,
            difficulty: difficulty,
            statement: statement,
            solution: seed["solution"] as? String,
            source: source,
            sourceUrl: seed["sourceUrl"] as? String ?? "",
            solutionUrl: seed["solutionUrl"] as? String ?? "",
            notions: stringArray(seed["notions"]),
            badges: stringArray(seed["badges"]),
            roles: stringArray(seed["roles"])
        )
    }

    /// `isChapterSeedShape` : sujet retranscrit minimal, ou `nil`.
    static func isChapterSeedShape(_ value: Any) -> OfflChapterSeed? {
        guard let seed = value as? [String: Any] else { return nil }
        guard let key = nonEmptyString(seed["key"]),
              let chapterId = nonEmptyString(seed["chapterId"]),
              let title = seed["title"] as? String,
              let statement = nonEmptyString(seed["statement"]),
              let source = nonEmptyString(seed["source"]),
              let difficulty = difficulty(seed["difficulty"]) else { return nil }
        return OfflChapterSeed(
            key: key,
            chapterId: chapterId,
            title: title,
            statement: statement,
            source: source,
            difficulty: difficulty
        )
    }

    /// `isFilledText` : chaîne non vide.
    static func isFilledText(_ value: Any) -> String? {
        nonEmptyString(value)
    }

    /// Chaîne JSON non vide, ou `nil`.
    private static func nonEmptyString(_ value: Any?) -> String? {
        guard let text = value as? String, !text.isEmpty else { return nil }
        return text
    }

    /// Tableau de chaînes non vide (`card.notions?.length ? … : {}`), ou `nil`.
    private static func stringArray(_ value: Any?) -> [String]? {
        guard let array = value as? [Any] else { return nil }
        let strings = array.compactMap { $0 as? String }
        return strings.isEmpty ? nil : strings
    }

    /// Niveau accepté, ou `nil` (`DIFFICULTIES.has(seed.difficulty)`).
    private static func difficulty(_ value: Any?) -> Int? {
        guard let number = value as? Int, difficulties.contains(number) else { return nil }
        return number
    }
}
