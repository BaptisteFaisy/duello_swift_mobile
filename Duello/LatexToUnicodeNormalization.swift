import Foundation

/// Normalisation d'entrée : glyphes privés PDF, repérage des blocs de code
/// Markdown et nettoyage des espaces d'une formule convertie. Les membres lus
/// depuis `LatexToUnicodeCore` sont élargis à `internal` ; aucun n'est renommé.
extension LatexToUnicode {
    // MARK: Glyphes privés PDF

    /// Codage privé U+F8xx laissé par certains extracteurs PDF (ancienne
    /// police Adobe Symbol) : rendu avec leur caractère Unicode réel.
    private static let glyphesPrivesPdf: [Character: String] = [
        "\u{F8E5}": "⎷", "\u{F8E6}": "⏐", "\u{F8E7}": "⎯",
        "\u{F8E8}": "®", "\u{F8E9}": "©", "\u{F8EA}": "™",
        "\u{F8EB}": "⎛", "\u{F8EC}": "⎜", "\u{F8ED}": "⎝",
        "\u{F8EE}": "⎡", "\u{F8EF}": "⎢", "\u{F8F0}": "⎣",
        "\u{F8F1}": "⎧", "\u{F8F2}": "⎨", "\u{F8F3}": "⎩",
        "\u{F8F4}": "⎪", "\u{F8F5}": "⎮",
    ]

    // MARK: Regex

    /// Commande ou script LaTeX reçu sans les délimiteurs normalement attendus.
    private static let scriptNonDelimiteRegex = try! NSRegularExpression(
        pattern: "(?:^|[^A-Za-zÀ-ÖØ-öø-ÿΑ-ω0-9])(?:lim|det|ker|max|min|sup|inf|sin|cos|tan|ln|exp|[A-Za-zÀ-ÖØ-öø-ÿΑ-ω])[_^](?:\\{[^{}\\n]*\\}|\\\\[a-zA-Z]+|[A-Za-z0-9])"
    )

    /// Blocs de code Markdown : ```lang\n … ```\n
    private static let blocCodeRegex = try! NSRegularExpression(
        pattern: "^```[^\\S\\r\\n]*[a-zA-Z0-9_-]*[^\\S\\r\\n]*\\r?\\n[\\s\\S]*?^```[^\\S\\r\\n]*(?:\\r?\\n|$)",
        options: [.anchorsMatchLines, .dotMatchesLineSeparators]
    )

    static func codeBlockRanges(in texte: String) -> [Range<String.Index>] {
        let full = texte.startIndex..<texte.endIndex
        return blocCodeRegex.matches(in: texte, range: NSRange(full, in: texte))
            .compactMap { Range($0.range, in: texte) }
    }

    static func contientLatexNonDelimite(_ texte: String) -> Bool {
        if texte.contains("\\") { return true }
        let full = NSRange(texte.startIndex..., in: texte)
        return scriptNonDelimiteRegex.firstMatch(in: texte, range: full) != nil
    }

    // MARK: Nettoyage

    static func normaliserGlyphesPrivesPdf(_ texte: String) -> String {
        guard texte.contains(where: { glyphesPrivesPdf[$0] != nil }) else { return texte }
        // `map` produit des `String` (le remplacement peut en compter
        // plusieurs) : il faut les recoller, `String([String])` n'existe pas.
        return texte.map { glyphesPrivesPdf[$0] ?? String($0) }.joined()
    }

    /// Les espaces alignant une matrice multiligne sont significatifs ; pour
    /// une formule ordinaire, l'espacement est ramené à une seule espace.
    static func nettoyerFormuleConvertie(_ converti: String) -> String {
        let propre = converti.trimmingCharacters(in: .whitespacesAndNewlines)
        guard propre.contains("\n") else {
            return propre.replacingOccurrences(
                of: "\\s+", with: " ",
                options: .regularExpression
            )
        }
        let lignes = propre
            .components(separatedBy: "\n")
            .map { $0.replacingOccurrences(of: "[ \\t]+$", with: "", options: .regularExpression) }
        return lignes.joined(separator: "\n")
            .replacingOccurrences(of: "\\n{3,}", with: "\n\n", options: .regularExpression)
    }
}
