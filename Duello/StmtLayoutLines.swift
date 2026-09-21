import Foundation

/// Recollage des lignes logiques d'un énoncé — port de
/// `src/utils/statementLayout.ts` (`normalizeStatementLineBreaks`).
enum StmtLayoutLines {
    /// Réduit les retours à la ligne d'habillage PDF sans toucher aux repères.
    static func normalizeStatementLineBreaks(_ statement: String) -> String {
        logicalLines(splitPhysicalLines(statement)).joined(separator: "\n")
    }

    /// Découpe et répare les lignes physiques d'un énoncé.
    static func splitPhysicalLines(_ statement: String) -> [String] {
        let raw = StmtRegex.replaceAll("\\r\\n?", in: statement, template: "\n")
            .components(separatedBy: "\n")
        var lines: [String] = []
        for line in raw { lines.append(contentsOf: splitAtSemicolons(line)) }
        lines = lines.flatMap(StmtLayoutFlat.splitLabeledMathList)
        lines = lines.flatMap(StmtLayoutFlat.splitDenseMathList)
        lines = lines.flatMap(StmtLayoutFlat.splitFlattenedQuestions)
        lines = lines.map(StmtLayoutFlat.repairSplitQuestionMath)
        return lines.filter { !StmtLayoutFlat.isStandalonePdfPageNumber($0) }
    }

    /// Sépare « … ; 2. … » en deux lignes physiques.
    static func splitAtSemicolons(_ line: String) -> [String] {
        var parts: [String] = []
        var rest = line
        while true {
            guard let semicolon = rest.firstIndex(of: ";") else {
                parts.append(rest)
                break
            }
            let after = String(rest[rest.index(after: semicolon)...])
            guard let groups = StmtRegex.groups("^\\s*(\\d{1,2})\\s*\\.", in: after) else {
                parts.append(rest)
                break
            }
            parts.append(String(rest[...semicolon]))
            rest = "\(groups[1])." + String(after.dropFirst(groups[0].count))
        }
        return parts
    }

    ///
    /// Dérogation de complexité : `logicalLines` compte 55 lignes (limite : 50).
    /// Boucle à état partagé (pile logique, insideMath) muté à chaque ligne :
    /// la scinder exigerait de transporter cet état entre sous-fonctions.
    /// Conservée telle quelle.
    /// Recolle les lignes physiques en lignes logiques.
    static func logicalLines(_ physicalLines: [String]) -> [String] {
        var logical: [String] = []
        var insideMath = false
        let normalized = StmtLayoutFlat.joinLabeledMathContinuations(
            StmtLayoutFlat.repairNestedFractionContinuation(physicalLines)
        )

        for physicalLine in normalized {
            let current = physicalLine.trimmingCharacters(in: .whitespaces)
            let hasExplicitIndentation = StmtRegex.contains("^(?:\\t| {4,})\\S", in: physicalLine)
            if current.isEmpty {
                if !insideMath, !logical.isEmpty, logical[logical.count - 1] != "" { logical.append("") }
                continue
            }

            let previous = logical.last
            let startsQuestion = StmtLayoutHeadings.isQuestionOpening(current)
            let continuationOfMath = insideMath && !startsQuestion
            let isProtectedBlock = StmtRegex.contains("^@@[a-z]+:\\d+@@$", in: current)
            let followsProtectedBlock = previous.map { StmtRegex.contains("^@@[a-z]+:\\d+@@$", in: $0) } ?? false

            if let previous, !previous.isEmpty,
               !StmtLayoutHeadings.isStatementHeading(current),
               !hasExplicitIndentation,
               !isProtectedBlock,
               !followsProtectedBlock,
               continuationOfMath || (!startsQuestion
                    && !StmtRegex.contains("^[A-H]\\s*=", in: current)
                    && !current.hasPrefix("$")
                    && (StmtRegex.contains("^[a-zà-öø-ÿ]", in: current)
                        || StmtRegex.contains("^[]−-√…)},.;:+×=]", in: current)
                        || StmtRegex.contains("[,;:]\\s*$", in: previous))) {
                let separator = StmtRegex.contains("^[])},.;:!?]", in: current) ? "" : " "
                logical[logical.count - 1] = "\(previous)\(separator)\(current)"
            } else {
                logical.append(hasExplicitIndentation ? StmtLayoutFlat.trailingTrim(physicalLine) : current)
            }

            let dollarCount = StmtLatexScan.unescapedDollarCount(current)
            if continuationOfMath {
                insideMath = dollarCount % 2 == 0
            } else if startsQuestion {
                let firstDollar = StmtRegex.firstMatch("(?<!\\\\)\\$", in: current)?.range.location ?? -1
                let marker = StmtRegex.firstMatch(StmtLayoutHeadings.questionMarker, in: current)
                let source = current as NSString
                let prefix = firstDollar >= 0 ? source.substring(to: firstDollar) : ""
                let markerText = marker.map { source.substring(with: $0.range) } ?? ""
                insideMath = dollarCount % 2 == 1 && marker != nil
                    && prefix.trimmingCharacters(in: .whitespaces) == markerText.trimmingCharacters(in: .whitespaces)
            } else if dollarCount % 2 == 1 {
                insideMath = true
            }
        }
        return logical
    }
}
