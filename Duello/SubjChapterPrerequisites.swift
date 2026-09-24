//
//  SubjChapterPrerequisites.swift
//  Duello
//
//  Port de src/utils/chapterPrerequisites.ts (RN) — prérequis de chapitre :
//  dépliage récursif des connaissances qu'un sujet mobilise, comparaison à
//  l'avancement du cours, puis état par question pour les pastilles du lecteur.
//  Port de src/utils/questionPrerequisiteGranularity.ts (RN) — empreinte
//  canonique d'une ventilation par question, uniformité et origine honnête.
//
//  Réutilise sans les redéfinir :
//    - `SubjProgramYear` (SubjFlashcardSelection.swift) = `ProgramYear` (1 | 2).
//    - `TrainCourseStatus` (TrainCourseStatus.swift) = `ChapterProgressStatus`
//      (`not-started` | `in-progress` | `completed`).
//    - `CollKnowledgeDocument` et `CollCourseIndex.requiredPosition`
//      (CollCourseIndex.swift) = `CourseKnowledgeIndex` et
//      `requiredCoursePositionFromKnowledge`.
//
//  Notes (2026-09-24) :
//  - `ChapterCourseStatus` (`in-progress` | `completed`) est porté à part sous
//    `SubjRequiredCourseStatus` : `TrainCourseStatus` y ajoute `not-started`,
//    qui n'a pas de sens comme niveau minimal exigé.
//  - Le programme Swift (`TrackChapter`, Models.swift:137) ne porte pas encore
//    `prerequisites` (`SubjProgramMerge.swift:69`) : ces fonctions sont pures et
//    attendent `chaptersByKey` / `statuses` fournis par l'appelant. Aucune
//    source de données n'est inventée (seam honnête).
//  - `Number.EPSILON` de la source → `Double.ulpOfOne` (même valeur 2⁻⁵²).
//  - La source met en cache l'index compilé et les positions dans des `WeakMap` ;
//    le port Swift recalcule (aucun cache partagé), comme `CollCourseIndex`.
//  Cible : iOS 16, aucune dépendance externe.
//
import Foundation

// MARK: - Statuts et exigences

/// `ChapterCourseStatus` : niveau minimal qu'un prérequis peut exiger.
enum SubjRequiredCourseStatus: String, Codable, CaseIterable {
    case inProgress = "in-progress"
    case completed = "completed"
}

/// `ChapterPrerequisite` : une connaissance attendue avant un sujet.
struct SubjChapterPrerequisite: Equatable, Hashable {
    var year: SubjProgramYear
    var chapterId: String
    /// Niveau minimal exigé ; `nil` vaut « terminé » (défaut de la source).
    var requiredStatus: SubjRequiredCourseStatus?
    /// Raison pédagogique courte, propre au sujet lorsqu'elle est connue.
    var reason: String?
}

/// Exigence dépliée : le niveau attendu n'y est plus optionnel.
struct SubjResolvedChapterPrerequisite: Equatable {
    var year: SubjProgramYear
    var chapterId: String
    var requiredStatus: SubjRequiredCourseStatus
    var reason: String?
}

/// `PrerequisiteChapter` : chapitre réduit à ce dont le calcul a besoin.
struct SubjPrerequisiteChapter: Equatable {
    var name: String
    var prerequisites: [SubjChapterPrerequisite]?
}

/// `PrerequisiteRequest.chapter` : chapitre d'où le sujet est ouvert, ou
/// `nil` pour une annale.
struct SubjPrerequisiteChapterRef: Equatable {
    var id: String
    var prerequisites: [SubjChapterPrerequisite]?
}

/// `questionReviewSource` : provenance d'une fiche par question. Seule une
/// source `editorial` atteste que le contenu a réellement été relu.
enum SubjQuestionReviewSource: String, Equatable {
    case editorial
    case semantic
    case exerciseInheritance = "exercise-inheritance"
}

// MARK: - Résultat du dépliage

/// Résultat de `expandedChapterRequirements` : un dictionnaire qui conserve
/// l'ordre d'insertion de la source (`Map`), pour une itération déterministe.
struct SubjExpandedChapterRequirements {
    private(set) var keys: [String] = []
    private(set) var values: [String: SubjResolvedChapterPrerequisite] = [:]

    var count: Int { values.count }
    subscript(key: String) -> SubjResolvedChapterPrerequisite? { values[key] }

    /// Entrées dans l'ordre d'insertion.
    var entries: [(key: String, value: SubjResolvedChapterPrerequisite)] {
        keys.compactMap { key in values[key].map { (key, $0) } }
    }

    /// `Map.set` : une clé déjà présente garde sa position d'origine.
    mutating func set(_ key: String, _ value: SubjResolvedChapterPrerequisite) {
        if values[key] == nil { keys.append(key) }
        values[key] = value
    }
}

// MARK: - États affichables

/// `PrerequisiteState` : état des connaissances requises, prêt pour l'affichage.
struct SubjPrerequisiteState: Equatable {
    var requiredCount: Int
    /// Chapitres à voir avant de commencer : pas même entamés.
    var missingNames: [String]
    /// Prérequis entamés mais pas terminés : à l'élève d'en juger.
    var startedNames: [String]
    /// Tout est acquis : aucun manque, aucun chapitre encore en cours.
    var ready: Bool
}

/// `QuestionPrerequisiteState` : résumé du badge global et des pastilles.
struct SubjQuestionPrerequisiteState: Equatable {
    var availableCount: Int
    var totalCount: Int
    var unavailableQuestionIds: [String]
    var missingNames: [String]
    var startedNames: [String]
}

// MARK: - Requêtes

/// `PrerequisiteRequest` : tout ce dont le calcul des prérequis a besoin.
struct SubjPrerequisiteRequest {
    var chapter: SubjPrerequisiteChapterRef?
    var requiredChapters: [SubjChapterPrerequisite]?
    var programYear: SubjProgramYear
    var chaptersByKey: [String: SubjPrerequisiteChapter]
    var statuses: [String: TrainCourseStatus]
    var coursePositions: [String: Double]?
    var courseKnowledgeIndexes: [String: CollKnowledgeDocument]?
    var knowledgeContext: String?
    var knowledgeContextChapterKey: String?
    var includeCurrentChapter: Bool = true
}

/// `QuestionPrerequisiteRequest` : la requête de chapitre, détaillée par question.
struct SubjQuestionPrerequisiteRequest {
    var chapter: SubjPrerequisiteChapterRef?
    var programYear: SubjProgramYear
    var chaptersByKey: [String: SubjPrerequisiteChapter]
    var statuses: [String: TrainCourseStatus]
    /// Identifiants stables réellement affichés dans le lecteur.
    var questionIds: [String]
    /// Exigences communes à toutes les questions de l'exercice.
    var requiredChapters: [SubjChapterPrerequisite]?
    /// Exigences complètes propres à une question, à la place du repli commun.
    var questionRequiredChapters: [String: [SubjChapterPrerequisite]]?
    /// Une revue en attente ne doit jamais produire un état vert par défaut.
    var reviewPending: Bool = false
    /// Contexte propre à chaque question pour retrouver sa notion dans le PDF.
    var questionKnowledgeContexts: [String: String]?
    var coursePositions: [String: Double]?
    var courseKnowledgeIndexes: [String: CollKnowledgeDocument]?
    var knowledgeContext: String?
    var knowledgeContextChapterKey: String?
    var includeCurrentChapter: Bool = true
}
// MARK: - Calcul des prérequis

/// `chapterPrerequisites.ts` : prérequis de chapitre — dépliage récursif des
/// connaissances qu'un sujet mobilise, comparaison à l'avancement du cours, puis
/// état par question pour les pastilles du lecteur.
///
/// Découpage (24/09/2026) : le calcul vit dans les extensions dédiées —
/// `SubjChapterPrerequisites+Expansion.swift` (dépliage),
/// `SubjChapterPrerequisites+CourseState.swift` (avancement du cours),
/// `SubjChapterPrerequisites+QuestionState.swift` (granularité par question) et
/// `SubjChapterPrerequisites+Granularity.swift` (empreinte et origine d'une
/// ventilation).
enum SubjChapterPrerequisites {}
