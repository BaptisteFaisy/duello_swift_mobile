import Foundation

/// Délimitation des formules d'une réponse — port de
/// `src/utils/mathAnswerLatex.ts` (`composeAnswerForDisplay`,
/// `editableMathPreview`).
enum StmtAnswerSupport {
    /// Fin du groupe ouvert à cette position, ou `nil` (`explicitGroupEnd`).
    static func explicitGroupEnd(_ answer: [Character], _ index: Int) -> Int? {
        guard index < answer.count, "^_√".contains(answer[index]),
              index + 1 < answer.count, answer[index + 1] == "(" else { return nil }
        var depth = 0
        var at = index + 1
        while at < answer.count {
            if answer[at] == "(" { depth += 1 }
            if answer[at] == ")" {
                depth -= 1
                if depth == 0 { return at + 1 }
            }
            at += 1
        }
        return nil
    }

    /// Espace que la formule absorbe (`bindsAcrossSpace`).
    static func bindsAcrossSpace(_ answer: [Character], _ index: Int) -> Bool {
        if index - 1 < 0 || index + 1 >= answer.count { return false }
        let before = answer[index - 1]
        let after = answer[index + 1]
        if before == " " || after == " " { return false }
        let beforeAlphanumeric = StmtRegex.contains("[a-zA-Z0-9]", in: String(before))
        let afterAlphanumeric = StmtRegex.contains("[a-zA-Z0-9]", in: String(after))
        if !beforeAlphanumeric || !afterAlphanumeric { return true }
        return StmtRegex.contains("[a-zA-Z]", in: String(after))
            && index + 2 < answer.count && answer[index + 2] == "("
    }

    /// Vrai si le texte porte une formule `$…$` (`containsMath`).
    static func containsMath(_ text: String?) -> Bool {
        guard let text else { return false }
        return StmtRegex.contains("\\$\\$[\\s\\S]*?\\$\\$", in: text)
            || StmtRegex.contains("(?:^|[^$])\\$(?!\\$)[\\s\\S]*?\\$(?!\\$)", in: text)
    }

    /// Vrai si le texte porte un tableau Markdown (`containsMarkdownTable`).
    static func containsMarkdownTable(_ text: String?) -> Bool {
        guard let text else { return false }
        let lines = text.components(separatedBy: "\n")
        return lines.indices.contains { index in
            index > 0
                && StmtRegex.contains("^\\s*\\|(?:\\s*:?-{3,}:?\\s*\\|)+\\s*$", in: lines[index])
                && StmtRegex.contains("^\\s*\\|.*\\|\\s*$", in: lines[index - 1])
        }
    }

    /// Vrai si le texte porte un bloc de code clôturé (`containsCodeBlock`).
    static func containsCodeBlock(_ text: String?) -> Bool {
        guard let text else { return false }
        return !fencedCodeBlocks(text).isEmpty
    }

    /// Vrai lorsqu'un texte mérite le lecteur composé (`containsRichDocument`).
    static func containsRichDocument(_ text: String?) -> Bool {
        containsMath(text) || containsCodeBlock(text) || containsMarkdownTable(text)
    }

    /// Blocs Markdown complets, avec leurs bornes (`fencedCodeBlocks`).
    static func fencedCodeBlocks(_ text: String) -> [(start: Int, end: Int, language: String, code: String)] {
        let pattern = "^```([a-zA-Z]*)[^\\S\\r\\n]*\\r?\\n([\\s\\S]*?)^```[^\\S\\r\\n]*(?:\\r?\\n|$)"
        let source = text as NSString
        return StmtRegex.allMatches(pattern, in: text, options: [.anchorsMatchLines]).map { match in
            let start = match.range.location
            let end = start + match.range.length
            let language = source.substring(with: match.range(at: 1)).lowercased()
            let code = StmtRegex.replaceAll("\\r?\\n$", in: source.substring(with: match.range(at: 2)), template: "")
            return (start, end, language, code)
        }
    }

    /// Réponse préparée pour la composition (`composeAnswerForDisplay`).
    static func composeAnswerForDisplay(_ raw: String) -> String? {
        let blocks = fencedCodeBlocks(raw)
        if blocks.isEmpty { return StmtAnswerCompose.composeMathAnswer(raw) }
        let source = raw as NSString
        var composed = ""
        var read = 0
        for block in blocks {
            let prose = source.substring(with: NSRange(location: read, length: block.start - read))
            composed += StmtAnswerCompose.composeMathAnswer(prose) ?? prose
            composed += source.substring(with: NSRange(location: block.start, length: block.end - block.start))
            read = block.end
        }
        let prose = source.substring(from: read)
        composed += StmtAnswerCompose.composeMathAnswer(prose) ?? prose
        return composed
    }

    /// Source lisible d'un champ mathématique modifiable (`editableMathPreview`).
    static func editableMathPreview(_ raw: String) -> String? {
        containsRichDocument(raw) ? raw : composeAnswerForDisplay(raw)
    }
}
