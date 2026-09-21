import Foundation

/// Balayage prose/formule/code et nettoyages de base — port de
/// `src/utils/statementLayout.ts` (section haute).
///
/// `mapOutsideMathAndCode` est le socle : la plupart des passes d'affichage
/// n'agissent que sur la prose, laissant intactes les formules `$…$` et les
/// blocs de code Markdown.
enum StmtLatexScan {
    /// Caractères de contrôle interdits à l'affichage.
    static let forbiddenDisplayControl = "[\u{0000}-\u{0008}\u{000B}\u{000C}\u{000E}-\u{001F}\u{007F}]"

    /// Glyphes privés Adobe → équivalents Unicode interopérables.
    static let legacyPdfGlyphs: [Character: String] = [
        "\u{F8EB}": "\u{239B}", "\u{F8EC}": "\u{239C}", "\u{F8ED}": "\u{239D}",
        "\u{F8EE}": "\u{23A1}", "\u{F8EF}": "\u{23A2}", "\u{F8F0}": "\u{23A3}",
        "\u{F8F1}": "\u{23A7}", "\u{F8F2}": "\u{23A8}", "\u{F8F3}": "\u{23A9}",
        "\u{F8F4}": "\u{23AA}",
        "\u{F8F6}": "\u{239E}", "\u{F8F7}": "\u{239F}", "\u{F8F8}": "\u{23A0}",
        "\u{F8F9}": "\u{23A4}", "\u{F8FA}": "\u{23A5}", "\u{F8FB}": "\u{23A6}",
        "\u{F8FC}": "\u{23AB}", "\u{F8FD}": "\u{23AC}", "\u{F8FE}": "\u{23AD}",
        "\u{F8FF}": "[",
        "\u{F731}": "1", "\u{F732}": "2", "\u{F738}": "8", "\u{F739}": "9",
    ]

    /// Applique une transformation à la prose, hors formules `$` et code.
    static func mapOutsideMathAndCode(
        _ text: String,
        protectMath: Bool = true,
        _ transform: (String) -> String
    ) -> String {
        let chars = Array(text)
        var result = ""
        var proseStart = 0
        var index = 0
        while index < chars.count {
            var delimiter = ""
            if startsWith(chars, index, "```") {
                delimiter = "```"
            } else if chars[index] == "`" {
                delimiter = "`"
            } else if protectMath && chars[index] == "$" && (index == 0 || chars[index - 1] != "\\") {
                delimiter = (index + 1 < chars.count && chars[index + 1] == "$") ? "$$" : "$"
            }
            if delimiter.isEmpty {
                index += 1
                continue
            }
            result += transform(String(chars[proseStart..<index]))
            guard let end = find(chars, delimiter, from: index + delimiter.count) else {
                result += String(chars[index...])
                return result
            }
            let after = end + delimiter.count
            result += String(chars[index..<after])
            index = after
            proseStart = after
        }
        result += transform(String(chars[proseStart...]))
        return result
    }

    /// Nombre de `$` non échappés d'une ligne (`unescapedDollarCount`).
    static func unescapedDollarCount(_ line: String) -> Int {
        StmtRegex.allMatches("(?<!\\\\)\\$", in: line).count
    }

    /// Rétablit les antislashs interprétés comme caractères de contrôle.
    static func restoreAccidentalLatexEscapes(_ text: String) -> String {
        let mapped = mapOutsideMathAndCode(text, protectMath: false) { prose in
            var value = StmtRegex.replaceMatches("\u{0008}", in: prose) { _, _ in "\\b" }
            value = StmtRegex.replaceMatches("\u{000B}", in: value) { _, _ in "\\v" }
            value = StmtRegex.replaceMatches("\u{000C}", in: value) { _, _ in "\\f" }
            return value
        }
        return StmtRegex.replaceAll(forbiddenDisplayControl, in: mapped, template: "")
    }

    /// Remplace les anciens glyphes Adobe de composition verticale.
    static func normalizeLegacyPdfGlyphs(_ text: String) -> String {
        StmtRegex.replaceMatches("[\u{F731}\u{F732}\u{F738}\u{F739}\u{F8EB}-\u{F8FF}]", in: text) { match, source in
            let glyph = source.substring(with: match.range)
            guard let character = glyph.first else { return glyph }
            return legacyPdfGlyphs[character] ?? glyph
        }
    }

    /// Retire les faux accents produits par les glyphes de construction PDF.
    static func removeLegacyPdfConstructionArtifacts(_ text: String) -> String {
        StmtRegex.replaceAll("\\r\\n?", in: text, template: "\n")
            .components(separatedBy: "\n")
            .flatMap { line -> [String] in
                let hasRingPair = line.contains("Å") && line.contains("ã")
                let hasDiaeresisPair = line.contains("Ä") && line.contains("ä")
                if !hasRingPair && !hasDiaeresisPair { return [line] }
                var cleaned = line
                if hasRingPair { cleaned = StmtRegex.replaceAll("[Åã]", in: cleaned, template: "") }
                if hasDiaeresisPair { cleaned = StmtRegex.replaceAll("[Ää]", in: cleaned, template: "") }
                cleaned = StmtRegex.replaceAll("[ \\t]{2,}", in: cleaned, template: " ")
                    .trimmingCharacters(in: .whitespaces)
                return cleaned.isEmpty ? [] : [cleaned]
            }
            .joined(separator: "\n")
    }

    /// Convertit les délimiteurs LaTeX `\[…\]` et `\(…\)` en `$`.
    static func normalizeLatexDelimiters(_ text: String) -> String {
        mapOutsideMathAndCode(text) { prose in
            let block = StmtRegex.replaceMatches("\\\\\\[([\\s\\S]*?)\\\\\\]", in: prose) { match, source in
                let body = source.substring(with: match.range(at: 1))
                return "$$\(body)$$"
            }
            return StmtRegex.replaceMatches("\\\\\\(([\\s\\S]*?)\\\\\\)", in: block) { match, source in
                let body = source.substring(with: match.range(at: 1))
                return "$\(body)$"
            }
        }
    }

    /// Délimite les formules LaTeX complètes laissées seules sur une ligne OCR.
    static func delimitStandaloneLatexFormulaLines(_ text: String) -> String {
        mapOutsideMathAndCode(text) { prose in
            prose.components(separatedBy: "\n").map { line in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                let startsFormula = StmtRegex.contains(
                    "^\\\\(?:left|int|sum|prod|lim|frac|dfrac|sqrt|mathbb|mathcal)\\b",
                    in: trimmed
                )
                let hasCommand = StmtRegex.contains(
                    "\\\\(?:left|right|int|sum|prod|frac|dfrac|sqrt)\\b",
                    in: trimmed
                )
                let hasSentence = StmtRegex.contains("[.!?]\\s+[A-ZÀ-ÖØ-Þ][\\p{L}’'-]{3,}", in: trimmed)
                guard startsFormula, hasCommand, !hasSentence,
                      let range = line.range(of: trimmed) else { return line }
                let prefix = String(line[line.startIndex..<range.lowerBound])
                return "\(prefix)$$\(trimmed)$$"
            }.joined(separator: "\n")
        }
    }

    /// Retire les demi-délimiteurs restés après la conversion des paires valides.
    static func normalizeOrphanLatexParentheses(_ text: String) -> String {
        mapOutsideMathAndCode(text) { prose in
            StmtRegex.replaceAll("\\\\([()])", in: prose, template: "$1")
        }
    }

    // MARK: Utilitaires internes

    /// Vrai si `chars` porte `needle` à partir de `index`.
    static func startsWith(_ chars: [Character], _ index: Int, _ needle: String) -> Bool {
        let needleChars = Array(needle)
        guard index + needleChars.count <= chars.count else { return false }
        return Array(chars[index..<(index + needleChars.count)]) == needleChars
    }

    /// Position de `needle` dans `chars`, à partir de `from`.
    static func find(_ chars: [Character], _ needle: String, from: Int) -> Int? {
        let needleChars = Array(needle)
        guard !needleChars.isEmpty else { return nil }
        var cursor = max(0, from)
        while cursor + needleChars.count <= chars.count {
            if Array(chars[cursor..<(cursor + needleChars.count)]) == needleChars { return cursor }
            cursor += 1
        }
        return nil
    }
}
