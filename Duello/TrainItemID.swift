import Foundation

/// Identifiant d'item partagé avec `ProgressStore` : `chapitre::exercice::clé`.
enum TrainItemID {
    static func make(chapterId: String, key: String) -> String {
        "\(chapterId)::exercice::\(key)"
    }

    /// Chapitre d'un identifiant d'item ; `nil` si la forme est inattendue.
    static func chapterId(of itemId: String) -> String? {
        guard let separator = itemId.range(of: "::") else { return nil }
        let chapter = String(itemId[itemId.startIndex..<separator.lowerBound])
        return chapter.isEmpty ? nil : chapter
    }
}
