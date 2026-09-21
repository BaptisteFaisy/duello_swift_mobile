import Foundation

/// Classification des lignes d'énoncé et blocs de lecture — port de
/// `src/utils/statementLayout.ts` (`statementDisplayLines`,
/// `statementLayoutRows`, `statementGapBefore`).
enum StmtLayoutRows {
    static let numberThenLetter = "^(\\d{1,2}\\s*[.)])\\s*(\\(?[a-h]\\s*[.)])\\s*(.*)$"
    static let numberWithRest = "^(\\d{1,2})\\s*([.)])\\s*(.*)$"
    static let numberDelimiter = "^(\\d{1,2})\\s*([.)])"

    /// Classe chaque ligne de l'énoncé (`StatementDisplayLine`).
    static func statementDisplayLines(_ statement: String) -> [StmtDisplayLine] {
        let lines = StmtLayoutLines.normalizeStatementLineBreaks(statement).components(separatedBy: "\n")
        return lines.flatMap { rawLine -> [StmtDisplayLine] in
            let text = rawLine.trimmingCharacters(in: .whitespaces)
            if text.isEmpty { return [StmtDisplayLine(kind: .blank, text: "")] }

            if let combined = StmtRegex.groups(numberThenLetter, in: text, options: [.caseInsensitive]) {
                let delimiter = StmtRegex.groups(numberDelimiter, in: combined[1])
                let number = delimiter?[1] ?? ""
                let mark = delimiter?[2] ?? "."
                let rest = combined[3].isEmpty ? "" : " \(combined[3])"
                return [
                    StmtDisplayLine(kind: .question, text: "\(number)\(mark)"),
                    StmtDisplayLine(kind: .subquestion, text: "\(combined[2])\(rest)"),
                ]
            }

            if StmtRegex.contains(StmtLayoutHeadings.questionHeadingMarker, in: text, options: [.caseInsensitive]) {
                return [StmtDisplayLine(kind: .question, text: text)]
            }

            if StmtRegex.contains(StmtLayoutHeadings.number, in: text) {
                if let groups = StmtRegex.groups(numberWithRest, in: text) {
                    let rest = groups[3]
                    let rebuilt = rest.isEmpty ? "\(groups[1])\(groups[2])" : "\(groups[1])\(groups[2]) \(rest)"
                    return [StmtDisplayLine(kind: .question, text: rebuilt)]
                }
                return [StmtDisplayLine(kind: .question, text: text)]
            }

            if StmtRegex.contains(StmtLayoutHeadings.letter, in: text, options: [.caseInsensitive]) {
                return [StmtDisplayLine(kind: .subquestion, text: text)]
            }

            return [StmtDisplayLine(kind: .body, text: StmtLayoutFlat.trailingTrim(rawLine))]
        }
    }

    /// Transforme les lignes reconnues en blocs de lecture (`StatementLayoutRow`).
    static func statementLayoutRows(_ statement: String) -> [StmtLayoutRow] {
        var rows: [StmtLayoutRow] = []
        var indentLevel = 0
        for line in statementDisplayLines(statement) {
            if line.kind == .question || StmtLayoutHeadings.isStatementHeading(line.text) {
                indentLevel = 0
            } else if line.kind == .subquestion {
                indentLevel = 1
            }
            if line.kind == .blank, rows.isEmpty || rows[rows.count - 1].kind == .blank { continue }
            rows.append(StmtLayoutRow(kind: line.kind, text: line.text, indentLevel: indentLevel))
        }
        while rows.last?.kind == .blank { rows.removeLast() }
        return rows
    }

    /// Type de respiration à insérer avant un repère (`statementGapBefore`).
    static func statementGapBefore(_ rows: [StmtLayoutRow], _ index: Int) -> StmtGap {
        guard index >= 0, index < rows.count else { return .none }
        let current = rows[index]
        let previous = index > 0 ? rows[index - 1] : nil
        if (current.kind != .question && current.kind != .subquestion) { return .none }
        guard let previous, previous.kind != .blank else { return .none }
        if current.kind == .subquestion, previous.kind == .question,
           StmtLayoutHeadings.splitQuestionMarker(previous.text).rest.trimmingCharacters(in: .whitespaces).isEmpty {
            return .none
        }
        return current.kind == .question ? .question : .subquestion
    }
}
