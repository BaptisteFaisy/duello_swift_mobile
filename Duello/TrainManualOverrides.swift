//
//  TrainManualOverrides.swift
//  Duello
//
//  Port de src/data/manualExerciseOverrides.ts (RN) — application des
//  corrections manuelles au-dessus des banques générées.
//
//  Les énoncés et les corrigés viennent d'extractions automatiques de PDF, qui
//  laissent passer des formules cassées. Plutôt que de rééditer les fichiers
//  générés — qu'un nouveau passage du générateur écraserait —, la relecture
//  humaine est conservée à part et réappliquée ici, à la sortie des banques.
//
//  Réutilise sans les redéfinir (ne pas modifier) :
//    - `StmtQuestion` (StmtModels.swift) = `AnnaleQuestion` ;
//    - `StmtQuestions.extractStatementQuestions(_:minimumCount:)`
//      (StmtQuestions.swift) = `extractStatementQuestions` ;
//    - `ProgPrereqReview` + `ProgPrereqReview.Status`/`.Granularity`
//      (ProgPrereq.swift) = `ExercisePrerequisiteReview` ;
//    - `SubjChapterPrerequisite`, `SubjQuestionReviewSource`
//      (SubjChapterPrerequisites.swift) ;
//    - `SubjChapterPrerequisites.questionReviewSourceFor(_:editorialSource:)`
//      (SubjChapterPrerequisites+Granularity.swift).
//
//  ⚠️ La table de corrections en vigueur (`manualExerciseOverrides()`, via
//  `servedRecord` + tables ECG) n'est PAS portée : le bundle ne sert plus les
//  corrections, et `MANUAL_EXERCISE_OVERRIDE_FLOOR` / `servedBank` n'existent
//  pas encore côté Swift. Les variantes publiques prennent donc la table en
//  paramètre, et un point d'injection `TrainManualOverrides.current` (vide par
//  défaut) permet de brancher une source.
//  → branchement servedBank à raccorder (vague 5).
//
//  Cible : iOS 16, aucune dépendance externe.
//
import Foundation

// MARK: - Modèles

/// `ChapterItem` réduit à ce dont l'application d'une correction a besoin.
struct TrainOverrideItem {
    var id: String
    var title: String
    var source: String?
    var statement: String?
    var solution: String?
    var markingScheme: String?
    var comments: String?
    var difficulty: Int?
    var badges: [String]
    var questions: [StmtQuestion]
    var prerequisiteReview: ProgPrereqReview?

    init(
        id: String,
        title: String,
        source: String? = nil,
        statement: String? = nil,
        solution: String? = nil,
        markingScheme: String? = nil,
        comments: String? = nil,
        difficulty: Int? = nil,
        badges: [String] = [],
        questions: [StmtQuestion] = [],
        prerequisiteReview: ProgPrereqReview? = nil
    ) {
        self.id = id
        self.title = title
        self.source = source
        self.statement = statement
        self.solution = solution
        self.markingScheme = markingScheme
        self.comments = comments
        self.difficulty = difficulty
        self.badges = badges
        self.questions = questions
        self.prerequisiteReview = prerequisiteReview
    }
}

/// `ManualExerciseOverride` : une correction manuelle, tous les champs
/// optionnels — seul ce qui est fourni recouvre le sujet d'origine.
struct TrainManualOverride {
    var title: String? = nil
    var source: String? = nil
    var statement: String? = nil
    var solution: String? = nil
    var markingScheme: String? = nil
    var comments: String? = nil
    var difficulty: Int? = nil
    var badges: [String]? = nil
    var roles: [String]? = nil
}

// MARK: - Point d'application

/// Port de `manualExerciseOverrides` : la table n'est pas servie ici, elle est
/// injectée par l'appelant (branchement servedBank à raccorder, vague 5).
enum TrainManualOverrides {

    /// Table de corrections en vigueur, vide tant que servedBank n'est pas
    /// raccordé.
    static var current: [String: TrainManualOverride] = [:]

    /// `OVERRIDE_TEXTS` : champs de texte d'une correction.
    static let overrideTextFields = [
        "title",
        "source",
        "statement",
        "solution",
        "markingScheme",
        "comments",
    ]

    /// `EXPLICITLY_DAMAGED_CORRECTION` : lacune d'OCR annoncée comme telle.
    static let explicitlyDamagedCorrection = try! NSRegularExpression(
        pattern: "\\[(?:illisible|ill\\.)\\]",
        options: [.caseInsensitive]
    )

    /// `EDITORIAL_NEW_QUESTION_SOURCES` : sous-questions rendues visibles par
    /// la relecture et vérifiées éditorialement. La valeur désigne la question
    /// voisine dont elles prolongent le raisonnement ; la valeur `*` marque une
    /// question relue qui mobilise explicitement toute la fiche du sujet.
    static let editorialNewQuestionSources: [String: [String: String]] = [
        "ecg-appliquees-2-ds3-vb-2024-2025": [
            "19d": "19c",
            "21b": "21a",
        ],
        "ecg-appliquees-2-ds6-vb-2025-2026": [
            "3a": "3b",
        ],
        "ecg-appliquees-2-ds2-vb-2025-2026": [
            "2": "1",
            "11a": "*",
            "11b": "*",
        ],
        "ecg-appliquees-2-ds6-va-2024-2025": [
            "exercice-2-8": "exercice-2-7",
        ],
        "ecg-appliquees-2-ds8-2024-2025": [
            // La relecture a séparé ces sous-questions de la ligne précédente et
            // a restauré le numéro 24, jusque-là lu comme 23.
            "17c": "17b",
            "21b": "21a",
            "24": "23",
        ],
        "ecg-appliquees-2-ds7-vb-2024-2025": [
            // 17.b majore l'égalité intégrale établie en 17.a ; l'extraction
            // lisait « 17.c » à sa place, et 17.c était collée à la formule qui
            // la précède.
            "17b": "17a",
        ],
    ]

    /// `isManualExerciseOverride` : une correction servie séparément n'est
    /// retenue que si ses champs ont la forme attendue. Rejette un objet nil,
    /// un tableau ou un scalaire.
    static func isManualExerciseOverride(_ value: Any?) -> Bool {
        guard let object = value as? [String: Any] else { return false }

        let textsValid = overrideTextFields.allSatisfy { field -> Bool in
            guard let raw = object[field], !(raw is NSNull) else { return true }
            return raw is String
        }
        guard textsValid else { return false }

        if let raw = object["difficulty"], !(raw is NSNull) {
            guard let number = raw as? NSNumber, !(raw is Bool) else { return false }
            let difficulty = number.doubleValue
            guard difficulty == difficulty.rounded(),
                  difficulty >= 1, difficulty <= 6
            else { return false }
        }

        return ["badges", "roles"].allSatisfy { field -> Bool in
            guard let raw = object[field], !(raw is NSNull) else { return true }
            return raw is [Any]
        }
    }

    /// `mergeManualExerciseOverrideLayers` : superpose les cahiers champ par
    /// champ. Une relecture de difficulté ou un corrigé court ne doit pas
    /// effacer un énoncé corrigé qui porte le même identifiant.
    static func mergeManualExerciseOverrideLayers(
        _ layers: [String: TrainManualOverride]...
    ) -> [String: TrainManualOverride] {
        var merged: [String: TrainManualOverride] = [:]
        for layer in layers {
            for (itemId, override) in layer {
                var entry = merged[itemId] ?? TrainManualOverride()
                if let value = override.title { entry.title = value }
                if let value = override.source { entry.source = value }
                if let value = override.statement { entry.statement = value }
                if let value = override.solution { entry.solution = value }
                if let value = override.markingScheme { entry.markingScheme = value }
                if let value = override.comments { entry.comments = value }
                if let value = override.difficulty { entry.difficulty = value }
                if let value = override.badges { entry.badges = value }
                if let value = override.roles { entry.roles = value }
                merged[itemId] = entry
            }
        }
        return merged
    }

    /// `withoutExplicitlyDamagedSolution` : une lacune d'OCR annoncée comme
    /// telle n'est pas un corrigé publiable — le sujet est présenté comme
    /// dépourvu de corrigé.
    static func withoutExplicitlyDamagedSolution(_ item: TrainOverrideItem) -> TrainOverrideItem {
        guard let solution = item.solution else { return item }
        let range = NSRange(solution.startIndex..<solution.endIndex, in: solution)
        guard explicitlyDamagedCorrection.firstMatch(in: solution, range: range) != nil else {
            return item
        }
        var corrected = item
        corrected.solution = nil
        return corrected
    }

    /// `sameQuestions` : deux listes portent les mêmes identifiants et libellés.
    static func sameQuestions(_ left: [StmtQuestion], _ right: [StmtQuestion]) -> Bool {
        guard left.count == right.count else { return false }
        for (index, question) in left.enumerated() {
            guard question.id == right[index].id,
                  question.label == right[index].label
            else { return false }
        }
        return true
    }

    /// `overriddenQuestions` : questions du sujet corrigé. Une banque qui porte
    /// une liste écrite à la main la garde ; sinon on dérive de l'énoncé corrigé
    /// en reportant l'ancien identifiant quand la question survit.
    static func overriddenQuestions(
        _ item: TrainOverrideItem,
        statement: String
    ) -> [StmtQuestion]? {
        let previous = item.questions
        let derivedBefore = StmtQuestions.extractStatementQuestions(item.statement ?? "")
        if !previous.isEmpty && !sameQuestions(previous, derivedBefore) {
            return item.questions
        }

        let derived = StmtQuestions.extractStatementQuestions(statement)
        if derived.isEmpty { return nil }

        var legacyIds: [String: String] = [:]
        for question in previous {
            if let legacyId = question.legacyId { legacyIds[question.id] = legacyId }
        }
        return derived.map { question in
            let legacyId = question.legacyId ?? legacyIds[question.id]
            guard let legacyId else { return question }
            var copy = question
            copy.legacyId = legacyId
            return copy
        }
    }

    /// `overriddenPrerequisiteReview` : fiche de prérequis recalée sur les
    /// questions du sujet corrigé. Une question nouvelle hérite des exigences de
    /// l'exercice, et cet héritage cesse de se déclarer `editorial`.
    /// Exigence propre à une question : sa propre entrée, celle de son ancien
    /// identifiant, puis la source éditoriale (`*` = toute la fiche). `nil` vaut
    /// héritage des exigences de l'exercice.
    static var resolvedPrerequisite: (
        ProgPrereqReview,
        [String: [SubjChapterPrerequisite]],
        [String: String],
        StmtQuestion
    ) -> [SubjChapterPrerequisite]? {
        { review, reviewed, editorialSources, question in
            if let own = reviewed[question.id] { return own }
            if let legacyId = question.legacyId, let own = reviewed[legacyId] { return own }
            let editorialSource = editorialSources[question.id]
            if editorialSource == "*" { return review.prerequisites }
            if let editorialSource { return reviewed[editorialSource] }
            return nil
        }
    }

    static func overriddenPrerequisiteReview(
        _ item: TrainOverrideItem,
        questions: [StmtQuestion]?
    ) -> ProgPrereqReview? {
        guard let review = item.prerequisiteReview else { return item.prerequisiteReview }
        guard let reviewed = review.questionPrerequisites else {
            guard let questions, questions.count >= 2 else { return review }
            var prerequisites: [String: [SubjChapterPrerequisite]] = [:]
            for question in questions { prerequisites[question.id] = review.prerequisites }
            var result = review
            result.granularity = .questions
            result.questionPrerequisites = prerequisites
            result.questionReviewSource = SubjChapterPrerequisites.questionReviewSourceFor(
                prerequisites,
                editorialSource: .semantic
            )
            return result
        }

        guard let questions, !questions.isEmpty else {
            var exerciseWide = review
            exerciseWide.questionPrerequisites = nil
            exerciseWide.questionReviewSource = nil
            exerciseWide.granularity = .exercise
            return exerciseWide
        }

        var inherited = false
        let editorialSources = editorialNewQuestionSources[item.id] ?? [:]
        var questionPrerequisites: [String: [SubjChapterPrerequisite]] = [:]
        for question in questions {
            let own = resolvedPrerequisite(review, reviewed, editorialSources, question)
            if own == nil { inherited = true }
            questionPrerequisites[question.id] = own ?? review.prerequisites
        }

        var result = review
        result.questionPrerequisites = questionPrerequisites
        result.questionReviewSource = SubjChapterPrerequisites.questionReviewSourceFor(
            questionPrerequisites,
            editorialSource: (!inherited && review.questionReviewSource == .editorial)
                ? .editorial
                : .semantic
        )
        return result
    }

    /// `overrideChapterItem` : sujet corrigé par une relecture donnée. Si
    /// l'énoncé est remplacé, les questions et la fiche de prérequis sont
    /// recalculées.
    static func overrideChapterItem(
        _ item: TrainOverrideItem,
        _ override: TrainManualOverride
    ) -> TrainOverrideItem {
        var corrected = item
        if let value = override.title { corrected.title = value }
        if let value = override.source { corrected.source = value }
        if let value = override.statement { corrected.statement = value }
        if let value = override.solution { corrected.solution = value }
        if let value = override.markingScheme { corrected.markingScheme = value }
        if let value = override.comments { corrected.comments = value }
        if let value = override.difficulty { corrected.difficulty = value }
        if let value = override.badges { corrected.badges = value }

        if let statement = override.statement {
            let questions = overriddenQuestions(item, statement: statement)
            corrected.questions = questions ?? []
            if let review = overriddenPrerequisiteReview(item, questions: questions) {
                corrected.prerequisiteReview = review
            }
        }
        return corrected
    }
}
