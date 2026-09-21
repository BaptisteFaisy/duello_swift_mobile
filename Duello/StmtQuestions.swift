import Foundation

/// Extraction des questions d'un énoncé — port de
/// `src/utils/statementQuestions.ts` (API publique).
enum StmtQuestions {
    /// Repère « Choix A », « Choix B »… d'un même exercice.
    static let alternativeChoiceMarker = "(^|\\n)[ \\t]*(?:\\*\\*)?choix\\s+([a-c])\\b(?:\\*\\*)?"
    static let french = StmtQuestionsParser.french

    /// Identifiant stable, dérivé du libellé (`annaleQuestionId`).
    static func annaleQuestionId(_ label: String) -> String {
        label.replacingOccurrences(of: ".", with: "")
    }

    /// Questions d'un sujet dont les libellés sont déjà connus (`toAnnaleQuestions`).
    static func toAnnaleQuestions(_ labels: [String]) -> [StmtQuestion]? {
        guard labels.count >= 2 else { return nil }
        return labels.map { StmtQuestion(id: annaleQuestionId($0), label: $0) }
    }

    /// Découpe un énoncé en questions (`extractStatementQuestions`).
    static func extractStatementQuestions(_ statement: String, minimumCount: Int = 2) -> [StmtQuestion] {
        let questions = extractStatementQuestionsWithPrompts(statement)
        if questions.count < minimumCount { return [] }
        return questions
    }

    /// Texte de la ligne qui introduit chaque question (`extractStatementQuestionPrompts`).
    static func extractStatementQuestionPrompts(_ statement: String) -> [String: String] {
        let questions = extractStatementQuestionsWithPrompts(statement)
        if questions.count < 2 { return [:] }
        return Dictionary(uniqueKeysWithValues: questions.map { ($0.id, $0.prompt) })
    }

    /// Transforme les variantes « Choix A », « Choix B »… en boutons distincts.
    static func extractAlternativeChoiceQuestions(_ statement: String, _ questionNumber: String) -> [StmtQuestion]? {
        let markers = alternativeChoiceMarkers(statement)
        if markers.count < 2 { return nil }
        let groupId = "question-\(questionNumber)"
        return markers.map { marker in
            let lower = marker.id.lowercased(with: french)
            return StmtQuestion(
                id: "\(groupId)-choice-\(lower)",
                label: "\(questionNumber) - Choix \(marker.id)",
                alternativeId: marker.id,
                alternativeGroupId: groupId
            )
        }
    }

    /// Isole un choix dans un énoncé ou un corrigé qui en regroupe plusieurs.
    static func extractAlternativeChoiceText(_ text: String, _ alternativeId: String?) -> String? {
        guard let alternativeId else { return nil }
        let markers = alternativeChoiceMarkers(text)
        guard let markerIndex = markers.firstIndex(where: { $0.id == alternativeId.uppercased(with: french) }) else {
            return nil
        }
        let source = text as NSString
        let commonPreamble = source.substring(to: markers[0].start).trimmingCharacters(in: .whitespaces)
        let end = markerIndex + 1 < markers.count ? markers[markerIndex + 1].start : source.length
        let selectedChoice = source
            .substring(with: NSRange(location: markers[markerIndex].start, length: end - markers[markerIndex].start))
            .trimmingCharacters(in: .whitespaces)
        return [commonPreamble, selectedChoice].filter { !$0.isEmpty }.joined(separator: "\n\n")
    }

    /// Analyse avec cache LRU (`extractStatementQuestionsWithPrompts`).
    static func extractStatementQuestionsWithPrompts(_ statement: String) -> [StmtQuestion] {
        if let cached = StmtQuestionCache.shared.value(for: statement) { return cached }
        let questions = StmtQuestionsParser.parse(statement)
        StmtQuestionCache.shared.set(questions, for: statement)
        return questions
    }

    /// Repères « Choix X » d'un texte, dans l'ordre et sans doublon.
    static func alternativeChoiceMarkers(_ text: String) -> [(id: String, start: Int)] {
        var markers: [(id: String, start: Int)] = []
        var seen = Set<String>()
        for match in StmtRegex.allMatches(alternativeChoiceMarker, in: text, options: [.caseInsensitive]) {
            let id = (text as NSString).substring(with: match.range(at: 2)).uppercased(with: french)
            if seen.contains(id) { continue }
            seen.insert(id)
            markers.append((id, match.range.location + match.range(at: 1).length))
        }
        return markers
    }
}

/// Cache LRU borné des analyses d'énoncé (`STATEMENT_QUESTION_CACHE_LIMIT`).
final class StmtQuestionCache {
    static let shared = StmtQuestionCache()
    private let limit = 512
    private let lock = NSLock()
    private var store: [String: [StmtQuestion]] = [:]
    private var order: [String] = []

    func value(for key: String) -> [StmtQuestion]? {
        lock.lock()
        defer { lock.unlock() }
        guard let value = store[key] else { return nil }
        order.removeAll { $0 == key }
        order.append(key)
        return value
    }

    func set(_ value: [StmtQuestion], for key: String) {
        lock.lock()
        defer { lock.unlock() }
        store[key] = value
        order.removeAll { $0 == key }
        order.append(key)
        while order.count > limit, let oldest = order.first {
            order.removeFirst()
            store[oldest] = nil
        }
    }
}
