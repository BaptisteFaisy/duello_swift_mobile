import Foundation

/// Lecture tolérante de l'analyse renvoyée par le relais
/// (`courseTdAnalysisFromUnknown` de `src/utils/courseTd.ts`).
///
/// Le relais rend une analyse produite par un modèle : chaque champ est
/// contrôlé, tronqué et borné avant d'entrer dans la feuille locale. Une
/// analyse inexploitable vaut `nil`, jamais un document à moitié rempli.
enum CtdAnalysisParser {
    /// Bornes de `courseTd.ts`.
    private static let maxExercises = 30
    private static let maxQuestionsPerExercise = 20
    private static let maxListEntries = 12
    private static let maxListEntryLength = 300
    private static let maxChapterLength = 300
    private static let maxTitleLength = 300
    private static let maxStatementLength = 40_000
    private static let maxQuestionLength = 12_000
    private static let maxLabelLength = 100
    private static let maxIdentifierLength = 200

    /// Analyse utilisable, ou `nil` si la charge est illisible.
    static func parse(_ data: Data, analyzedAt: Double, courseUploadedAt: Double) -> CtdAnalysis? {
        guard let raw = try? JSONDecoder().decode(RawAnalysis.self, from: data),
              let identifiedChapter = text(raw.identifiedChapter, maxLength: maxChapterLength),
              let match = raw.chapterMatch.flatMap({ CtdChapterMatch(rawValue: $0) })
        else { return nil }
        let exercises = (raw.exercises ?? []).enumerated().compactMap { pair in
            exercise(pair.element, index: pair.offset)
        }
        guard !exercises.isEmpty else { return nil }
        return CtdAnalysis(
            analyzedAt: analyzedAt,
            courseUploadedAt: courseUploadedAt,
            identifiedChapter: identifiedChapter,
            chapterMatch: match,
            exercises: Array(exercises.prefix(maxExercises))
        )
    }

    /// Exercice retenu : titre, énoncé et au moins une question exploitable.
    private static func exercise(_ value: RawExercise, index: Int) -> CtdExercise? {
        guard let title = text(value.title, maxLength: maxTitleLength),
              let statement = text(value.statement, maxLength: maxStatementLength)
        else { return nil }
        let questions = (value.questions ?? []).enumerated().compactMap { pair in
            question(pair.element, exerciseIndex: index, questionIndex: pair.offset)
        }
        guard !questions.isEmpty else { return nil }
        return CtdExercise(
            id: text(value.id, maxLength: maxIdentifierLength) ?? "exercise-\(index + 1)",
            title: title,
            statement: statement,
            questions: Array(questions.prefix(maxQuestionsPerExercise))
        )
    }

    /// Question retenue : libellé, texte et difficulté de 1 à 5.
    private static func question(
        _ value: RawQuestion,
        exerciseIndex: Int,
        questionIndex: Int
    ) -> CtdQuestion? {
        guard let label = text(value.label, maxLength: maxLabelLength),
              let body = text(value.text, maxLength: maxQuestionLength),
              let level = difficulty(value.difficulty)
        else { return nil }
        return CtdQuestion(
            id: text(value.id, maxLength: maxIdentifierLength)
                ?? "exercise-\(exerciseIndex + 1)-question-\(questionIndex + 1)",
            label: label,
            text: body,
            difficulty: level,
            theorems: list(value.theorems?.values),
            hypotheses: list(value.hypotheses?.values)
        )
    }

    /// `difficulty` : entier de 1 à 5, sinon `nil` (la question est écartée).
    private static func difficulty(_ value: Int?) -> Int? {
        guard let value, (1...5).contains(value) else { return nil }
        return value
    }

    /// `stringList` : au plus douze entrées non vides de 300 caractères.
    private static func list(_ values: [String]?) -> [String] {
        let kept = (values ?? []).compactMap { text($0, maxLength: maxListEntryLength) }
        return Array(kept.prefix(maxListEntries))
    }

    /// `nonEmptyString` : texte rogné, tronqué, `nil` s'il est vide.
    private static func text(_ value: String?, maxLength: Int) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return String(trimmed.prefix(maxLength))
    }

    /// Charge brute du relais : tous les champs sont facultatifs, un champ
    /// absent ne fait jamais échouer la lecture.
    private struct RawAnalysis: Decodable {
        var identifiedChapter: String?
        var chapterMatch: String?
        var exercises: [RawExercise]?
    }

    private struct RawExercise: Decodable {
        var id: String?
        var title: String?
        var statement: String?
        var questions: [RawQuestion]?
    }

    private struct RawQuestion: Decodable {
        var id: String?
        var label: String?
        var text: String?
        var difficulty: Int?
        var theorems: RawStrings?
        var hypotheses: RawStrings?
    }

    /// Liste de textes tolérante (`stringList`) : une valeur qui n'est pas une
    /// liste, ou qui mêle des types, donne une liste vide plutôt qu'une erreur
    /// de lecture.
    private struct RawStrings: Decodable {
        let values: [String]

        init(from decoder: Decoder) throws {
            guard let container = try? decoder.singleValueContainer(),
                  let raw = try? container.decode([String].self)
            else {
                values = []
                return
            }
            values = raw
        }
    }
}
