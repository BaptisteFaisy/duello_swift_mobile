//
//  SubjFlashcardSelection.swift
//  Duello
//
//  Lot « Subj » (9-E) — sélection des flashcards : modes de correction,
//  chapitres révisables et paquets. Types, options et algèbre de sélection
//  partagés par les menus de `SubjFlashcardDropdowns.swift`.
//
//  Fichiers source Expo portés (libellés repris mot pour mot) :
//    - src/screens/SubjectsScreen.tsx (lignes 1556-1583)
//        `ERROR_SORT_OPTIONS`, `FlashcardCorrectionMode`,
//        `FlashcardChapterSelection`, `LoadedCourseFlashcardChapterSource`,
//        `FlashcardChapterCandidate`, `FLASHCARD_CORRECTION_OPTIONS`.
//    - src/utils/courseFlashcards.ts : `FlashcardDeckDefinition` est **déjà
//        porté** sous `CollDeckDefinition` (`CollFlashcards.swift`) — il est
//        réutilisé ici et n'est jamais redéclaré.
//
//  Cible : iOS 16, aucune dépendance externe.
//
import Foundation

// MARK: - Année de programme

/// `ProgramYear` d'Expo (`src/data/tracks.ts` : `1 | 2`). Aucun type partagé
/// n'existe encore côté Swift : ce miroir local (préfixé) évite d'inventer un
/// type commun que d'autres lots devraient adopter. `1` = 1re année.
enum SubjProgramYear: Int, Codable, CaseIterable {
    case first = 1
    case second = 2
}

// MARK: - Mode de correction

/// `FlashcardCorrectionMode` : une carte se corrige « soi-même » ou par IA.
enum SubjFlashcardCorrectionMode: String, CaseIterable {
    case selfCorrection = "self"
    case ai = "ai"
}

/// `FLASHCARD_CORRECTION_OPTIONS` : entrées du menu « Mode de correction ».
enum SubjFlashcardCorrectionOptions {
    static let all: [CollDeckDefinition] = [
        CollDeckDefinition(key: "self", label: "Auto-correction", description: nil),
        CollDeckDefinition(key: "ai", label: "Correction IA", description: nil),
    ]

    /// Repli sûr du parent : tout ce qui n'est pas « ai » vaut « self ».
    static func mode(from key: String) -> SubjFlashcardCorrectionMode {
        key == SubjFlashcardCorrectionMode.ai.rawValue ? .ai : .selfCorrection
    }
}

// MARK: - Clés sentinelles des menus

/// Clés réservées des entrées de menu qui ne désignent pas un paquet réel
/// (littéraux `'all'`, `'__none__'`, `'__create__'` du JSX, nommés ici).
enum SubjFlashcardSelectionKey {
    /// Entrée « tous les types » (`allowAll`).
    static let all = "all"
    /// Entrée « sans type » (`allowNone`).
    static let none = "__none__"
    /// Entrée « créer un type » (`allowCreate`).
    static let create = "__create__"
}

// MARK: - Sélection de chapitres

/// `FlashcardChapterSelection` : soit tous les chapitres, soit une liste d'ids.
enum SubjFlashcardChapterSelection: Equatable {
    case all
    case chapters([String])

    /// Ids retenus ; `nil` signifie « tous » (comme la chaîne `'all'`).
    var chapterIds: [String]? {
        if case let .chapters(ids) = self { return ids }
        return nil
    }

    /// Le chapitre est-il coché ? Reprend `selectedIds.has(...)` d'Expo, où
    /// « tous » coche chaque ligne.
    func contains(_ key: String) -> Bool {
        chapterIds?.contains(key) ?? true
    }

    /// Bascule d'un chapitre (`onPress` des lignes) : depuis « tous », on
    /// décoche le seul chapitre touché ; sinon on ajoute ou on retire, en
    /// conservant l'ordre des options.
    func toggling(_ key: String, allKeys: [String]) -> SubjFlashcardChapterSelection {
        guard let ids = chapterIds else {
            return .chapters(allKeys.filter { $0 != key })
        }
        return ids.contains(key)
            ? .chapters(ids.filter { $0 != key })
            : .chapters(ids + [key])
    }
}

// MARK: - Chapitres chargés

/// `LoadedCourseFlashcardChapterSource` : une banque de chapitre enrichie du
/// libellé d'option et de l'année de programme.
struct SubjLoadedCourseChapterSource: Identifiable {
    var chapterId: String
    var chapterName: String
    var subject: String
    var coursePosition: Double
    var document: CollFlashcardsDocument
    var optionLabel: String
    var year: SubjProgramYear

    var id: String { chapterId }
}

/// `FlashcardChapterCandidate` : chapitre proposé au menu « Chapitres ».
struct SubjFlashcardChapterCandidate: Identifiable {
    var chapterId: String
    var chapterName: String
    var subject: String
    var optionLabel: String
    var year: SubjProgramYear
    var coursePosition: Double

    var id: String { chapterId }
}

// MARK: - Options des menus

/// `ERROR_SORT_OPTIONS` : classement des erreurs (panneau « Mes erreurs »).
enum SubjErrorSortOptions {
    static let recentKey = "recent"
    static let typeKey = "type"
    static let recurrenceKey = "recurrence"

    static let all: [CollDeckDefinition] = [
        CollDeckDefinition(key: recentKey, label: "Ordre chronologique", description: nil),
        CollDeckDefinition(key: typeKey, label: "Par type d’erreur", description: nil),
        CollDeckDefinition(key: recurrenceKey, label: "Par récurrence du type", description: nil),
    ]
}

/// Options du menu « Ordre » de la révision (littéral du JSX, nommé ici pour
/// ne pas figer « ordered » / « shuffled » dans la vue).
enum SubjFlashcardOrderOptions {
    static let orderedKey = "ordered"
    static let shuffledKey = "shuffled"

    static let all: [CollDeckDefinition] = [
        CollDeckDefinition(key: orderedKey, label: "Dans l’ordre", description: nil),
        CollDeckDefinition(key: shuffledKey, label: "Dans le désordre", description: nil),
    ]

    /// Clé affichée pour l'état courant (`flashcardShuffle`).
    static func key(shuffled: Bool) -> String {
        shuffled ? shuffledKey : orderedKey
    }

    /// Repli du parent : seul « shuffled » active le désordre.
    static func isShuffled(_ key: String) -> Bool {
        key == shuffledKey
    }
}

// MARK: - Libellés

/// Libellés du sélecteur, repris mot pour mot de `SubjectsScreen.tsx`.
enum SubjFlashcardSelectionCopy {
    /// Libellé par défaut de l'entrée « tous les types » (`allLabel`).
    static let allTypes = "Tous les types"
    static let noneType = "Sans type"
    static let createType = "Créer un type"
    static let loading = "Chargement…"
    static let chaptersLabel = "Chapitres"
    static let allChapters = "Tous"
    static let noChapter = "Aucun chapitre"
    static let searchingChapters = "Recherche des chapitres…"
    static let emptyChapters = "Aucun chapitre ne contient encore de flashcard."

    /// `selectedLabel` du menu « Chapitres » : « Tous », « Aucun chapitre »,
    /// le nom du chapitre unique, ou le compte. L'état de chargement est géré
    /// par la vue (`loading` prime sur tout le reste).
    static func chapterLabel(
        _ selection: SubjFlashcardChapterSelection,
        options: [CollDeckDefinition]
    ) -> String {
        guard let ids = selection.chapterIds else { return allChapters }
        if ids.isEmpty { return noChapter }
        if ids.count == 1 {
            return options.first { $0.key == ids[0] }?.label ?? "1 chapitre"
        }
        return "\(ids.count) chapitres"
    }
}
