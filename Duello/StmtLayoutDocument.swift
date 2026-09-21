import Foundation

/// Texte de fiche d'exercice pour l'affichage — port de
/// `src/utils/statementLayout.ts`.
enum StmtLayoutDocument {
    static let markdownHeading = "^#{1,6}\\s+"
    static let redundantExerciseOpening =
        "^(?:exercice|exo\\.?)\\s*(?:n[°ºo]\\s*)?(?:\\d+(?:[.\\-]\\d+)*|[IVX]+)\\s*[.:]?\\s*(.*)$"
    static let danglingSectionHeading =
        "(?:[.!?;:]|\\$\\$|\\\\\\])\\s+([\\p{Lu}][\\p{L}\\p{M}\\d'’ -]{2,59})$"
    static let instructionOpening =
        "^(?:calculer|comparer|compléter|conclure|décrire|démontrer|déterminer|donner|effectuer|en déduire|établir|étudier|exprimer|justifier|montrer|prouver|proposer|rappeler|répondre|représenter|résoudre|simplifier|tracer|trouver|vérifier|écrire)\\b"
    static let statementOrConclusionWord =
        "\\b(?:a|admet|admettent|ainsi|appartient|appartiennent|avec|car|c[’']est|converge|convergent|dans|diverge|divergent|doit|doivent|donc|elle|elles|est|étaient|était|existe|existent|il|ils|implique|la|le|les|montre|montrent|n[’']est|on|ont|peut|peuvent|pour|que|qui|reste|restent|sans|seraient|serait|si|soit|soient|sont|suit|suivent|vaut|valent|vérifie|vérifient)\\b"

    /// Retire le titre de la rubrique suivante collé à la fin d'un champ isolé.
    static func withoutDanglingSectionHeading(_ text: String) -> String {
        let normalized = StmtRegex.replaceAll("\\r\\n?", in: text, template: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let match = StmtRegex.firstMatch(danglingSectionHeading, in: normalized) else { return normalized }
        let source = normalized as NSString
        let candidate = source.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespaces)
        let wordCount = candidate.split(separator: " ").filter { !$0.isEmpty }.count
        if wordCount > 8
            || StmtRegex.contains(instructionOpening, in: candidate, options: [.caseInsensitive])
            || StmtRegex.contains(statementOrConclusionWord, in: candidate, options: [.caseInsensitive]) {
            return normalized
        }
        let whole = source.substring(with: match.range)
        let delimiter = StmtRegex.groups("^(?:\\$\\$|\\\\\\]|[.!?;:])", in: whole)?[0] ?? ""
        let cut = match.range.location + delimiter.count
        return source.substring(to: cut).trimmingCharacters(in: .whitespaces)
    }

    /// Texte d'une fiche d'exercice isolée, débarrassé des repères de source.
    static func exerciseDocumentForDisplay(_ text: String) -> String {
        let restored = StmtLatexPython.mathDocumentForDisplay(text)
        var lines = StmtRegex.replaceAll("\\r\\n?", in: restored, template: "\n").components(separatedBy: "\n")
        guard let openingIndex = lines.firstIndex(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) else {
            return ""
        }
        let opening = StmtRegex.replaceAll(
            markdownHeading,
            in: lines[openingIndex].trimmingCharacters(in: .whitespaces),
            template: ""
        )
        if let groups = StmtRegex.groups(redundantExerciseOpening, in: opening, options: [.caseInsensitive]) {
            let remainder = StmtRegex.replaceAll("^[—–-]\\s*", in: groups[1].trimmingCharacters(in: .whitespaces), template: "")
            if remainder.isEmpty { lines.remove(at: openingIndex) } else { lines[openingIndex] = remainder }
        }
        var displayed = withoutDanglingSectionHeading(
            lines.map { StmtRegex.replaceAll(markdownHeading, in: $0, template: "") }
                .joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        )
        for _ in 0..<3 {
            let next = withoutDanglingSectionHeading(StmtLatexPython.mathDocumentForDisplay(displayed))
            if next == displayed { return displayed }
            displayed = next
        }
        return displayed
    }
}
