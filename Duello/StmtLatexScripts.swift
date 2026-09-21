import Foundation

/// Recompose les indices et exposants aplatis par l'extraction PDF, et répare
/// les formules délimitées — port de `src/utils/statementLayout.ts`.
enum StmtLatexScripts {
    /// Corps d'un script aplati acceptable (`safeFlattenedScriptBody`).
    static func safeFlattenedScriptBody(_ body: String) -> Bool {
        let allowed = "^[\\p{L}\\p{N}\\s+=\\-−*/,.():;|!<>[\\]{}'\\\\\u{2192}\u{21D2}\u{21D4}∞∈∉≤≥⩽⩾π₀-₉⁰-⁹]+$"
        if !StmtRegex.contains(allowed, in: body) { return false }
        var depth = 0
        for character in body {
            if character == "{" { depth += 1 } else if character == "}" { depth -= 1 }
            if depth < 0 { return false }
        }
        if depth != 0 { return false }
        let withoutCommands = StmtRegex.replaceAll("\\\\[A-Za-z]+", in: body, template: "")
        return StmtRegex.allMatches("\\p{L}+", in: withoutCommands).allSatisfy { match in
            match.range.length <= 3
        }
    }

    /// `u_(n+1)` → `u_{n+1}` à l'intérieur d'une formule.
    static func replaceFlattenedScriptsInFormula(_ formula: String) -> String {
        let chars = Array(formula)
        var result = ""
        var index = 0
        while index < chars.count {
            let marker = chars[index]
            let previous = index > 0 ? chars[index - 1] : nil
            if (marker != "_" && marker != "^") || index + 1 >= chars.count || chars[index + 1] != "("
                || previous == nil || StmtRegex.contains("\\s", in: String(previous!)) || previous == "}" {
                result += String(chars[index])
                index += 1
                continue
            }
            var cursor = index + 2
            var depth = 1
            while cursor < chars.count && depth > 0 && chars[cursor] != "\n" {
                if chars[cursor] == "(" { depth += 1 } else if chars[cursor] == ")" { depth -= 1 }
                cursor += 1
            }
            if depth != 0 {
                result += String(chars[index])
                index += 1
                continue
            }
            let body = String(chars[(index + 2)..<(cursor - 1)]).trimmingCharacters(in: .whitespaces)
            if body.isEmpty || body.count > 40 || !safeFlattenedScriptBody(body) {
                result += String(chars[index..<cursor])
            } else {
                result += "\(marker){\(body)}"
            }
            index = cursor
        }
        return result
    }

    /// Base parenthésée d'un script aplati (`parenthesizedScriptBase`).
    static func parenthesizedScriptBase(_ prose: [Character], _ index: Int) -> (base: String, cursor: Int)? {
        guard index < prose.count, prose[index] == "(" else { return nil }
        var cursor = index + 1
        var depth = 1
        while cursor < prose.count && depth > 0 && prose[cursor] != "\n" {
            if prose[cursor] == "(" { depth += 1 } else if prose[cursor] == ")" { depth -= 1 }
            cursor += 1
        }
        if depth != 0 { return nil }
        let body = String(prose[(index + 1)..<(cursor - 1)]).trimmingCharacters(in: .whitespaces)
        if body.isEmpty || body.count > 40 || !safeFlattenedScriptBody(body) { return nil }
        return ("(\(body))", cursor)
    }

    /// Base d'une construction guidée recomposée.
    static func composedScriptBase(_ base: String) -> String {
        switch base {
        case "lim": return "\\lim"
        case "∑": return "\\sum"
        case "∏": return "\\prod"
        case "∫": return "\\int"
        default: return base
        }
    }

    /// Recompose les scripts aplatis hors formule et hors code.
    static func composeFlattenedScripts(_ text: String) -> String {
        StmtLatexScan.mapOutsideMathAndCode(text, composeFlattenedScriptsInProse)
    }

    /// `$x$_1(y)` → `$x_1(y)$` : scripts accolés à une formule d'une lettre.
    static func composeScriptsAdjacentToMath(_ text: String) -> String {
        StmtRegex.replaceMatches("\\$([A-Za-z])\\$\\s*([_^])\\(([^)\\n]{1,40})\\)", in: text) { match, source in
            let formula = source.substring(with: match.range(at: 1))
            let marker = source.substring(with: match.range(at: 2))
            let body = source.substring(with: match.range(at: 3))
            guard safeFlattenedScriptBody(body) else { return source.substring(with: match.range) }
            return "$\(formula)\(marker){\(body.trimmingCharacters(in: .whitespaces))}$"
        }
    }

    /// Recompose les indices et exposants explicitement parenthésés.
    static func composeFlattenedScriptsInProse(_ prose: String) -> String {
        let chars = Array(prose)
        var result = ""
        var index = 0
        while index < chars.count {
            let parenthesized = parenthesizedScriptBase(chars, index)
            let base: String
            if let parenthesized {
                base = parenthesized.base
            } else if StmtLatexScan.startsWith(chars, index, "lim") {
                base = "lim"
            } else if StmtRegex.contains("[\\p{L}∑∏∫]", in: String(chars[index])) {
                base = String(chars[index])
            } else {
                base = ""
            }
            let previous = index > 0 ? String(chars[index - 1]) : ""
            if base.isEmpty || (!previous.isEmpty && StmtRegex.contains("[\\p{L}\\p{N}_\\\\^]", in: previous)) {
                result += String(chars[index])
                index += 1
                continue
            }
            let collected = collectScriptParts(chars, parenthesized?.cursor ?? index + base.count)
            let next = collected.cursor < chars.count ? String(chars[collected.cursor]) : ""
            if collected.bodies.isEmpty
                || (!next.isEmpty && StmtRegex.contains("[\\p{L}\\p{N}_]", in: next))
                || collected.bodies.contains(where: { !safeFlattenedScriptBody($0) }) {
                result += String(chars[index])
                index += 1
                continue
            }
            result += "$\(composedScriptBase(base))\(mergedScripts(collected))$"
            index = collected.cursor
        }
        return result
    }

    /// Répare les erreurs de commande déterministes à l'intérieur des formules.
    static func normalizeLatexFormulaCommands(_ text: String) -> String {
        let chars = Array(text)
        var result = ""
        var proseStart = 0
        var index = 0
        while index < chars.count {
            var delimiter = ""
            if StmtLatexScan.startsWith(chars, index, "```") {
                delimiter = "```"
            } else if chars[index] == "`" {
                delimiter = "`"
            } else if chars[index] == "$" && (index == 0 || chars[index - 1] != "\\") {
                delimiter = (index + 1 < chars.count && chars[index + 1] == "$") ? "$$" : "$"
            }
            if delimiter.isEmpty {
                index += 1
                continue
            }
            result += String(chars[proseStart..<index])
            guard let end = StmtLatexScan.find(chars, delimiter, from: index + delimiter.count) else {
                result += String(chars[index...])
                return result
            }
            if delimiter == "`" || delimiter == "```" {
                let after = end + delimiter.count
                result += String(chars[index..<after])
                index = after
                proseStart = after
                continue
            }
            let formula = String(chars[(index + delimiter.count)..<end])
            result += "\(delimiter)\(StmtLatexPython.repairFormulaCommands(formula))\(delimiter)"
            index = end + delimiter.count
            proseStart = index
        }
        result += String(chars[proseStart...])
        return result
    }

    // MARK: Internes

    /// Collecte jusqu'à deux scripts `_(…)`/`^(…)` à partir de `start`.
    private static func collectScriptParts(
        _ prose: [Character],
        _ start: Int
    ) -> (markers: [Character], bodies: [String], cursor: Int) {
        var cursor = start
        var markers: [Character] = []
        var bodies: [String] = []
        while markers.count < 2 {
            var markerCursor = cursor
            while markerCursor < prose.count && (prose[markerCursor] == " " || prose[markerCursor] == "\t") {
                markerCursor += 1
            }
            guard markerCursor < prose.count else { break }
            let marker = prose[markerCursor]
            if marker != "_" && marker != "^" { break }
            cursor = markerCursor + 1
            while cursor < prose.count && (prose[cursor] == " " || prose[cursor] == "\t") { cursor += 1 }
            guard cursor < prose.count, prose[cursor] == "(" else { break }
            let bodyStart = cursor + 1
            var depth = 1
            cursor += 1
            while cursor < prose.count && depth > 0 && prose[cursor] != "\n" {
                if prose[cursor] == "(" { depth += 1 } else if prose[cursor] == ")" { depth -= 1 }
                cursor += 1
            }
            if depth != 0 { break }
            var body = String(prose[bodyStart..<(cursor - 1)]).trimmingCharacters(in: .whitespaces)
            if marker == "_", cursor < prose.count, prose[cursor] == "*",
               StmtRegex.contains("[∈∉]", in: body),
               !(cursor + 1 < prose.count && StmtRegex.contains("[\\p{L}\\p{N}_]", in: String(prose[cursor + 1]))) {
                body += "*"
                cursor += 1
            }
            markers.append(marker)
            bodies.append(body)
        }
        return (markers, bodies, cursor)
    }

    /// Fusionne deux scripts de même marqueur consécutifs.
    private static func mergedScripts(_ collected: (markers: [Character], bodies: [String], cursor: Int)) -> String {
        var markers: [Character] = []
        var bodies: [String] = []
        for (offset, marker) in collected.markers.enumerated() {
            if let last = markers.last, last == marker {
                let joined = "\(bodies[bodies.count - 1]) \(collected.bodies[offset])"
                bodies[bodies.count - 1] = joined.trimmingCharacters(in: .whitespaces)
            } else {
                markers.append(marker)
                bodies.append(collected.bodies[offset])
            }
        }
        return zip(markers, bodies).map { "\($0.0){\($0.1)}" }.joined()
    }
}
