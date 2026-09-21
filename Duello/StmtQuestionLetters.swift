import Foundation

/// Repères alphabétiques d'un énoncé — port de
/// `src/utils/statementQuestionLetters.ts`.
///
/// « a) », « b. », « (c) » et leurs variantes Markdown en gras. La séparation
/// qui précède le repère empêche de lire `f(a)` comme une sous-question.
struct StmtInlineLetterMarker: Equatable {
    var letter: String
    var marker: String
    var start: Int
    var end: Int
    var parenthesized: Bool
}

enum StmtQuestionLetters {
    static let letterMarker = "(^|[ \\t])((?:\\*\\*)?(?:\\(([a-z])\\)|([a-z])\\s*[.)])(?:\\*\\*)?)"

    /// Repères alphabétiques d'une ligne, hors formule `$…$`.
    static func inlineLetterMarkers(_ line: String) -> [StmtInlineLetterMarker] {
        let source = line as NSString
        return StmtRegex.allMatches(letterMarker, in: line).compactMap { match -> StmtInlineLetterMarker? in
            let leadingLength = match.range(at: 1).length
            let marker = source.substring(with: match.range(at: 2))
            let start = match.range.location + leadingLength
            let parenthesized = match.range(at: 3).location != NSNotFound
            let letter = parenthesized
                ? source.substring(with: match.range(at: 3))
                : source.substring(with: match.range(at: 4))
            let candidate = StmtInlineLetterMarker(
                letter: letter,
                marker: marker,
                start: start,
                end: start + (marker as NSString).length,
                parenthesized: parenthesized
            )
            return isInsideMathFormula(line, start) ? nil : candidate
        }
    }

    /// Vrai si les repères se suivent alphabétiquement (a, b, c…).
    static func areConsecutiveLetterMarkers(_ markers: [StmtInlineLetterMarker]) -> Bool {
        guard markers.count >= 2 else { return false }
        return markers.enumerated().allSatisfy { index, marker in
            index == 0 || (nextScalar(markers[index - 1].letter) ?? "") == marker.letter
        }
    }

    /// `f (a)` est un appel de fonction, contrairement à « … : (a) calculer ».
    static func isFunctionArgumentMarker(_ line: String, _ marker: StmtInlineLetterMarker) -> Bool {
        if !marker.parenthesized || marker.start == 0 { return false }
        let before = (line as NSString).substring(to: marker.start)
        return StmtRegex.contains("(?:^|[^\\p{L}\\p{N}_])[\\p{L}]\\s+$", in: before)
    }

    /// Vrai si les repères forment un alphabet complet à partir de « a ».
    static func isCompleteAlphabeticalSet(_ markers: [StmtInlineLetterMarker]) -> Bool {
        guard markers.count >= 2 else { return false }
        let letters = Set(markers.map(\.letter))
        if letters.count != markers.count || !letters.contains("a") { return false }
        let alphabet = "abcdefghijklmnopqrstuvwxyz"
        guard let last = letters.sorted().last, let lastIndex = alphabet.firstIndex(of: Character(last)) else {
            return false
        }
        for character in alphabet[alphabet.startIndex...lastIndex] where !letters.contains(String(character)) {
            return false
        }
        return true
    }

    /// Vrai si la position tombe entre deux `$` non échappés de la ligne.
    static func isInsideMathFormula(_ line: String, _ index: Int) -> Bool {
        let source = line as NSString
        let chars = Array(source.substring(to: min(index, source.length)))
        var delimiters = 0
        for cursor in 0..<chars.count where chars[cursor] == "$" && (cursor == 0 || chars[cursor - 1] != "\\") {
            delimiters += 1
        }
        return delimiters % 2 == 1
    }

    /// Lettre suivante de l'alphabet (« a » → « b »).
    static func nextScalar(_ letter: String) -> String? {
        let alphabet = "abcdefghijklmnopqrstuvwxyz"
        guard let character = letter.first, let index = alphabet.firstIndex(of: character) else { return nil }
        let next = alphabet.index(after: index)
        return next < alphabet.endIndex ? String(alphabet[next]) : nil
    }
}
