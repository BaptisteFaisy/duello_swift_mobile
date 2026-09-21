import Foundation

/// Emphase Markdown et options de liste LaTeX — port de
/// `src/utils/statementLayout.ts`.
enum StmtLatexEmphasis {
    static let listOptionLine =
        "^\\s*\\[[^\\]\\n]*(?:label\\s*=|leftmargin|series\\s*=|itemsep|topsep|parsep|resume\\b|width\\s*=)[^\\]\\n]*\\]\\s*$"
    static let pythonCodeLine =
        "^\\s*(?:>>>\\s*)?(?:#|import\\s+|from\\s+\\S+\\s+import\\s+|def\\s+\\w+\\s*\\(|class\\s+\\w+|for\\s+\\w+\\s+in\\s+|while\\s+|if\\s+|elif\\s+|else\\s*:|return\\b|break\\b|continue\\b|print\\s*\\(|[A-Za-z_]\\w*\\s*(?:=|\\+=|-=|\\*=|\\/=)|(?:np|plt|sp|rd|random|math)\\.\\w+\\s*\\()"

    static let boldCommands: Set<String> = [
        "paragraph", "subparagraph", "section", "subsection", "subsubsection", "textbf",
    ]
    static let plainCommands: Set<String> = [
        "textit", "emph", "textsl", "underline", "textsc", "texttt",
    ]
    static let emphasisCommand =
        "^\\\\(?:paragraph|subparagraph|sub(?:sub)?section|section|textbf|textit|emph|textsl|underline|textsc|texttt)\\*?\\s*\\{"

    /// Retire les lignes d'options de liste LaTeX détachées de leur environnement.
    static func stripLatexListOptionLines(_ text: String) -> String {
        if !text.contains("[") { return text }
        let kept = text.components(separatedBy: "\n").filter { line in
            !StmtRegex.contains(listOptionLine, in: line)
        }.joined(separator: "\n")
        return StmtRegex.replaceAll("\\n{3,}", in: kept, template: "\n\n")
    }

    /// Convertit `\textbf{…}` en `**…**` et les italiques en texte nu.
    static func normalizeLatexEmphasisCommands(_ text: String) -> String {
        if !text.contains("\\") { return text }
        let ns = text as NSString
        var result = ""
        var cursor = 0
        var index = 0
        var inFence = false
        var inInlineCode = false
        var inMath = false

        while index < ns.length {
            if index + 2 < ns.length,
               ns.character(at: index) == 0x60,
               ns.character(at: index + 1) == 0x60,
               ns.character(at: index + 2) == 0x60 {
                inFence.toggle()
                index += 3
                continue
            }
            let char = ns.character(at: index)
            if !inFence && char == 0x60 {
                inInlineCode.toggle()
                index += 1
                continue
            }
            if !inFence && !inInlineCode && char == 0x24 && (index == 0 || ns.character(at: index - 1) != 0x5C) {
                inMath.toggle()
                index += 1
                continue
            }
            if inFence || inInlineCode || inMath || char != 0x5C {
                index += 1
                continue
            }

            let tail = ns.substring(from: index)
            guard let groups = StmtRegex.groups(emphasisCommand, in: tail) else {
                index += 1
                continue
            }
            let openBrace = index + (groups[0] as NSString).length - 1
            guard let group = StmtLatexBlocks.balancedLatexGroup(ns, openBrace) else {
                index += 1
                continue
            }
            let command = StmtRegex.groups("^\\\\([a-z]+)", in: groups[0], options: [.caseInsensitive])?[1] ?? ""
            let isBold = boldCommands.contains(command)
            if !isBold && !plainCommands.contains(command) {
                index += 1
                continue
            }
            result += ns.substring(with: NSRange(location: cursor, length: index - cursor))
            result += isBold ? "**\(group.body.trimmingCharacters(in: .whitespaces))**" : group.body
            cursor = group.end
            index = group.end
        }

        return result + ns.substring(from: cursor)
    }

    /// Retire les marqueurs de gras orphelins d'une ligne (nombre impair).
    static func normalizeUnpairedEmphasis(_ text: String) -> String {
        if !text.contains("**") { return text }
        var inFence = false
        return text.components(separatedBy: "\n").map { line in
            if StmtRegex.contains("^```", in: line.trimmingCharacters(in: .whitespaces)) {
                inFence.toggle()
                return line
            }
            if inFence
                || StmtRegex.contains(pythonCodeLine, in: line)
                || StmtRegex.contains("^\\s{4,}\\S", in: line) {
                return line
            }
            let markers = StmtRegex.allMatches("\\*\\*", in: line).count
            return markers % 2 == 1 ? line.replacingOccurrences(of: "**", with: "") : line
        }.joined(separator: "\n")
    }

    /// Délimiteur de gras ou d'italique acceptable à cette position.
    static func emphasisDelimiterAt(_ line: [Character], _ start: Int) -> (closing: Int, bold: Bool)? {
        let bold = StmtLatexScan.startsWith(line, start, "**")
        let open = bold ? 2 : 1
        if start + open < line.count, StmtRegex.contains("\\s", in: String(line[start + open])) { return nil }
        if !bold && start > 0, StmtRegex.contains("[\\p{L}\\p{N}*$]", in: String(line[start - 1])) { return nil }
        guard let closing = StmtLatexScan.find(line, bold ? "**" : "*", from: start + open) else { return nil }
        let body = String(line[(start + open)..<closing])
        if body.isEmpty
            || StmtRegex.contains("^\\s", in: body)
            || StmtRegex.contains("\\s$", in: body) {
            return nil
        }
        if !bold && body.contains("$") { return nil }
        let after = bold ? closing + 2 : closing + 1
        if after < line.count, StmtRegex.contains("[\\p{L}\\p{N}*]", in: String(line[after])) { return nil }
        return (closing, bold)
    }

    /// Découpe une ligne en fragments de gras et d'italique, hors formule.
    static func splitEmphasisSpans(_ line: String) -> [StmtEmphasisSpan] {
        let plain: (String) -> StmtEmphasisSpan = { StmtEmphasisSpan(text: $0, bold: false, italic: false) }
        if !line.contains("*") { return [plain(line)] }
        let chars = Array(line)
        var spans: [StmtEmphasisSpan] = []
        var cursor = 0
        while cursor < chars.count {
            let doubleStart = StmtLatexScan.find(chars, "**", from: cursor)
            let singleStart = StmtLatexScan.find(chars, "*", from: cursor)
            var start = doubleStart ?? -1
            if let single = singleStart, single >= 0, start < 0 || single < start { start = single }
            if start < 0 { break }

            guard let found = emphasisDelimiterAt(chars, start) else {
                spans.append(plain(String(chars[cursor..<min(start + 1, chars.count)])))
                cursor = start + 1
                continue
            }
            let open = found.bold ? 2 : 1
            let before = String(chars[cursor..<start])
            if !before.isEmpty { spans.append(plain(before)) }
            spans.append(StmtEmphasisSpan(
                text: String(chars[(start + open)..<found.closing]),
                bold: found.bold,
                italic: !found.bold
            ))
            cursor = found.closing + open
        }
        let rest = String(chars[cursor...])
        if !rest.isEmpty || spans.isEmpty { spans.append(plain(rest)) }
        return spans
    }
}
