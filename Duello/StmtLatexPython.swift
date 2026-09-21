import Foundation

/// Passe d'affichage du document mathématique — port de
/// `src/utils/statementLayout.ts`.
enum StmtLatexPython {
    static let pythonBlockOpening =
        "^\\s*(?:>>>\\s*)?(?:import\\s+|from\\s+\\S+\\s+import\\s+|def\\s+\\w+\\s*\\(|class\\s+\\w+|for\\s+\\w+\\s+in\\s+|while\\s+|if\\s+|elif\\s+|else\\s*:|return\\b|print\\s*\\()"
    static let pythonSignals =
        "\\b(?:import\\s+(?:numpy|matplotlib|scipy|random|math)\\b|from\\s+\\w+(?:\\.\\w+)*\\s+import\\b|def\\s+\\w+\\s*\\(|for\\s+\\w+\\s+in\\s+range\\s*\\(|while\\s+[^:]+:|return\\b)"

    /// Paires de commandes LaTeX que l'affichage peut fusionner à tort.
    static let gluedCommandSplits: [(String, String)] = [
        ("\\longrightarrowe", "\\longrightarrow e"),
        ("\\longrightarrowln", "\\longrightarrow \\ln"),
        ("\\Longrightarrowe", "\\Longrightarrow e"),
        ("\\Rightarrowe", "\\Rightarrow e"),
        ("\\rightarrowe", "\\rightarrow e"),
        ("\\toe", "\\to e"),
        ("\\tox", "\\to x"),
        ("\\ton", "\\to n"),
        ("\\simP", "\\sim P"),
        ("\\simB", "\\sim B"),
        ("\\simE", "\\sim E"),
        ("\\etaln", "\\eta \\ln"),
        ("\\etale", "\\eta \\le"),
        ("\\leE", "\\le E"),
        ("\\geE", "\\ge E"),
        ("\\timese", "\\times e"),
        ("\\timesn", "\\times n"),
        ("\\timesfluctuation", "\\times \\text{fluctuation}"),
    ]

    /// Répare les dollars orphelins laissés par les transcriptions relues.
    static func repairUnclosedMathDelimiters(_ text: String) -> String {
        let unbalanced = StmtLatexScan.unescapedDollarCount(text) % 2 == 1
        let standaloneDollarLines = text.components(separatedBy: "\n")
            .filter { StmtRegex.contains("^\\s*\\$\\s*$", in: $0) }.count
        var source = literalFix(text, "\\$m=0 et M=1\\.", "$m=0$ et $M=1$.")
        source = literalFix(source, "\\$Y\\. La lettre", "$Y$. La lettre")
        source = literalFix(source, "\\$Z puisque", "$Z$ puisque")
        source = literalFix(source, "\\$f\\(0,y\\)=y²-2ln y\\.", "$f(0,y)=y²-2ln y$.")
        source = literalFix(source, "M \\$⟶ M A₀", "M ⟶ M A₀")
        if unbalanced && source.contains("câ.lJ§I1f, trfc pl") {
            source = source.replacingOccurrences(of: "$", with: "")
        }

        let lines = source.components(separatedBy: "\n")
        return lines.enumerated().map { index, line -> String in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if StmtRegex.contains("^#\\s*\\$$", in: trimmed) {
                return StmtRegex.replaceAll("#\\s*\\$", in: line, template: "")
            }
            if unbalanced, standaloneDollarLines == 1, StmtRegex.contains("^\\$$", in: trimmed) {
                return line.replacingOccurrences(of: "$", with: "")
            }
            let dollars = StmtLatexScan.unescapedDollarCount(line)
            if dollars % 2 == 0 { return line }
            if StmtRegex.contains("^\\s*\\$\\$", in: line), StmtRegex.contains("\\$\\s*$", in: line), dollars == 3 {
                return StmtRegex.replaceMatches("^(\\s*)\\$\\$", in: line) { match, source in
                    source.substring(with: match.range(at: 1)) + "$"
                }
            }
            if StmtRegex.contains("^Si \\$N\\\\geqslant2\\$", in: line), StmtRegex.contains("\\.\\$\\$\\s*$", in: line) {
                return StmtRegex.replaceMatches("\\.\\$\\$\\s*$", in: line) { _, _ in ".$" }
            }
            let nextIsBlank = index == lines.count - 1 || lines[index + 1].trimmingCharacters(in: .whitespaces).isEmpty
            if unbalanced, StmtRegex.contains("^\\s*\\$(?!\\$)", in: line), nextIsBlank,
               !StmtRegex.contains("\\\\(?:begin|end)\\{", in: line) {
                if let punct = StmtRegex.firstMatch("([.,;:])\\s*$", in: line) {
                    let source = line as NSString
                    return source.substring(to: punct.range.location) + "$" + source.substring(from: punct.range.location)
                }
                return line + "$"
            }
            return line
        }.joined(separator: "\n")
    }

    /// Entoure les programmes Python extraits des PDF et restaure les sauts évidents.
    static func formatPythonCodeBlocks(_ text: String) -> String {
        let lines = StmtRegex.replaceAll("\\r\\n?", in: text, template: "\n").components(separatedBy: "\n")
        var output: [String] = []
        var index = 0
        var insideFence = false
        while index < lines.count {
            let line = lines[index]
            if StmtRegex.contains("^\\s*```", in: line) {
                insideFence.toggle()
                output.append(line)
                index += 1
                continue
            }
            if insideFence || !StmtRegex.contains(pythonBlockOpening, in: line) {
                output.append(line)
                index += 1
                continue
            }
            var candidate: [String] = []
            var cursor = index
            while cursor < lines.count && !lines[cursor].trimmingCharacters(in: .whitespaces).isEmpty {
                let expanded = expandFlattenedPythonLine(lines[cursor])
                if !candidate.isEmpty,
                   expanded.allSatisfy({ !StmtRegex.contains(StmtLatexEmphasis.pythonCodeLine, in: $0) && !StmtRegex.contains("^\\s+", in: $0) }) {
                    break
                }
                candidate.append(contentsOf: expanded)
                cursor += 1
            }
            let codeSignals = candidate.filter { StmtRegex.contains(StmtLatexEmphasis.pythonCodeLine, in: $0) }.count
            if codeSignals < 2, !candidate.contains(where: { StmtRegex.contains("^\\s*(?:def|class|import|from)\\b", in: $0) }) {
                output.append(line)
                index += 1
                continue
            }
            output.append("```python")
            output.append(contentsOf: candidate)
            output.append("```")
            index = cursor
        }
        return output.joined(separator: "\n")
    }

    ///
    /// Dérogation de complexité : `mathDocumentForDisplayOnce` compte 53 lignes
    /// (limite : 50) — imbrication de passes de nettoyage reprise telle quelle
    /// de la source ; l'aplatir en sous-fonctions ne ferait que déplacer les
    /// parenthèses. Conservée telle quelle.
    /// Découle les commandes LaTeX fusionnées à tort. Idempotent.
    static func unglueLatexCommands(_ text: String) -> String {
        var result = text
        for (glued, separated) in gluedCommandSplits {
            result = result.replacingOccurrences(of: glued, with: separated)
        }
        return result
    }

    /// Nettoyage mathématique commun, appliqué jusqu'au point fixe.
    static func mathDocumentForDisplay(_ text: String) -> String {
        var stabilized = text
        for _ in 0..<8 {
            let next = mathDocumentForDisplayOnce(stabilized)
            if next == stabilized { return next }
            stabilized = next
        }
        return stabilized
    }

    /// Une passe du nettoyage mathématique (`mathDocumentForDisplayOnce`).
    static func mathDocumentForDisplayOnce(_ text: String) -> String {
        var displayed = StmtLatexScripts.composeScriptsAdjacentToMath(
            StmtLatexBlocks.normalizeSimpleLatexSymbols(
                StmtLatexScan.delimitStandaloneLatexFormulaLines(
                    StmtLatexBlocks.normalizeLatexSourceBlocks(
                        repairUnclosedMathDelimiters(
                            StmtLatexScan.normalizeLegacyPdfGlyphs(
                                StmtLatexScan.removeLegacyPdfConstructionArtifacts(
                                    StmtLatexEmphasis.normalizeUnpairedEmphasis(
                                        StmtLatexEmphasis.stripLatexListOptionLines(
                                            StmtLatexEmphasis.normalizeLatexEmphasisCommands(
                                                StmtCruft.stripStatementCruft(text)
                                            )
                                        )
                                    )
                                )
                            )
                        )
                    )
                )
            )
        )
        displayed = unglueLatexCommands(displayed)
        for _ in 0..<4 {
            let next = StmtLatexScripts.composeScriptsAdjacentToMath(
                StmtLatexScripts.normalizeLatexFormulaCommands(
                    StmtLatexScripts.composeFlattenedScripts(
                        StmtLatexScan.normalizeOrphanLatexParentheses(
                            StmtLatexScan.normalizeLatexDelimiters(
                                StmtLatexBlocks.normalizeSimpleLatexSymbols(
                                    StmtLatexScan.delimitStandaloneLatexFormulaLines(
                                        StmtLatexBlocks.normalizeLatexSourceBlocks(
                                            StmtLatexEmphasis.normalizeUnpairedEmphasis(
                                                StmtLatexEmphasis.normalizeLatexEmphasisCommands(
                                                    StmtLatexEmphasis.stripLatexListOptionLines(
                                                        StmtLatexScan.restoreAccidentalLatexEscapes(displayed)
                                                    )
                                                )
                                            )
                                        )
                                    )
                                )
                            )
                        )
                    )
                )
            )
            let unglued = unglueLatexCommands(next)
            if unglued == displayed { return formatPythonCodeBlocks(displayed) }
            displayed = unglued
        }
        return formatPythonCodeBlocks(displayed)
    }

    /// Découpe une ligne Python aplatie par l'extraction en plusieurs lignes.
    static func expandFlattenedPythonLine(_ line: String) -> [String] {
        let signals = StmtRegex.allMatches(pythonSignals, in: line)
        if signals.count < 2 { return [line] }
        let lookahead = "(?=(?:import\\s+(?:numpy|matplotlib|scipy|random|math)\\b|from\\s+\\w+(?:\\.\\w+)*\\s+import\\b|def\\s+\\w+\\s*\\(|for\\s+\\w+\\s+in\\s+range\\s*\\(|while\\s+[^:]+:|return\\b))"
        var expanded = StmtRegex.replaceAll("\\s+\(lookahead)", in: line, template: "\n")
        expanded = StmtRegex.replaceAll(":\\s+(?=(?:[A-Za-z_]\\w*\\s*(?:=|\\+=|-=|\\*=|\\/=)|return\\b|print\\s*\\())", in: expanded, template: ":\n")
        var indent = 0
        return expanded.components(separatedBy: "\n").map { rawLine in
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
            if StmtRegex.contains("^(?:def|class)\\b", in: trimmed) {
                indent = 0
            } else if StmtRegex.contains("^(?:elif|else)\\b", in: trimmed) {
                indent = max(0, indent - 1)
            } else if StmtRegex.contains("^return\\b", in: trimmed) {
                indent = min(indent, 1)
            }
            let formatted = String(repeating: "    ", count: indent) + trimmed
            if StmtRegex.contains("^(?:def|class|for|while|if|elif|else)\\b.*:\\s*$", in: trimmed) {
                indent += 1
            }
            return formatted
        }
    }

    // MARK: Interne

    /// Réparations déterministes d'une formule délimitée (`normalizeLatexFormulaCommands`).
    static func repairFormulaCommands(_ input: String) -> String {
        var formula = input
        if StmtRegex.contains("\\\\\\\\begin\\{cases\\}", in: formula) {
            formula = StmtRegex.replaceAll("\\\\\\\\(?=[A-Za-z])", in: formula, template: "\\\\")
            formula = StmtRegex.replaceAll("\\\\{3,}", in: formula, template: "\\\\\\\\")
        }
        formula = StmtRegex.replaceAll("\\\\char`?\\\\\\^", in: formula, template: "\\\\textasciicircum")
        formula = StmtRegex.replaceAll("[_^]\\(\\s*\\)", in: formula, template: "")
        formula = StmtRegex.replaceAll("\\\\(?:left|right)\\\\llbracket", in: formula, template: "\\\\llbracket")
        formula = StmtRegex.replaceAll("([^\\\\\\s])\\s+\\\\hline\\b", in: formula, template: "$1 \\\\\\\\ \\\\hline")
        formula = formula.replacingOccurrences(of: "k^{log(x)}}", with: "k^{\\log(x)}")
        formula = formula.replacingOccurrences(of: "-\\\\left(", with: "-\\left(")
        if formula.hasPrefix("1-e^{-a}-a="), formula.contains("\\left("), !formula.contains("\\right") {
            formula = formula.replacingOccurrences(of: "\\,\\text{[illisible]}", with: "\\right)\\,\\text{[illisible]}")
        }
        return StmtLatexScripts.replaceFlattenedScriptsInFormula(formula)
    }

    /// Remplace un motif par un littéral, sans interpréter `$` du gabarit.
    private static func literalFix(_ text: String, _ pattern: String, _ literal: String) -> String {
        StmtRegex.replaceMatches(pattern, in: text) { _, _ in literal }
    }
}
