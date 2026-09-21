import Foundation

// MARK: - Garde-fou « énoncé recopié » (port de duelCopyPolicy.ts)

/// Garde-fou commun à l'app et au relais : une recopie de l'énoncé vaut zéro,
/// quel que soit le correcteur. Sans contenu distinct de l'énoncé, il n'y a
/// rien à noter.
enum DuelCopyPolicy {
    static let statementOnlyNote =
        "Énoncé recopié : aucun raisonnement personnel n’a été fourni."

    /// Ramène prose et formules à des jetons comparables, sans dépendre d'Intl.
    private static func canonicalTokens(_ text: String) -> [String] {
        // Décomposition de compatibilité (NFKD) d'abord : `²` doit rejoindre
        // les chiffres, comme dans la normalisation JS d'origine.
        let deaccented = text.decomposedStringWithCompatibilityMapping
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "fr_FR"))
            .replacingOccurrences(of: "≤", with: " <= ")
            .replacingOccurrences(of: "⩽", with: " <= ")
            .replacingOccurrences(of: "≥", with: " >= ")
            .replacingOccurrences(of: "⩾", with: " >= ")
            .replacingOccurrences(of: "≠", with: " != ")
        // `\p{L}` Unicode : lettres accentuées déjà neutralisées ci-dessus.
        let matches = matches(of: "[a-z0-9]+|<=|>=|!=|[=+\\-*/^<>]", in: deaccented)
        return matches
    }

    private static func matches(of pattern: String, in text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, range: range).compactMap { Range($0.range, in: text).map { String(text[$0]) } }
    }

    /// Cherche une réponse recopiée comme fragment continu de l'énoncé.
    private static func containsTokenSequence(_ statement: [String], _ answer: [String]) -> Bool {
        if answer.count > statement.count { return false }
        let statementKey = "\u{0}" + statement.joined(separator: "\u{0}") + "\u{0}"
        let answerKey = "\u{0}" + answer.joined(separator: "\u{0}") + "\u{0}"
        return statementKey.contains(answerKey)
    }

    /// Nombre de jetons de la réponse déjà disponibles dans l'énoncé.
    private static func statementTokenOverlap(_ statement: [String], _ answer: [String]) -> Int {
        var remaining: [String: Int] = [:]
        for token in statement { remaining[token, default: 0] += 1 }
        var overlap = 0
        for token in answer {
            if let count = remaining[token], count > 0 {
                overlap += 1
                remaining[token] = count - 1
            }
        }
        return overlap
    }

    /// Part des trigrammes de la réponse qui viennent tels quels de l'énoncé.
    private static func copiedTrigramRatio(_ statement: [String], _ answer: [String]) -> Double {
        if answer.count < 3 { return 0 }
        var statementTrigrams = Set<String>()
        if statement.count >= 3 {
            for index in 0...(statement.count - 3) {
                statementTrigrams.insert(statement[index..<index + 3].joined(separator: "\u{0}"))
            }
        }
        var copied = 0
        let total = answer.count - 2
        if total > 0 {
            for index in 0...total where answer.count >= index + 3 {
                if statementTrigrams.contains(answer[index..<index + 3].joined(separator: "\u{0}")) {
                    copied += 1
                }
            }
        }
        return Double(copied) / Double(total)
    }

    /// Détecte une copie qui ne fait que reprendre l'énoncé.
    static func isStatementOnlyAnswer(_ statement: String, _ answer: String) -> Bool {
        let statementTokens = canonicalTokens(statement)
        let answerTokens = canonicalTokens(answer)
        if statementTokens.isEmpty || answerTokens.isEmpty { return false }
        if statementTokens.joined(separator: " ") == answerTokens.joined(separator: " ") { return true }
        if answerTokens.count >= 2 && containsTokenSequence(statementTokens, answerTokens) { return true }
        if answerTokens.count < 5 { return false }
        let overlap = statementTokenOverlap(statementTokens, answerTokens)
        let novelTokens = answerTokens.count - overlap
        return novelTokens <= 4
            && Double(overlap) / Double(answerTokens.count) >= 0.8
            && copiedTrigramRatio(statementTokens, answerTokens) >= 0.65
    }

    /// Rend le zéro imposé par la politique, ou laisse la copie au correcteur.
    static func deterministicStatementGrade(_ statement: String, _ answer: String) -> ProductionAssessment? {
        isStatementOnlyAnswer(statement, answer)
            ? ProductionAssessment(score: 0, note: statementOnlyNote)
            : nil
    }
}
