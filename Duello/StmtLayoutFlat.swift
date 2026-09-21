import Foundation

/// Découpage des lignes physiques aplaties par l'extraction — port de
/// `src/utils/statementLayout.ts` (`normalizeStatementLineBreaks` et ses aides).
enum StmtLayoutFlat {
    /// Sépare les listes d'expressions aplaties : « A = … B = … C = … ».
    static func splitLabeledMathList(_ line: String) -> [String] {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if !StmtRegex.contains("^[A-H]\\s*=", in: trimmed) { return [line] }
        let source = trimmed as NSString
        let matches = StmtRegex.allMatches("\\s+(?:et\\s+)?([A-H])\\s*=\\s*", in: trimmed).filter { match in
            let before = source.substring(to: match.range.location).trimmingCharacters(in: .whitespaces)
            return StmtLatexScan.unescapedDollarCount(before) % 2 == 0 || StmtRegex.contains("[;,.]$", in: before)
        }
        if matches.count < 1 { return [line] }

        var boundaries: [Int] = [0]
        for match in matches {
            let whole = source.substring(with: match.range)
            let label = source.substring(with: match.range(at: 1))
            let labelOffset = (whole as NSString).range(of: label, options: .backwards).location
            boundaries.append(match.range.location + labelOffset)
        }
        return boundaries.enumerated().map { index, start in
            let end = index + 1 < boundaries.count ? boundaries[index + 1] : source.length
            return source.substring(with: NSRange(location: start, length: end - start))
                .trimmingCharacters(in: .whitespaces)
        }
    }

    /// Sépare une liste dense `$a \qquad b \qquad c$`.
    static func splitDenseMathList(_ line: String) -> [String] {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard let formula = StmtRegex.groups("^(.*?)\\$([^$\\n]+)\\$(.*?)$", in: trimmed),
              StmtRegex.contains("\\\\+(?:qquad|quad)\\b", in: formula[2]),
              StmtRegex.allMatches("\\\\+ldots\\b", in: formula[2]).count >= 2 else { return [line] }
        let items = StmtRegex.split("\\\\+(?:qquad|quad)\\b", in: formula[2])
            .map { "$\($0.trimmingCharacters(in: .whitespaces))$" }
            .filter { $0 != "$$" }
        if items.count < 2 { return [line] }
        var result: [String] = []
        if !formula[1].trimmingCharacters(in: .whitespaces).isEmpty {
            result.append(formula[1].trimmingCharacters(in: .whitespaces))
        }
        result.append(contentsOf: items)
        if !formula[3].trimmingCharacters(in: .whitespaces).isEmpty {
            result.append(formula[3].trimmingCharacters(in: .whitespaces))
        }
        return result
    }

    /// Sépare les questions numérotées aplaties : « 1. … 2. … 3. … ».
    static func splitFlattenedQuestions(_ line: String) -> [String] {
        if StmtRegex.contains("^(?:\\t| {4,})\\S", in: line) { return [line] }
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        let source = trimmed as NSString
        let markers = StmtRegex.allMatches("(?:^|(?<=\\s))(\\d{1,2})\\s*\\.\\s+(?=\\S)", in: trimmed)
            .compactMap { match -> (number: Int, start: Int)? in
                let start = match.range.location
                guard let number = Int(source.substring(with: match.range(at: 1))) else { return nil }
                let before = source.substring(to: start).trimmingCharacters(in: .whitespaces)
                return number >= 1 && !StmtRegex.contains("\\d\\s*$", in: before) ? (number, start) : nil
            }
        if markers.count < 2 { return [line] }
        for index in 1..<markers.count where markers[index].number <= markers[index - 1].number {
            return [line]
        }
        for marker in markers where StmtLatexScan.unescapedDollarCount(source.substring(to: marker.start)) % 2 == 1 {
            return [line]
        }
        let boundaries = [0] + markers.map(\.start) + [source.length]
        return (0..<(boundaries.count - 1)).map { index in
            source.substring(with: NSRange(location: boundaries[index], length: boundaries[index + 1] - boundaries[index]))
                .trimmingCharacters(in: .whitespaces)
        }
    }

    /// Répare les délimiteurs perdus quand deux colonnes de questions ont fusionné.
    static func repairSplitQuestionMath(_ line: String) -> String {
        guard let match = StmtRegex.firstMatch(StmtLayoutHeadings.questionMarker, in: line),
              StmtLatexScan.unescapedDollarCount(line) % 2 == 1 else { return line }
        let source = line as NSString
        let markerText = source.substring(with: match.range)
        let rest = source.substring(from: match.range.location + match.range.length)

        if StmtRegex.contains("^\\s*\\$", in: rest), StmtRegex.contains(";\\s*$", in: line) {
            return StmtRegex.replaceMatches(";\\s*$", in: line) { _, _ in "$;" }
        }
        if StmtRegex.contains("^\\s*\\\\forall a,?\\s+b\\\\b", in: rest), line.contains("(a$") {
            let withoutMisplacedDollar = removingFirstDollar(line)
            let end = StmtRegex.replaceMatches(";\\s*$", in: withoutMisplacedDollar) { _, _ in "$;" }
            let cut = (markerText as NSString).length
            let remainder = (end as NSString).substring(from: cut).trimmingCharacters(in: .whitespaces)
            return "\(markerText) $\(remainder)"
        }
        if StmtRegex.contains("^\\s*\\\\(?:forall|exists)\\b", in: rest) {
            return "\(markerText) $\(rest.trimmingCharacters(in: .whitespaces))"
        }
        return line
    }

    /// Un petit nombre seul sur sa ligne est un numéro de page résiduel.
    static func isStandalonePdfPageNumber(_ line: String) -> Bool {
        StmtRegex.contains("^\\d{1,2}$", in: line.trimmingCharacters(in: .whitespaces))
    }

    /// Répare les fractions imbriquées dont les étages ont été détachés.
    static func repairNestedFractionContinuation(_ lines: [String]) -> [String] {
        var result: [String] = []
        var index = 0
        while index < lines.count {
            if StmtRegex.contains("^H\\s*=\\s*1/1$", in: lines[index].trimmingCharacters(in: .whitespaces)),
               index + 1 < lines.count, StmtRegex.contains("^1\\s*\\+\\s*$", in: lines[index + 1].trimmingCharacters(in: .whitespaces)),
               index + 2 < lines.count, StmtRegex.contains("^1\\s*\\+\\s*1/2$", in: lines[index + 2].trimmingCharacters(in: .whitespaces)) {
                result.append("H = 1/(1 + 1/(1 + 1/2))")
                index += 3
            } else {
                result.append(lines[index])
                index += 1
            }
        }
        return result
    }

    /// Rattache une continuation numérique à la dernière expression étiquetée.
    static func joinLabeledMathContinuations(_ lines: [String]) -> [String] {
        var result: [String] = []
        var active = false
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if StmtRegex.contains("^[A-H]\\s*=", in: trimmed) {
                active = true
                result.append(line)
                continue
            }
            if active, StmtRegex.contains("^\\d+(?:[.,]\\d+)?\\s*[+−*/×]", in: trimmed) {
                result[result.count - 1] = "\(trailingTrim(result[result.count - 1])) \(trimmed)"
                continue
            }
            active = false
            result.append(line)
        }
        return result
    }

    /// Retire les espaces de fin de chaîne (`trimEnd`).
    static func trailingTrim(_ value: String) -> String {
        StmtRegex.replaceAll("\\s+$", in: value, template: "")
    }

    /// Retire la première occurrence de `$` (comme `line.replace('$', '')`).
    private static func removingFirstDollar(_ line: String) -> String {
        guard let range = line.range(of: "$") else { return line }
        return line.replacingCharacters(in: range, with: "")
    }
}
