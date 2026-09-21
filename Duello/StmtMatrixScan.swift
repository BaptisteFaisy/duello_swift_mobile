import Foundation

/// Balayage bas niveau des matrices du champ de réponse — port de
/// `src/utils/mathMatrix.ts`.
enum StmtMatrixScan {
    /// Repère une matrice multiligne produite par `formatMatrix`.
    static let multilineMatrix = "[⎡⎢⎣⎛⎜⎝⎧⎨⎪⎩│‖][^\\n]*[⎤⎥⎦⎞⎟⎠⎫⎬⎪⎭│‖]"

    /// Vrai si le texte contient une matrice multiligne (`containsMultilineMatrix`).
    static func containsMultilineMatrix(_ value: String) -> Bool {
        StmtRegex.contains(multilineMatrix, in: value)
    }

    /// Colonnes possibles après la première ligne d'une matrice.
    static func continuationOffsets(_ firstOffset: Int) -> [Int] {
        firstOffset == 0 ? [0] : [firstOffset, 0]
    }

    /// Premier encadrement trouvé à l'un des décalages proposés.
    static func enclosedLineAtOffsets(
        _ line: String,
        _ left: String,
        _ right: String,
        _ offsets: [Int]
    ) -> StmtMatrixParse.EnclosedLine? {
        for offset in offsets {
            if let parsed = StmtMatrixParse.enclosedLine(line, left, right, offset) { return parsed }
        }
        return nil
    }

    /// Encadrements multilignes reconnus (carré, rond, accolades).
    static let bracketedMultiline: [StmtMatrixParse.BracketedDefinition] = [
        .init(delimiter: .square, top: ("⎡", "⎤"), middles: [("⎢", "⎥")], bottom: ("⎣", "⎦")),
        .init(delimiter: .round, top: ("⎛", "⎞"), middles: [("⎜", "⎟")], bottom: ("⎝", "⎠")),
        .init(delimiter: .braces, top: ("⎧", "⎫"), middles: [("⎪", "⎪"), ("⎨", "⎬")], bottom: ("⎩", "⎭")),
    ]

    /// Délimiteurs d'une matrice sur une seule ligne.
    static let singleLineDelimiters: [(StmtMatrixDelimiter, String, String)] = [
        (.square, "[", "]"),
        (.round, "(", ")"),
        (.braces, "{", "}"),
        (.bars, "│", "│"),
        (.doubleBars, "‖", "‖"),
    ]
}
