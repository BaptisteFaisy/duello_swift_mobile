import Foundation

/// Relève les constructions guidées écrites dans un texte — port de
/// `src/utils/mathOperator.ts` (`parseMathOperators`).
///
/// Le parseur inverse les deux formes produites par `formatMathOperator` :
/// scripts Unicode (`∑ₖ₌₁ⁿ`) et replis explicites (`∑_(k=1)^(n+1)`). Les
/// réponses enregistrées avant l'ajout de l'édition restent donc lisibles.
enum StmtOperatorParse {
    /// Inverse une table de scripts : caractère scripté → caractère simple.
    static func inverseScript(_ table: [Character: String]) -> [Character: String] {
        var inverse: [Character: String] = [:]
        for (plain, scripted) in table {
            guard scripted.count == 1, let character = scripted.first else { continue }
            if inverse[character] == nil { inverse[character] = String(plain) }
        }
        return inverse
    }

    static let fromSubscript = inverseScript(LatexToUnicode.subscripts)
    static let fromSuperscript = inverseScript(LatexToUnicode.superscripts)

    /// Valeur entre parenthèses introduite par un marqueur (`parseParenthesizedValue`).
    static func parseParenthesizedValue(_ text: [Character], _ start: Int, _ marker: Character) -> (value: String, end: Int)? {
        guard StmtLatexScan.startsWith(text, start, "\(marker)(") else { return nil }
        var depth = 1
        var index = start + 2
        while index < text.count {
            let character = text[index]
            if character == "(" {
                depth += 1
            } else if character == ")" {
                depth -= 1
                if depth == 0 {
                    let value = String(text[(start + 2)..<index])
                    return value.isEmpty ? nil : (value, index + 1)
                }
            }
            index += 1
        }
        return nil
    }

    /// Valeur d'un script, explicite ou en caractères Unicode (`parseScriptValue`).
    static func parseScriptValue(
        _ text: [Character],
        _ start: Int,
        _ marker: Character,
        _ inverse: [Character: String]
    ) -> (value: String, end: Int)? {
        if let explicit = parseParenthesizedValue(text, start, marker) { return explicit }
        var value = ""
        var end = start
        while end < text.count, let plain = inverse[text[end]] {
            value += plain
            end += 1
        }
        return value.isEmpty ? nil : (value, end)
    }

    /// Inclut l'espace généré après un opérateur (`rangeEndWithGeneratedSpace`).
    static func rangeEndWithGeneratedSpace(_ text: [Character], _ end: Int) -> Int {
        end < text.count && text[end] == " " ? end + 1 : end
    }

    /// Relève les constructions guidées d'un texte (`parseMathOperators`).
    static func parseMathOperators(_ text: String, _ expectedKind: StmtMathOperatorKind? = nil) -> [StmtParsedMathOperator] {
        let chars = Array(text)
        let kinds: [StmtMathOperatorKind] = expectedKind.map { [$0] } ?? [.limit, .sum, .product, .integral, .exponent]
        var candidates: [StmtParsedMathOperator] = []
        var start = 0
        while start < chars.count {
            var parsed: StmtParsedMathOperator?
            for kind in kinds {
                if let result = parseMathOperatorAt(chars, start, kind) { parsed = result; break }
            }
            if let parsed {
                candidates.append(parsed)
                if expectedKind == nil { start = max(start, parsed.range.end - 1) }
            }
            start += 1
        }
        return candidates
    }

    /// Construction guidée à la position `start`, ou `nil` (`parseMathOperatorAt`).
    static func parseMathOperatorAt(_ text: [Character], _ start: Int, _ kind: StmtMathOperatorKind) -> StmtParsedMathOperator? {
        if kind == .limit {
            guard StmtLatexScan.startsWith(text, start, "lim_("),
                  let content = parseParenthesizedValue(text, start + 3, "_") else { return nil }
            guard let arrow = content.value.firstIndex(of: "→") else { return nil }
            let arrowIndex = content.value.distance(from: content.value.startIndex, to: arrow)
            if arrowIndex <= 0 || arrowIndex == content.value.count - 1 { return nil }
            return StmtParsedMathOperator(
                kind: kind,
                values: ["variable": String(content.value.prefix(arrowIndex)), "target": String(content.value.dropFirst(arrowIndex + 1))],
                range: StmtTextSelection(start: start, end: rangeEndWithGeneratedSpace(text, content.end))
            )
        }
        if kind == .exponent {
            if start > 0, fromSuperscript[text[start - 1]] != nil { return nil }
            guard let exponent = parseScriptValue(text, start, "^", fromSuperscript) else { return nil }
            return StmtParsedMathOperator(
                kind: kind,
                values: ["exponent": exponent.value],
                range: StmtTextSelection(start: start, end: exponent.end)
            )
        }
        return parseScriptOperator(text, start, kind)
    }

    /// Somme, produit ou intégrale bornés (`∑`, `∏`, `∫`).
    static func parseScriptOperator(_ text: [Character], _ start: Int, _ kind: StmtMathOperatorKind) -> StmtParsedMathOperator? {
        let symbol = kind == .sum ? "∑" : (kind == .product ? "∏" : "∫")
        guard StmtLatexScan.startsWith(text, start, symbol) else { return nil }
        guard let lower = parseScriptValue(text, start + symbol.count, "_", fromSubscript),
              let upper = parseScriptValue(text, lower.end, "^", fromSuperscript) else { return nil }

        if kind == .sum || kind == .product {
            guard let equals = lower.value.firstIndex(of: "=") else { return nil }
            let equalsIndex = lower.value.distance(from: lower.value.startIndex, to: equals)
            if equalsIndex <= 0 || equalsIndex == lower.value.count - 1 { return nil }
            return StmtParsedMathOperator(
                kind: kind,
                values: [
                    "index": String(lower.value.prefix(equalsIndex)),
                    "lower": String(lower.value.dropFirst(equalsIndex + 1)),
                    "upper": upper.value,
                ],
                range: StmtTextSelection(start: start, end: rangeEndWithGeneratedSpace(text, upper.end))
            )
        }
        return StmtParsedMathOperator(
            kind: kind,
            values: ["lower": lower.value, "upper": upper.value],
            range: StmtTextSelection(start: start, end: rangeEndWithGeneratedSpace(text, upper.end))
        )
    }
}
