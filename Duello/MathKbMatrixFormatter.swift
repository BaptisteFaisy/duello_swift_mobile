//
//  MathKbMatrixFormatter.swift
//  Duello
//
//  Matrices : délimiteur et rendu Unicode en texte modifiable
//  (`utils/mathMatrix.ts`).
//
//  Extrait de `MathKeyboardView.swift` : découpage en modules, sans
//  renommage de type, de membre ni de signature.
//

import Foundation

// MARK: - Matrices

/// Délimiteur de matrice (`MatrixDelimiter` de `utils/mathMatrix.ts`).
enum MathKbMatrixDelimiter: String, CaseIterable, Hashable {
    case square
    case round
    case braces
    case leftBrace
    case bars
    case doubleBars
    case none
}

/// Rendu d'une matrice en texte Unicode : les morceaux de crochets gardent les
/// lignes et les colonnes visibles tout en restant du texte modifiable
/// (`formatMatrix`).
enum MathKbMatrixFormatter {

    /// Colonnes alignées à droite sur la largeur visible la plus grande, deux
    /// espaces entre les colonnes. `nil` si une case est vide ou si les lignes
    /// n'ont pas toutes la même longueur.
    static func format(
        rows: [[String]],
        delimiter: MathKbMatrixDelimiter = .square
    ) -> String? {
        guard let firstRow = rows.first, !firstRow.isEmpty else { return nil }
        let columnCount = firstRow.count
        guard rows.allSatisfy({ $0.count == columnCount }) else { return nil }

        var values: [[String]] = []
        for row in rows {
            var cleaned: [String] = []
            for value in row {
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return nil }
                cleaned.append(
                    value
                        .components(separatedBy: .newlines)
                        .map { $0.trimmingCharacters(in: .whitespaces) }
                        .joined(separator: " ")
                )
            }
            values.append(cleaned)
        }

        let widths: [Int] = (0..<columnCount).map { column in
            values.map { $0[column].count }.max() ?? 0
        }

        let contents: [String] = values.map { row in
            row.enumerated()
                .map { index, value in alignRight(value, width: widths[index]) }
                .joined(separator: "  ")
        }

        let lines: [String] = contents.enumerated().map { index, content in
            let sides = sides(delimiter, row: index, rowCount: contents.count)
            return "\(sides.0)\(content)\(sides.1)"
        }
        return lines.joined(separator: "\n")
    }

    /// Crochets d'une ligne de matrice (`matrixSides`).
    static func sides(
        _ delimiter: MathKbMatrixDelimiter,
        row: Int,
        rowCount: Int
    ) -> (String, String) {
        switch delimiter {
        case .none:
            return ("", "")
        case .bars:
            return ("│", "│")
        case .doubleBars:
            return ("‖", "‖")
        case .leftBrace:
            if rowCount == 1 { return ("{", "") }
            if row == 0 { return ("⎧", "") }
            if row == rowCount - 1 { return ("⎩", "") }
            if rowCount % 2 == 1 && row == rowCount / 2 { return ("⎨", "") }
            return ("⎪", "")
        case .round:
            if rowCount == 1 { return ("(", ")") }
            if row == 0 { return ("⎛", "⎞") }
            if row == rowCount - 1 { return ("⎝", "⎠") }
            return ("⎜", "⎟")
        case .braces:
            if rowCount == 1 { return ("{", "}") }
            if row == 0 { return ("⎧", "⎫") }
            if row == rowCount - 1 { return ("⎩", "⎭") }
            if rowCount % 2 == 1 && row == rowCount / 2 { return ("⎨", "⎬") }
            return ("⎪", "⎪")
        case .square:
            if rowCount == 1 { return ("[", "]") }
            if row == 0 { return ("⎡", "⎤") }
            if row == rowCount - 1 { return ("⎣", "⎦") }
            return ("⎢", "⎥")
        }
    }

    private static func alignRight(_ value: String, width: Int) -> String {
        String(repeating: " ", count: max(0, width - value.count)) + value
    }
}
