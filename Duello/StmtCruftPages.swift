import Foundation

/// Mentions de page et nettoyage de prose — port de `src/utils/statementCruft.ts`.
///
/// La liste s'arrête aux nombres : « 10 pages » n'est jamais touché. Le
/// nettoyage ne s'applique qu'aux segments où une mention a réellement été
/// retirée : la typographie du reste n'est jamais modifiée.
enum StmtCruftPages {
    static let pageMention =
        "\\b(?:de\\s+l[ae'’\\s]*?(?:premi[èe]re|derni[èe]re|seconde|deuxi[èe]me|troisi[èe]me)\\s+pages?(?:\\s+(?:précédente|suivante|ci-contre))?|pages?\\s+(?:précédentes?|suivantes?|ci-contre)|[Ll][’']énoncé\\s+comporte\\s+\\d+\\s+pages?\\.?|de\\s+la\\s+pages?\\s*\\d+(?:\\s*\\/\\s*\\d+)?|\\d{1,3}\\s*\\/\\s*\\d{1,3}\\s*tournez\\s+la\\s+pages?\\s*(?:[,;]?\\s*(?:s\\.?\\s*v\\.?\\s*p?\\.?|svp|s'il\\s+vous\\s+pla[îi]t))?\\s*[.!?]*\\s*(?![\\p{L}\\p{N}])|tournez\\s+la\\s+pages?\\s*(?:[,;]?\\s*(?:s\\.?\\s*v\\.?\\s*p?\\.?|svp|s'il\\s+vous\\s+pla[îi]t))?\\s*[.!?]*\\s*(?![\\p{L}\\p{N}])|(?:pages?\\s*(?:n[°ºo]\\s*)?\\d+|pp?\\.\\s*\\d+)(?:\\s*\\/\\s*\\d+|\\s*(?:[-–—à,]\\s*|\\s+et\\s+)\\d+)*)"
    static let pageMarkerLine =
        "^[^\\p{L}\\p{N}[\\]$\\\\]*\\[?\\s*pages?\\s*(?:n[°ºo]\\s*)?\\d+(?:\\s*\\/\\s*\\d+)?(?:\\s*\\(\\s*p\\.?\\s*\\d+\\s*\\))?\\s*\\]?\\s*(?:[-–—]\\s*)?(?:[A-Z]{1,4}|\\[[^\\][()]{1,40}\\])?[\\s\\-–—=.!?]*$"
    static let tournezPageLine =
        "^(?:\\s*(?:[-–—*#]|\\d{1,3}(?:\\s*\\/\\s*\\d{1,3})?(?!\\d)|\\$\\s*\\\\frac\\s*\\{\\d+\\}\\s*\\{\\d+\\}\\s*\\$)\\s*)*(?:\\$_\\{?\\d+\\s*\\/\\s*\\d+\\}\\$\\s*)?tournez\\s+la\\s+pages?\\s*(?:[,;]?\\s*(?:s\\.?\\s*v\\.?\\s*p?\\.?|svp|s'il\\s+vous\\s+pla[îi]t))?\\s*[.!?]*\\s*$"
    static let ocrPageFooterLine = "^[^$\\n]{0,80}\\bPage\\s+\\d+\\s*\\/\\s*\\d+\\s*$"
    static let pageNumberingLine = "numérot(?:er|ez)\\s+vos\\s+pages"
    static let barePageNumberLine = "^\\d{1,3}\\s*\\/\\s*\\d{1,3}$"

    static func isPageMarkerLine(_ trimmed: String) -> Bool {
        if trimmed.count > StmtCruftRules.maxMetadataLineLength { return false }
        return StmtRegex.contains(pageMarkerLine, in: trimmed, options: [.caseInsensitive])
    }

    static func isTournezPageLine(_ trimmed: String) -> Bool {
        if trimmed.count > StmtCruftRules.maxMetadataLineLength { return false }
        // Garde-fou linéaire : sans « tournez », le motif imbriqué ne peut aboutir.
        if !StmtRegex.contains("tournez", in: trimmed, options: [.caseInsensitive]) { return false }
        return StmtRegex.contains(tournezPageLine, in: trimmed, options: [.caseInsensitive])
    }

    static func isOcrPageFooterLine(_ trimmed: String) -> Bool {
        if trimmed.count > StmtCruftRules.maxMetadataLineLength { return false }
        return StmtRegex.contains(ocrPageFooterLine, in: trimmed, options: [.caseInsensitive])
    }

    static func isPageNumberingLine(_ trimmed: String) -> Bool {
        StmtRegex.contains(pageNumberingLine, in: trimmed, options: [.caseInsensitive])
    }

    /// Retire les mentions de page d'un segment de prose et recoud les espaces.
    static func cleanProseSegment(_ segment: String) -> String {
        if !StmtRegex.contains(pageMention, in: segment, options: [.caseInsensitive]) { return segment }
        var value = StmtRegex.replaceAll(pageMention, in: segment, options: [.caseInsensitive], template: "")
        value = StmtRegex.replaceAll("\\(\\s*\\)", in: value, template: "")
        value = StmtRegex.replaceAll("\\s+\\)", in: value, template: ")")
        value = StmtRegex.replaceAll("[ \\t]{2,}", in: value, template: " ")
        value = StmtRegex.replaceAll(" +([.!?;:,])", in: value, template: "$1")
        value = StmtRegex.replaceAll("\\s+([—–-])\\s*$", in: value, options: [.anchorsMatchLines], template: "$1")
        value = StmtRegex.replaceMatches("^[ \\t]+", in: value, options: [.anchorsMatchLines]) { match, source in
            match.range.location == 0 ? source.substring(with: match.range) : ""
        }
        return value
    }

    /// Retire les mentions de page littérales du texte hors formule et code.
    static func removeWordPageRefs(_ text: String) -> String {
        let chars = Array(text)
        var result = ""
        var proseStart = 0
        var index = 0
        while index < chars.count {
            var delimiter = ""
            if chars[index] == "`" {
                if index + 2 < chars.count, chars[index + 1] == "`", chars[index + 2] == "`" {
                    delimiter = "```"
                } else {
                    delimiter = "`"
                }
            } else if chars[index] == "$" && (index == 0 || chars[index - 1] != "\\") {
                delimiter = (index + 1 < chars.count && chars[index + 1] == "$") ? "$$" : "$"
            }
            if delimiter.isEmpty {
                index += 1
                continue
            }
            result += cleanProseSegment(String(chars[proseStart..<index]))
            let delim = Array(delimiter)
            var found = -1
            var cursor = index + delim.count
            while cursor + delim.count <= chars.count {
                if Array(chars[cursor..<(cursor + delim.count)]) == delim { found = cursor; break }
                cursor += 1
            }
            if found < 0 {
                result += String(chars[index...])
                return result
            }
            let after = found + delim.count
            result += String(chars[index..<after])
            index = after
            proseStart = after
        }
        result += cleanProseSegment(String(chars[proseStart...]))
        return result
    }

    /// Nettoie les mentions de page des fragments `\text{…}` et `\textit{…}`.
    static func cleanMathTextPageRefs(_ text: String) -> String {
        if !StmtRegex.contains("\\\\(?:text|textit)\\s*\\{", in: text, options: [.caseInsensitive]) { return text }
        let segments = text.components(separatedBy: "```")
        return segments.enumerated().map { pair in
            pair.offset % 2 == 1 ? pair.element : cleanSegmentMathText(pair.element)
        }.joined(separator: "```")
    }

    static func cleanSegmentMathText(_ segment: String) -> String {
        var result = ""
        var cursor = 0
        while true {
            let tail = String(Array(segment)[cursor...])
            guard let match = StmtRegex.firstMatch("\\\\(?:text|textit)\\s*\\{", in: tail, options: [.caseInsensitive]) else {
                result += tail
                return result
            }
            let openBrace = cursor + match.range.location + match.range.length - 1
            var depth = 1
            var close = openBrace + 1
            let chars = Array(segment)
            while close < chars.count && depth > 0 {
                if chars[close] == "{" { depth += 1 }
                else if chars[close] == "}" { depth -= 1 }
                close += 1
            }
            if depth != 0 {
                result += String(chars[cursor...])
                return result
            }
            let content = String(chars[(openBrace + 1)..<(close - 1)])
            result += String(chars[cursor...openBrace])
            result += StmtRegex.contains("page", in: content, options: [.caseInsensitive]) ? cleanProseSegment(content) : content
            result += "}"
            cursor = close
        }
    }
}
