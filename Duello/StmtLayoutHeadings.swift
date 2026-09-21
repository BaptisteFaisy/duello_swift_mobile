import Foundation

/// Titres, repères et découpage de ligne — port de `src/utils/statementLayout.ts`.
enum StmtLayoutHeadings {
    static let heading = "^(exercice|probl[èe]me|partie|annexe|pr[ée]liminaires?)\\b|^[IVX]{1,5}\\s*[.)-]"
    static let partieHeading =
        "^\\*{0,2}partie\\s+(?:[ivxlcdm]{1,7}|[a-z]|\\d{1,2})\\*{0,2}(?:\\s*[—–-].*|\\s*[.:;!)»].*)?$"
    static let partieHeadingMaxLength = 90
    static let questionMarker = "^(\\d{1,2}\\s*[.)]|\\(?[a-h]\\s*[.)])"
    static let questionHeadingMarker = "^Question\\s+(\\d{1,2}\\s*\\.|terminale|de\\s+rupture)"
    static let number = "^\\d{1,2}\\s*[.)](?=\\s|$)"
    static let letter = "^\\(?[a-h]\\s*[.)](?=\\s|$)"
    static let bullet = "^(?:[•▪◦]|[–—-](?=\\s))"

    /// Sépare un titre de partie de son enveloppe de gras Markdown.
    static func splitPartieHeading(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty || trimmed.count > partieHeadingMaxLength { return nil }
        if let groups = StmtRegex.groups("^\\*\\*(.+)\\*\\*$", in: trimmed) {
            let inner = groups[1].trimmingCharacters(in: .whitespaces)
            return StmtRegex.contains(partieHeading, in: inner, options: [.caseInsensitive]) ? inner : nil
        }
        if StmtRegex.contains("^\\*\\*partie\\s+\\S+\\s*\\*\\*", in: trimmed, options: [.caseInsensitive]) {
            let without = trimmed.replacingOccurrences(of: "**", with: "")
            return StmtRegex.contains(partieHeading, in: without, options: [.caseInsensitive]) ? without : nil
        }
        return StmtRegex.contains(partieHeading, in: trimmed, options: [.caseInsensitive]) ? trimmed : nil
    }

    /// Vrai lorsque la ligne nomme un exercice, une partie ou un problème.
    static func isStatementHeading(_ text: String) -> Bool {
        var trimmed = StmtRegex.replaceAll("^\\*\\*", in: text.trimmingCharacters(in: .whitespaces), template: "")
        trimmed = StmtRegex.replaceAll("\\*\\*$", in: trimmed, template: "").trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return false }
        if trimmed.count <= partieHeadingMaxLength, StmtRegex.contains(partieHeading, in: trimmed, options: [.caseInsensitive]) {
            return true
        }
        return trimmed.count <= 60 && StmtRegex.contains(heading, in: trimmed, options: [.caseInsensitive])
    }

    /// Sépare le numéro d'ouverture du reste de la ligne.
    static func splitQuestionMarker(_ text: String) -> (marker: String, rest: String) {
        if let groups = StmtRegex.groups(questionMarker, in: text, options: [.caseInsensitive]) {
            return (groups[1], String(text.dropFirst(groups[1].count)))
        }
        if let heading = StmtRegex.groups(questionHeadingMarker, in: text, options: [.caseInsensitive]) {
            let numbered = StmtRegex.contains("^Question\\s+\\d", in: heading[0], options: [.caseInsensitive])
            let marker = numbered
                ? StmtRegex.replaceAll("^Question\\s+", in: heading[0], options: [.caseInsensitive], template: "")
                : heading[0]
            return (marker, String(text.dropFirst(heading[0].count)))
        }
        return ("", text)
    }

    /// Vrai si la ligne ouvre une question (numéro, lettre ou puce).
    static func isQuestionOpening(_ line: String) -> Bool {
        let text = line.trimmingCharacters(in: .whitespaces)
        return StmtRegex.contains(number, in: text)
            || StmtRegex.contains(letter, in: text, options: [.caseInsensitive])
            || StmtRegex.contains(bullet, in: text)
    }
}
