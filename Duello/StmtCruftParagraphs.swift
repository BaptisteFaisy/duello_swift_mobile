import Foundation

/// Paragraphes éditoriaux retirés en tête d'énoncé — port de
/// `src/utils/statementCruft.ts` (cadrage programme, annonce du but, consignes).
enum StmtCruftParagraphs {
    static let programPerimeterBlock =
        "^Cadre du programme\\.[^\\n]*\\n(?:[^\\n]+\\n)*?\\n?Énoncé(?:\\n|$)"
    static let goalAnnouncementParagraph =
        "^(?:[^$\\n]*\\b)?(?:L'exercice|Le problème|Ce problème|L'objectif de (?:cet exercice|ce problème)|Le but de (?:cet exercice|ce problème))\\s+demande.*$"
    static let consigneUsageParagraph =
        "^(?:Toutes les fonctions et tous les objets non usuels nécessaires sont définis\\b|Toutes les fonctions et tous les outils nécessaires sont définis\\b)[\\s\\S]*$"

    /// Retire le bloc de cadrage programme en tête de texte.
    static func stripProgramPerimeterBlock(_ text: String) -> String {
        guard text.hasPrefix("Cadre du programme.") else { return text }
        guard let match = StmtRegex.firstMatch(programPerimeterBlock, in: text) else { return text }
        return (text as NSString).substring(from: match.range.location + match.range.length)
    }

    /// Retire un paragraphe d'annonce du but en tête de texte.
    static func stripGoalAnnouncementParagraph(_ text: String) -> String {
        var paragraphs = text.components(separatedBy: "\n\n")
        guard let first = paragraphs.first else { return text }
        let candidate = first.trimmingCharacters(in: .whitespacesAndNewlines)
        if !StmtRegex.contains(goalAnnouncementParagraph, in: candidate) { return text }
        if !annonceAdmissible(candidate) { return text }
        paragraphs.removeFirst()
        return paragraphs.joined(separator: "\n\n")
    }

    /// Formules admises dans une annonce du but : mentions triviales seulement.
    static func annonceAdmissible(_ paragraph: String) -> Bool {
        let fragments = paragraph.components(separatedBy: "$")
        if fragments.count % 2 == 0 { return false }
        return fragments.enumerated()
            .filter { $0.offset % 2 == 1 }
            .allSatisfy { !$0.element.contains("\\") && $0.element.count <= 12 }
    }

    /// Retire le paragraphe d'usage qui suit « Consignes. » en tête de texte.
    static func stripConsigneUsageParagraph(_ text: String) -> String {
        var paragraphs = text.components(separatedBy: "\n\n")
        if paragraphs.count < 2 { return text }
        var candidate = paragraphs[0].trimmingCharacters(in: .whitespacesAndNewlines)
        if StmtRegex.contains("^consignes?\\b", in: candidate, options: [.caseInsensitive]) {
            candidate = StmtRegex.replaceAll("^consignes?[^\\n]*\\n?", in: candidate, options: [.caseInsensitive], template: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if candidate.isEmpty { return text }
        }
        if !StmtRegex.contains(consigneUsageParagraph, in: candidate, options: [.caseInsensitive]) { return text }
        if !estParagrapheDUsageConsignes(candidate) { return text }
        paragraphs.removeFirst()
        return paragraphs.joined(separator: "\n\n")
    }

    /// Garde du paragraphe d'usage : il reste court.
    static func estParagrapheDUsageConsignes(_ candidate: String) -> Bool {
        candidate.count <= 600
    }
}
