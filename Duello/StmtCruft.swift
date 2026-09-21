import Foundation

/// Nettoyage d'énoncé et de corrigé — port de `src/utils/statementCruft.ts`.
///
/// Retire les mentions éditoriales (durée, difficulté, niveau, consignes,
/// barème, matériel, titres rédactionnels, marqueurs « Énoncé » / « Corrigé »,
/// références de pages). Idempotent, sûr sur le LaTeX délimité par `$`.
enum StmtCruft {
    /// Texte débarrassé des mentions qui ne sont pas du contenu.
    static func stripStatementCruft(_ text: String) -> String {
        if text.isEmpty { return text }
        var prepared = StmtCruftParagraphs.stripProgramPerimeterBlock(text)
        prepared = StmtCruftParagraphs.stripGoalAnnouncementParagraph(prepared)
        prepared = StmtCruftParagraphs.stripConsigneUsageParagraph(prepared)
        let lines = StmtRegex.replaceAll("\\r\\n?", in: prepared, template: "\n")
            .components(separatedBy: "\n")
        var kept: [String] = []
        var insideFence = false

        let neighbors = nonEmptyNeighbors(lines)
        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if StmtRegex.contains("^```", in: trimmed) {
                insideFence.toggle()
                kept.append(line)
                continue
            }
            if insideFence {
                kept.append(line)
                continue
            }
            if StmtCruftSession.isCruftLine(trimmed) { continue }
            if StmtRegex.contains(StmtCruftPages.barePageNumberLine, in: trimmed) {
                let pair = neighbors[index]
                let neighborIsMarker =
                    (!pair.next.isEmpty && (StmtCruftPages.isPageMarkerLine(pair.next) || StmtCruftPages.isTournezPageLine(pair.next)))
                    || (!pair.previous.isEmpty && (StmtCruftPages.isPageMarkerLine(pair.previous) || StmtCruftPages.isTournezPageLine(pair.previous)))
                if neighborIsMarker { continue }
            }
            kept.append(StmtCruftSession.markHeaderInstruction(trimmed))
        }

        var result = StmtCruftPages.removeWordPageRefs(kept.joined(separator: "\n"))
        result = StmtCruftPages.cleanMathTextPageRefs(result)
        result = StmtRegex.replaceAll("\\n{3,}", in: result, template: "\n\n")
        result = StmtRegex.replaceAll("^(?:[ \\t]*\\n)+", in: result, template: "")
        result = StmtRegex.replaceAll("(?:\\n[ \\t]*)+$", in: result, template: "")
        return result
    }

    /// Retire les marqueurs d'italique posés sur les consignes d'en-tête.
    static func stripStatementItalicMarkers(_ text: String) -> String {
        if !text.contains("*") { return text }
        return text.components(separatedBy: "\n").map { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard StmtRegex.contains("^\\*([^*$]+)\\*$", in: trimmed) else { return line }
            return String(trimmed.dropFirst().dropLast())
        }.joined(separator: "\n")
    }

    /// Déballe les paires d'astérisques doubles du gras Markdown, hors formule et code.
    static func stripStatementBoldMarkers(_ text: String) -> String {
        if !text.contains("**") { return text }
        return text.components(separatedBy: "\n").map { line in
            if !line.contains("**") { return line }
            if line.contains("$") {
                var fragments = line.components(separatedBy: "$")
                if fragments.count % 2 == 0 { return line }
                var index = 0
                while index < fragments.count {
                    fragments[index] = fragments[index].replacingOccurrences(of: "**", with: "")
                    index += 2
                }
                return fragments.joined(separator: "$")
            }
            return line.replacingOccurrences(of: "**", with: "")
        }.joined(separator: "\n")
    }

    /// Premier voisin non vide de chaque ligne (au plus trois lignes d'écart).
    private static func nonEmptyNeighbors(_ lines: [String]) -> [(next: String, previous: String)] {
        lines.enumerated().map { index, _ in
            var next = ""
            var forward = index + 1
            while forward < min(index + 4, lines.count) {
                if !lines[forward].trimmingCharacters(in: .whitespaces).isEmpty {
                    next = lines[forward].trimmingCharacters(in: .whitespaces)
                    break
                }
                forward += 1
            }
            var previous = ""
            var backward = index - 1
            while backward >= max(0, index - 3) {
                if !lines[backward].trimmingCharacters(in: .whitespaces).isEmpty {
                    previous = lines[backward].trimmingCharacters(in: .whitespaces)
                    break
                }
                backward -= 1
            }
            return (next, previous)
        }
    }
}
