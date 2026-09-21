import Foundation

/// Point d'entrée de la composition LaTeX d'une réponse — port de
/// `src/utils/mathAnswerLatex.ts`, `mathMatrix.ts` et `mathOperator.ts`.
///
/// Les briques (valeurs courtes, matrices, opérateurs guidés, délimitation des
/// formules) restent dans leurs modules ; cette façade donne l'API stable
/// attendue par les écrans.
enum StmtLatex {
    /// Rend en LaTeX une valeur courte écrite au clavier maths.
    static func mathValueToLatex(_ value: String) -> String {
        StmtValueLatex.mathValueToLatex(value)
    }

    /// Réponse préparée pour la composition, ou `nil` s'il n'y a rien à composer.
    static func composeAnswerForDisplay(_ raw: String) -> String? {
        StmtAnswerSupport.composeAnswerForDisplay(raw)
    }

    /// Source lisible d'un champ mathématique modifiable.
    static func editableMathPreview(_ raw: String) -> String? {
        StmtAnswerSupport.editableMathPreview(raw)
    }

    /// Vrai lorsqu'un texte mérite le lecteur composé (maths, code ou tableau).
    static func containsRichDocument(_ text: String?) -> Bool {
        StmtAnswerSupport.containsRichDocument(text)
    }

    /// Vrai si le texte contient une matrice multiligne.
    static func containsMultilineMatrix(_ value: String) -> Bool {
        StmtMatrixScan.containsMultilineMatrix(value)
    }

    /// Matrices relevées dans un texte, chevauchements compris.
    static func parseMatrices(_ value: String) -> [StmtParsedMatrix] {
        StmtMatrixParse.parseMatrices(value)
    }

    /// Constructions guidées relevées dans un texte.
    static func parseMathOperators(_ text: String, expectedKind: StmtMathOperatorKind? = nil) -> [StmtParsedMathOperator] {
        StmtOperatorParse.parseMathOperators(text, expectedKind)
    }
}
