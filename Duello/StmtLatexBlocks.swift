import Foundation

/// Environnements et symboles LaTeX de document — port de
/// `src/utils/statementLayout.ts`.
enum StmtLatexBlocks {
    /// Commande LaTeX suivie d'une commande dépliable (`\sim\mathcal{P}`).
    static let unfoldableAfterCommand =
        "\\\\([A-Za-z]+)(\\\\(?:text|operatorname|mathrm)\\s*\\{[A-Za-z]+\\}|\\\\(?:mathcal|mathbb)\\s*\\{[A-Za-z]+\\}|\\\\(?:mathcal|mathbb)\\s+[A-Za-z]|\\\\(?:ln|lim)(?![A-Za-z]))(?![A-Za-z])"

    /// Groupe à accolades équilibrées à partir de `start`, ou `nil`.
    static func balancedLatexGroup(_ text: NSString, _ start: Int) -> (body: String, end: Int)? {
        guard start < text.length, text.character(at: start) == 0x7B else { return nil }
        var depth = 1
        var cursor = start + 1
        while cursor < text.length && depth > 0 {
            let char = text.character(at: cursor)
            if char == 0x7B { depth += 1 } else if char == 0x7D { depth -= 1 }
            cursor += 1
        }
        guard depth == 0 else { return nil }
        let body = text.substring(with: NSRange(location: start + 1, length: cursor - 1 - (start + 1)))
        return (body, cursor)
    }

    /// Convertit les environnements LaTeX de document que le lecteur ne comprend pas.
    static func normalizeLatexSourceBlocks(_ text: String) -> String {
        let withLiteralBlocks = literalBlocksPass(text)
        let withoutRedundantWrappers = StmtLatexScan.mapOutsideMathAndCode(withLiteralBlocks, protectMath: false) { prose in
            StmtRegex.replaceMatches("\\\\\\[([\\s\\S]*?)\\\\\\]", in: prose) { match, source in
                let body = source.substring(with: match.range(at: 1))
                return body.contains("$") ? body : source.substring(with: match.range)
            }
        }
        let result = environmentBlocksPass(withoutRedundantWrappers)
        return StmtRegex.replaceAll("\\n{3,}", in: result, template: "\n\n")
    }

    /// Remplace hors formule les commandes dont le symbole Unicode est univoque.
    static func normalizeSimpleLatexSymbols(_ text: String) -> String {
        StmtLatexScan.mapOutsideMathAndCode(text) { prose in
            var value = replaceLatexFractionsInProse(prose)
            value = StmtRegex.replaceMatches(unfoldableAfterCommand, in: value) { match, source in
                let command = source.substring(with: match.range(at: 1))
                let unfold = source.substring(with: match.range(at: 2))
                return "\\\(command) \(unfold)"
            }
            value = StmtRegex.replaceAll("\\\\(?:tiny|scriptsize|footnotesize|small|normalsize|large|Large|LARGE|huge|Huge)\\b", in: value, template: "")
            value = StmtRegex.replaceAll("\\\\(?:text|operatorname|mathrm)\\s*\\{([^{}]*)\\}", in: value, template: "$1")
            value = StmtRegex.replaceAll("\\\\mathbb(?:\\s*\\{\\s*R\\s*\\}|\\s+R\\b)", in: value, template: "ℝ")
            value = StmtRegex.replaceAll("\\\\mathbb(?:\\s*\\{\\s*N\\s*\\}|\\s+N\\b)", in: value, template: "ℕ")
            value = StmtRegex.replaceAll("\\\\mathbb(?:\\s*\\{\\s*C\\s*\\}|\\s+C\\b)", in: value, template: "ℂ")
            value = StmtRegex.replaceAll("\\\\mathbb(?:\\s*\\{\\s*Z\\s*\\}|\\s+Z\\b)", in: value, template: "ℤ")
            value = StmtRegex.replaceAll("\\\\mathbb(?:\\s*\\{\\s*Q\\s*\\}|\\s+Q\\b)", in: value, template: "ℚ")
            value = StmtRegex.replaceAll("\\\\mathbb(?:\\s*\\{\\s*P\\s*\\}|\\s+P\\b)", in: value, template: "ℙ")
            value = StmtRegex.replaceAll("\\\\(?:mathcal|mathbb)\\s*\\{([^{}]*)\\}", in: value, template: "$1")
            value = StmtRegex.replaceAll("\\\\(?:mathcal|mathbb)\\s+([A-Za-z])", in: value, template: "$1")
            value = StmtRegex.replaceAll("\\\\infty\\b", in: value, template: "∞")
            value = StmtRegex.replaceAll("\\\\notin\\b", in: value, template: "∉")
            value = StmtRegex.replaceAll("\\\\forall\\b", in: value, template: "∀")
            value = StmtRegex.replaceAll("\\\\exists\\b", in: value, template: "∃")
            value = StmtRegex.replaceAll("\\\\in\\b", in: value, template: "∈")
            value = StmtRegex.replaceAll("\\\\to\\b", in: value, template: "→")
            value = StmtRegex.replaceAll("\\\\prime\\b", in: value, template: "′")
            value = StmtRegex.replaceAll("\\\\sum\\b", in: value, template: "∑")
            value = StmtRegex.replaceAll("\\\\prod\\b", in: value, template: "∏")
            value = StmtRegex.replaceAll("\\\\int\\b", in: value, template: "∫")
            value = StmtRegex.replaceAll("\\\\lim\\b", in: value, template: "lim")
            value = StmtRegex.replaceAll("\\\\ln\\b", in: value, template: "ln")
            value = StmtRegex.replaceAll("\\\\(?:left|right)\\b", in: value, template: "")
            value = StmtRegex.replaceAll("\\\\sqrt\\s*", in: value, template: "√")
            value = StmtRegex.replaceAll("ℝ\\\\\\[", in: value, template: "ℝ∖[")
            value = StmtRegex.replaceAll("[_^]\\(\\s*\\)", in: value, template: "")
            value = StmtRegex.replaceAll("[_^]\\(([⎛⎜⎝⎞⎟⎠])\\)", in: value, template: "$1")
            value = StmtRegex.replaceAll("[_^]\\((′{1,2}|[+−]?∞|[+−×=*≤≥∈∣])\\)", in: value, template: "$1")
            return value
        }
    }

    /// Remplace `\frac{a}{b}` hors formule par `(a)/(b)`.
    static func replaceLatexFractionsInProse(_ prose: String) -> String {
        let ns = prose as NSString
        var result = ""
        var cursor = 0
        for match in StmtRegex.allMatches("\\\\(?:d|t)?frac\\s*(?=\\{)", in: prose) {
            let offset = match.range.location
            if offset < cursor { continue }
            guard let numerator = balancedLatexGroup(ns, offset + match.range.length),
                  let denominator = balancedLatexGroup(ns, numerator.end) else { continue }
            result += ns.substring(with: NSRange(location: cursor, length: offset - cursor))
            result += "(\(numerator.body))/(\(denominator.body))"
            cursor = denominator.end
        }
        return result + ns.substring(from: cursor)
    }

    // MARK: Passes internes

    /// Convertit les environnements littéraux (verbatim, tabular, texorpdfstring).
    private static func literalBlocksPass(_ text: String) -> String {
        var value = StmtRegex.replaceMatches(
            "\\\\texorpdfstring\\s*\\{((?:[^{}]|\\{(?:[^{}]|\\{[^{}]*\\})*\\})*)\\}\\s*\\{(?:[^{}]|\\{(?:[^{}]|\\{[^{}]*\\})*\\})*\\}",
            in: text
        ) { match, source in
            source.substring(with: match.range(at: 1))
        }
        value = StmtRegex.replaceAll("\\\\qquadet\\b", in: value, template: "\\\\qquad\\\\text{et}")
        value = StmtRegex.replaceAll("\\\\subsetVect\\b", in: value, template: "\\\\subset \\\\operatorname{Vect}")
        value = StmtRegex.replaceAll("\\\\mathbb\\^\\*", in: value, template: "\\\\mathbb N^*")
        value = StmtRegex.replaceMatches(
            "\\\\begin\\{verbatim\\}\\s*\\n?([\\s\\S]*?)\\n?\\s*\\\\end\\{verbatim\\}",
            in: value
        ) { match, source in
            let body = source.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines)
            return "\n```text\n\(body)\n```\n"
        }
        return StmtRegex.replaceMatches(
            "\\\\begin\\{tabular\\}\\{[^}\\n]*\\}([\\s\\S]*?)\\\\end\\{tabular\\}",
            in: value
        ) { match, source in
            let body = source.substring(with: match.range(at: 1))
            var cleaned = StmtRegex.replaceAll("\\\\hline\\s*", in: body, template: "")
            cleaned = StmtRegex.replaceAll("\\\\\\\\", in: cleaned, template: "\n")
            return cleaned.components(separatedBy: "\n").map { row in
                StmtRegex.replaceAll("\\s*&\\s*", in: row.trimmingCharacters(in: .whitespaces), template: " | ")
            }.filter { !$0.isEmpty }.joined(separator: "\n")
        }
    }

    /// Convertit align/cases/figure en équivalents lisibles, hors formule.
    private static func environmentBlocksPass(_ text: String) -> String {
        StmtLatexScan.mapOutsideMathAndCode(text) { prose in
            var value = StmtRegex.replaceMatches(
                "\\\\begin\\{align\\*?\\}([\\s\\S]*?)\\\\end\\{align\\*?\\}",
                in: prose
            ) { match, source in
                "$\\begin{aligned}\(source.substring(with: match.range(at: 1)))\\end{aligned}$"
            }
            value = StmtRegex.replaceMatches(
                "\\\\begin\\{(cases|pmatrix|bmatrix|array)\\}([\\s\\S]*?)\\\\end\\{\\1\\}",
                in: value
            ) { match, source in
                let environment = source.substring(with: match.range(at: 1))
                let body = source.substring(with: match.range(at: 2))
                return "$\\begin{\(environment)}\(body)\\end{\(environment)}$"
            }
            value = StmtRegex.replaceAll("\\\\(?:begin|end)\\{(?:abstract|displayquote)\\}\\s*", in: value, template: "")
            value = StmtRegex.replaceAll("\\\\(?:begin|end)\\{figure\\}(?:\\[[^\\]\\n]*\\])?\\s*", in: value, template: "")
            value = StmtRegex.replaceAll("^\\s*\\\\maketitle\\s*$", in: value, options: [.anchorsMatchLines], template: "")
            value = StmtRegex.replaceAll("^\\s*\\\\captionsetup\\{[^\\n]*\\}\\s*$", in: value, options: [.anchorsMatchLines], template: "")
            value = StmtRegex.replaceAll("\\\\quad\\b", in: value, template: " ")
            value = StmtRegex.replaceAll("\\\\newline\\b", in: value, template: "\n")
            return value
        }
    }
}
