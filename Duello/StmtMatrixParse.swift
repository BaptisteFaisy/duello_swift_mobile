import Foundation

/// Relève les matrices écrites dans un texte — port de
/// `src/utils/mathMatrix.ts` (`parseMatrices`).
///
/// Une même zone peut être lue de plusieurs façons — les lignes d'une matrice à
/// crochets se lisent aussi comme des matrices d'une seule ligne. Le choix
/// appartient à l'appelant : l'éditeur privilégie la construction multiligne
/// sous le curseur, la composition élimine ensuite les chevauchements.
enum StmtMatrixParse {
    /// Ligne de texte et son décalage de départ (en caractères).
    struct TextLine {
        var text: String
        var start: Int
    }

    /// Ligne encadrée : cellules et décalages des délimiteurs.
    struct EnclosedLine {
        var cells: [String]
        var leftOffset: Int
        var rightOffset: Int
    }

    /// Définition d'un encadrement multiligne.
    struct BracketedDefinition {
        var delimiter: StmtMatrixDelimiter
        var top: (String, String)
        var middles: [(String, String)]
        var bottom: (String, String)
    }

    /// Matrices relevées dans un texte, chevauchements compris (`parseMatrices`).
    static func parseMatrices(_ value: String) -> [StmtParsedMatrix] {
        let lines = textLines(value)
        var candidates: [StmtParsedMatrix] = []
        for lineIndex in 0..<lines.count {
            for definition in StmtMatrixScan.bracketedMultiline {
                if let parsed = parseBracketedMatrix(lines, lineIndex, definition) { candidates.append(parsed) }
            }
            if let bars = parseRepeatedDelimiterMatrix(lines, lineIndex, "│", "│", .bars) { candidates.append(bars) }
            if let doubleBars = parseRepeatedDelimiterMatrix(lines, lineIndex, "‖", "‖", .doubleBars) { candidates.append(doubleBars) }
            candidates.append(contentsOf: singleLineMatrices(lines[lineIndex]))
        }
        return candidates
    }

    /// Découpe le texte en lignes, avec leur décalage de départ.
    static func textLines(_ value: String) -> [TextLine] {
        let chars = Array(value)
        var lines: [TextLine] = []
        var start = 0
        var index = 0
        while index <= chars.count {
            if index == chars.count || chars[index] == "\n" {
                lines.append(TextLine(text: String(chars[start..<index]), start: start))
                if index == chars.count { break }
                start = index + 1
            }
            index += 1
        }
        return lines
    }

    /// Cellules d'un contenu encadré, ou `nil` si le séparateur manque.
    static func matrixCells(_ content: String) -> [String]? {
        let trimmed = content.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return nil }
        let cells = StmtRegex.split(" {2,}", in: trimmed).map { $0.trimmingCharacters(in: .whitespaces) }
        return cells.allSatisfy { !$0.isEmpty } ? cells : nil
    }

    /// Encadrement `left…right` d'une ligne à partir de `leftOffset`.
    static func enclosedLine(_ line: String, _ left: String, _ right: String, _ leftOffset: Int? = nil) -> EnclosedLine? {
        let chars = Array(line)
        let offset: Int
        if let leftOffset {
            offset = leftOffset
        } else {
            guard let found = StmtLatexScan.find(chars, left, from: 0) else { return nil }
            offset = found
        }
        guard StmtLatexScan.startsWith(chars, offset, left) else { return nil }
        let rightStart = offset + left.count
        guard let rightOffset = StmtLatexScan.find(chars, right, from: rightStart) else { return nil }
        let content = String(chars[rightStart..<rightOffset])
        guard let cells = matrixCells(content) else { return nil }
        return EnclosedLine(cells: cells, leftOffset: offset, rightOffset: rightOffset)
    }

    /// Matrice encadrée multiligne (`parseBracketedMatrix`).
    static func parseBracketedMatrix(_ lines: [TextLine], _ lineIndex: Int, _ definition: BracketedDefinition) -> StmtParsedMatrix? {
        guard let first = enclosedLine(lines[lineIndex].text, definition.top.0, definition.top.1) else { return nil }
        var rows = [first.cells]
        var continuationOffset: Int?
        var index = lineIndex + 1
        while index < lines.count {
            let line = lines[index]
            let offsets = continuationOffset.map { [$0] } ?? StmtMatrixScan.continuationOffsets(first.leftOffset)
            guard let parsed = bracketRow(line.text, definition, offsets) else { return nil }
            rows.append(parsed.cells)
            if parsed.isBottom {
                if rows.contains(where: { $0.count != rows[0].count }) { return nil }
                return StmtParsedMatrix(
                    rows: rows,
                    delimiter: definition.delimiter,
                    range: StmtTextSelection(
                        start: lines[lineIndex].start + first.leftOffset,
                        end: line.start + parsed.line.rightOffset + definition.bottom.1.count
                    )
                )
            }
            continuationOffset = parsed.line.leftOffset
            index += 1
        }
        return nil
    }

    /// Cherche un rang encadré (bas ou milieu) aux décalages proposés.
    static func bracketRow(
        _ text: String,
        _ definition: BracketedDefinition,
        _ offsets: [Int]
    ) -> (cells: [String], line: EnclosedLine, isBottom: Bool)? {
        for offset in offsets {
            if let bottom = enclosedLine(text, definition.bottom.0, definition.bottom.1, offset) {
                return (bottom.cells, bottom, true)
            }
            for (left, right) in definition.middles {
                if let middle = enclosedLine(text, left, right, offset) {
                    return (middle.cells, middle, false)
                }
            }
        }
        return nil
    }

    /// Matrice à délimiteur répété (`parseRepeatedDelimiterMatrix`).
    static func parseRepeatedDelimiterMatrix(
        _ lines: [TextLine],
        _ lineIndex: Int,
        _ left: String,
        _ right: String,
        _ delimiter: StmtMatrixDelimiter
    ) -> StmtParsedMatrix? {
        guard let first = enclosedLine(lines[lineIndex].text, left, right) else { return nil }
        if lineIndex > 0 {
            let previous = lines[lineIndex - 1].text
            if enclosedLine(previous, left, right, first.leftOffset) != nil
                || (first.leftOffset == 0 && enclosedLine(previous, left, right) != nil) {
                return nil
            }
        }
        var rows = [first.cells]
        var last = first
        var lastLineIndex = lineIndex
        var continuationOffset: Int?
        var index = lineIndex + 1
        while index < lines.count {
            let offsets = continuationOffset.map { [$0] } ?? StmtMatrixScan.continuationOffsets(first.leftOffset)
            guard let parsed = StmtMatrixScan.enclosedLineAtOffsets(lines[index].text, left, right, offsets) else { break }
            rows.append(parsed.cells)
            last = parsed
            lastLineIndex = index
            continuationOffset = parsed.leftOffset
            index += 1
        }
        if rows.count < 2 || rows.contains(where: { $0.count != rows[0].count }) { return nil }
        return StmtParsedMatrix(
            rows: rows,
            delimiter: delimiter,
            range: StmtTextSelection(
                start: lines[lineIndex].start + first.leftOffset,
                end: lines[lastLineIndex].start + last.rightOffset + right.count
            )
        )
    }

    /// Matrices d'une seule ligne (`singleLineMatrices`).
    static func singleLineMatrices(_ line: TextLine) -> [StmtParsedMatrix] {
        let chars = Array(line.text)
        var matrices: [StmtParsedMatrix] = []
        for (delimiter, left, right) in StmtMatrixScan.singleLineDelimiters {
            var from = 0
            while from < chars.count {
                guard let location = StmtLatexScan.find(chars, left, from: from),
                      let parsed = enclosedLine(line.text, left, right, location) else { break }
                from = parsed.rightOffset + right.count
                // Deux espaces sont le séparateur produit par `formatMatrix`.
                if parsed.cells.count < 2 { continue }
                matrices.append(StmtParsedMatrix(
                    rows: [parsed.cells],
                    delimiter: delimiter,
                    range: StmtTextSelection(start: line.start + parsed.leftOffset, end: line.start + parsed.rightOffset + right.count)
                ))
            }
        }
        return matrices
    }
}
