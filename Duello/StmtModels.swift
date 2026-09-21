import Foundation

/// Modèles partagés du lot « Stmt » — port de
/// `src/utils/statementLayout.ts`, `statementQuestions.ts` et
/// `exerciseAnswerInput.ts`.
///
/// Tous les types portent le préfixe `Stmt` : aucun n'existe ailleurs dans
/// l'app.

// MARK: - Lignes d'énoncé

/// Nature d'une ligne d'énoncé (`StatementDisplayLine['kind']`).
enum StmtLineKind: String {
    case body
    case question
    case subquestion
    case blank
}

/// Ligne d'énoncé classée (`StatementDisplayLine`).
struct StmtDisplayLine: Equatable {
    var kind: StmtLineKind
    var text: String
}

/// Ligne de lecture et son niveau logique (`StatementLayoutRow`).
struct StmtLayoutRow: Equatable {
    var kind: StmtLineKind
    var text: String
    /// `0` pour un bloc de corps, `1` pour une sous-question et ses prolongements.
    var indentLevel: Int
}

/// Respiration à insérer avant un repère (`statementGapBefore`).
enum StmtGap: String {
    case none
    case question
    case subquestion
}

// MARK: - Fragments de texte

/// Fragment d'une ligne portant ou non une emphase Markdown (`EmphasisSpan`).
struct StmtEmphasisSpan: Equatable {
    var text: String
    var bold: Bool
    var italic: Bool
}

/// Sélection de texte, en unités de la chaîne qui la porte (`TextSelection`).
struct StmtTextSelection: Equatable {
    var start: Int
    var end: Int
}

// MARK: - Questions

/// Question extraite d'un énoncé (`AnnaleQuestion` + `prompt` interne).
struct StmtQuestion: Equatable {
    var id: String
    var label: String
    /// Identifiant de la convention précédente, pour rattacher les réponses.
    var legacyId: String?
    /// Variante d'un QCM (« A », « B »…), absente d'une question unique.
    var alternativeId: String?
    /// Regroupe les variantes d'un même choix.
    var alternativeGroupId: String?
    /// Texte de la ligne qui introduit la question (vue éditoriale).
    var prompt: String

    init(
        id: String,
        label: String,
        legacyId: String? = nil,
        alternativeId: String? = nil,
        alternativeGroupId: String? = nil,
        prompt: String = ""
    ) {
        self.id = id
        self.label = label
        self.legacyId = legacyId
        self.alternativeId = alternativeId
        self.alternativeGroupId = alternativeGroupId
        self.prompt = prompt
    }
}

// MARK: - Mode de saisie

/// Mode de saisie d'une réponse (`ExerciseAnswerInputMode`).
enum StmtAnswerInputMode: String {
    case math
    case python
}

// MARK: - Matrices

/// Délimiteur visuel d'une matrice (`MatrixDelimiter`).
enum StmtMatrixDelimiter: String {
    case square
    case round
    case braces
    case leftBrace = "left-brace"
    case bars
    case doubleBars = "double-bars"
    case none
}

/// Matrice relevée dans un texte (`ParsedMatrix`).
struct StmtParsedMatrix: Equatable {
    var rows: [[String]]
    var delimiter: StmtMatrixDelimiter
    var range: StmtTextSelection
}

// MARK: - Opérateurs guidés

/// Type de construction guidée (`MathOperatorKind`).
enum StmtMathOperatorKind: String {
    case exponent
    case limit
    case integral
    case sum
    case product
}

/// Opérateur guidé relevé dans un texte (`ParsedMathOperator`).
struct StmtParsedMathOperator: Equatable {
    var kind: StmtMathOperatorKind
    var values: [String: String]
    var range: StmtTextSelection
}
