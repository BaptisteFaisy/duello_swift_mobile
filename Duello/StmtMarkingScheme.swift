import Foundation

/// Barème retranscrit préparé pour l'affichage — port de
/// `src/utils/markingSchemeDisplay.ts`.
///
/// Les PDF de barème reprennent souvent l'intégralité du sujet avant d'insérer
/// les critères de notation. L'énoncé dispose déjà de son propre onglet : on
/// retire donc ici ses lignes recopiées, tout en gardant la structure des
/// exercices et des questions ainsi que le contenu propre au barème.
enum StmtMarkingScheme {
    /// Début de consigne de question, pour repérer une ligne recopiée du sujet.
    private static let questionPromptStart =
        "^(?:montrer|démontrer|déterminer|calculer|justifier|en déduire|établir|exprimer|donner|résoudre|étudier|vérifier|compléter|écrire|prouver|reconnaître|rappeler|soit|on (?:considère|note|pose|définit|admet|suppose)|dans (?:cette|tout|la suite)|à partir de maintenant)\\b"

    /// Barème nettoyé des lignes recopiées de l'énoncé (`markingSchemeForDisplay`).
    static func forDisplay(_ markingScheme: String, statement: String? = nil) -> String {
        let trimmedScheme = markingScheme.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedStatement = statement?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedScheme.isEmpty, let statementText = trimmedStatement, !statementText.isEmpty else {
            return trimmedScheme
        }

        let statementLines = Set(
            splitLines(statementText).map(normalizeLine).filter { !$0.isEmpty }
        )
        let normalizedStatement = normalizeText(statementText)
        let statementWords = Set(words(normalizedStatement))
        var output: [String] = []

        for rawLine in splitLines(trimmedScheme) {
            let line = normalizeLine(rawLine)
            if line.isEmpty {
                if output.last != nil, output.last != "" { output.append("") }
                continue
            }

            if let label = structuralLabel(line) {
                output.append(label)
                continue
            }

            let lineWords = words(line)
            let ratio = lineWords.isEmpty
                ? 0.0
                : Double(lineWords.filter { statementWords.contains($0) }.count) / Double(lineWords.count)
            let scoringLine = StmtRegex.contains("^[•*-]\\s+", in: line)
                || StmtRegex.contains("^\\d+(?:[.,]\\d+)?\\s*pts?\\b", in: line, options: [.caseInsensitive])
            let copied = statementLines.contains(line)
                || (line.count >= 12 && normalizedStatement.contains(line))
                || (!scoringLine
                    && StmtRegex.contains(questionPromptStart, in: line, options: [.caseInsensitive])
                    && lineWords.count >= 3
                    && ratio >= 0.85)
                || (!scoringLine && lineWords.count >= 8 && ratio >= 0.95)
            if !copied { output.append(rawLine.trimmingCharacters(in: .whitespaces)) }
        }

        let compact = StmtRegex.replaceAll(
            "\\n{3,}",
            in: output.joined(separator: "\n"),
            template: "\n\n"
        ).trimmingCharacters(in: .whitespacesAndNewlines)
        return compact.isEmpty ? trimmedScheme : compact
    }

    /// Ligne réduite à une espace unique (`normalizeLine`).
    static func normalizeLine(_ value: String) -> String {
        StmtRegex.replaceAll("\\s+", in: value.replacingOccurrences(of: "\u{00a0}", with: " "), template: " ")
            .trimmingCharacters(in: .whitespaces)
    }

    /// Ligne dont les sauts internes sont repliés (`normalizeText`).
    static func normalizeText(_ value: String) -> String {
        normalizeLine(StmtRegex.replaceAll("\\n+", in: value, template: " "))
    }

    /// Mots lettres/chiffres d'un texte, en minuscules (`words`).
    static func words(_ value: String) -> [String] {
        let lowered = value.lowercased(with: Locale(identifier: "fr-FR"))
        return StmtRegex.allMatches("[\\p{L}\\p{N}]+", in: lowered).compactMap { match in
            guard let range = Range(match.range, in: lowered) else { return nil }
            return String(lowered[range])
        }
    }

    /// Repère structurel d'une ligne (« Exercice 2 », « Partie II », « 3) », « a) »).
    static func structuralLabel(_ line: String) -> String? {
        if let groups = StmtRegex.groups(
            "^(Exercice\\s+\\d+(?:\\s*\\([^)]*\\))?)(?:[.:]?\\s+.*)?$",
            in: line,
            options: [.caseInsensitive]
        ) {
            return groups[1]
        }

        if StmtRegex.contains("^Partie\\s+(?:[IVXLCDM]+|\\d+)\\b", in: line, options: [.caseInsensitive]) {
            return line
        }

        if let groups = StmtRegex.groups(
            "^\\^?(\\d+(?:\\.[a-z])?[.)](?:\\s*[a-z][.)])?)\\s+",
            in: line,
            options: [.caseInsensitive]
        ) {
            return StmtRegex.replaceAll("\\.\\s+([a-z][.)])$", in: groups[1], options: [.caseInsensitive], template: ".$1")
        }

        if let groups = StmtRegex.groups("^([a-z][.)])\\s+", in: line, options: [.caseInsensitive]) {
            return groups[1]
        }

        return nil
    }

    /// Découpe en lignes en conservant les lignes vides (comme `split('\n')`).
    private static func splitLines(_ value: String) -> [String] {
        value.components(separatedBy: "\n")
    }
}
