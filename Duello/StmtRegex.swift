import Foundation

/// Petites aides `NSRegularExpression` partagées par le lot « Stmt ».
///
/// Les modules source Expo (`statementLayout.ts`, `statementQuestions.ts`,
/// `markingSchemeDisplay.ts`, …) s'appuient partout sur les expressions
/// régulières JavaScript. ICU (`NSRegularExpression`) en couvre la syntaxe
/// utile : classes `\p{L}`/`\p{N}`, regards arrière, groupes capturants,
/// remplacements `$1`. Ce fichier n'expose que des primitives, aucun type
/// public métier.
enum StmtRegex {
    /// Compile un motif constant. Un motif invalide retombe sur le motif vide
    /// (jamais le cas ici : tous les motifs sont littéraux et vérifiés).
    static func compile(
        _ pattern: String,
        options: NSRegularExpression.Options = []
    ) -> NSRegularExpression {
        if let regex = try? NSRegularExpression(pattern: pattern, options: options) {
            return regex
        }
        // Motif vide : toujours valide, sert de repli neutre (aucune correspondance).
        return try! NSRegularExpression(pattern: "")
    }

    /// Premier couple `(NSRange, NSString)` trouvé, ou `nil`.
    static func firstMatch(
        _ pattern: String,
        in text: String,
        options: NSRegularExpression.Options = []
    ) -> (range: NSRange, source: NSString)? {
        let regex = compile(pattern, options: options)
        let source = text as NSString
        guard let match = regex.firstMatch(
            in: text,
            range: NSRange(location: 0, length: source.length)
        ) else { return nil }
        return (match.range, source)
    }

    /// Vrai si le motif apparaît au moins une fois.
    static func contains(
        _ pattern: String,
        in text: String,
        options: NSRegularExpression.Options = []
    ) -> Bool {
        firstMatch(pattern, in: text, options: options) != nil
    }

    /// Groupes capturants du premier match (`groups[0]` = match entier), ou `nil`.
    static func groups(
        _ pattern: String,
        in text: String,
        options: NSRegularExpression.Options = []
    ) -> [String]? {
        let regex = compile(pattern, options: options)
        let source = text as NSString
        guard let match = regex.firstMatch(
            in: text,
            range: NSRange(location: 0, length: source.length)
        ) else { return nil }
        return (0..<match.numberOfRanges).map { index in
            let range = match.range(at: index)
            return range.location == NSNotFound ? "" : source.substring(with: range)
        }
    }

    /// Remplacement global par gabarit (`$1`, `$2`…), comme `replace(/g)`.
    static func replaceAll(
        _ pattern: String,
        in text: String,
        options: NSRegularExpression.Options = [],
        template: String
    ) -> String {
        let regex = compile(pattern, options: options)
        return regex.stringByReplacingMatches(
            in: text,
            range: NSRange(text.startIndex..<text.endIndex, in: text),
            withTemplate: template
        )
    }

    /// Remplacement global par transformation, comme `replace(/g, fn)`.
    static func replaceMatches(
        _ pattern: String,
        in text: String,
        options: NSRegularExpression.Options = [],
        transform: (NSTextCheckingResult, NSString) -> String
    ) -> String {
        let regex = compile(pattern, options: options)
        let source = text as NSString
        let matches = regex.matches(
            in: text,
            range: NSRange(location: 0, length: source.length)
        )
        if matches.isEmpty { return text }
        var result = ""
        var cursor = 0
        for match in matches {
            if match.range.location < cursor { continue }
            let head = NSRange(location: cursor, length: match.range.location - cursor)
            result += source.substring(with: head)
            result += transform(match, source)
            cursor = match.range.location + match.range.length
        }
        result += source.substring(from: cursor)
        return result
    }

    /// Toutes les correspondances, dans l'ordre du texte.
    static func allMatches(
        _ pattern: String,
        in text: String,
        options: NSRegularExpression.Options = []
    ) -> [NSTextCheckingResult] {
        let regex = compile(pattern, options: options)
        return regex.matches(
            in: text,
            range: NSRange(text.startIndex..<text.endIndex, in: text)
        )
    }

    /// Découpe le texte sur un motif (comme `String.split(/re/)`).
    static func split(
        _ pattern: String,
        in text: String,
        options: NSRegularExpression.Options = []
    ) -> [String] {
        let matches = allMatches(pattern, in: text, options: options)
        if matches.isEmpty { return [text] }
        let source = text as NSString
        var parts: [String] = []
        var cursor = 0
        for match in matches {
            parts.append(source.substring(with: NSRange(location: cursor, length: match.range.location - cursor)))
            cursor = match.range.location + match.range.length
        }
        parts.append(source.substring(from: cursor))
        return parts
    }
}
