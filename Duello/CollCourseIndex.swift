//
//  CollCourseIndex.swift
//  Duello
//
//  Index de connaissances d'un cours et encodage d'une URI de document.
//
//  Fichiers source Expo portés :
//    - src/utils/courseKnowledgeIndex.ts
//        `CourseKnowledgeIndex`, `CourseKnowledgeAnchor`, `parse`, `serialize`,
//        `courseKnowledgeIndexFromFlashcards`, `requiredCoursePositionFromKnowledge`
//        et la normalisation française des mots (`normalizedWords`, `uniqueWords`).
//    - src/utils/courseDocumentData.ts
//        `courseDocumentBase64Payload`, `courseDocumentDataUri`.
//
//  Limite documentée : la source met en cache l'index compilé et les positions
//  calculées dans des `WeakMap`. `CollKnowledgeDocument` est une valeur Swift :
//  l'index compilé est recalculé à chaque recherche, sans cache (aucune
//  mutation partagée, donc aucun risque de fuite).
//  Cible : iOS 16, aucune dépendance externe.
//
import Foundation

/// Point d'ancrage d'une notion dans le cours (`CourseKnowledgeAnchor`).
struct CollKnowledgeAnchor: Codable, Equatable, Identifiable {
    var id: String
    var label: String
    var detail: String
    /// Position de la notion dans le cours, normalisée entre 0 et 1.
    var sourcePosition: Double
}

/// Index de connaissances d'un cours (`CourseKnowledgeIndex`).
struct CollKnowledgeDocument: Codable, Equatable {
    var version: Int
    var sourceName: String
    var sourceUploadedAt: Double
    var generatedAt: Double
    var anchors: [CollKnowledgeAnchor]
}

/// `courseKnowledgeIndexFromFlashcards`, `parseCourseKnowledgeIndex`,
/// `serializeCourseKnowledgeIndex` et `requiredCoursePositionFromKnowledge`.
enum CollCourseIndex {
    /// Mots courants ignorés (`FRENCH_STOP_WORDS` de la source).
    private static let stopWords: Set<String> = [
        "afin", "ainsi", "alors", "apres", "avec", "avoir", "cette", "comme",
        "connaitre", "dans", "devoir", "elle", "elles", "entre", "etre", "exercice",
        "faire", "faut", "grace", "leurs", "mais", "necessaire", "objet", "pour",
        "porte", "question", "savoir", "selon", "sont", "tout", "toute", "utilise",
        "utiliser", "ainsi", "directement", "permet", "permettre", "repose",
    ]

    /// `courseKnowledgeIndexFromFlashcards` : les cartes positionnées deviennent
    /// des ancres, dans l'ordre du document.
    static func fromFlashcards(
        _ flashcards: CollFlashcardsDocument,
        sourceUploadedAt: Double
    ) -> CollKnowledgeDocument {
        let anchors = flashcards.cards.compactMap { card -> CollKnowledgeAnchor? in
            guard let position = card.sourcePosition else { return nil }
            return CollKnowledgeAnchor(
                id: card.id,
                label: card.question,
                detail: card.answer,
                sourcePosition: min(1, max(0, position))
            )
        }
        return CollKnowledgeDocument(
            version: 1,
            sourceName: flashcards.sourceName,
            sourceUploadedAt: sourceUploadedAt,
            generatedAt: flashcards.generatedAt,
            anchors: anchors
        )
    }

    /// `parseCourseKnowledgeIndex` : `nil` si le document est illisible ou vide.
    static func parse(_ raw: String?) -> CollKnowledgeDocument? {
        guard let raw,
              let data = raw.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data),
              let value = object as? [String: Any],
              (value["version"] as? Int) == 1,
              let sourceName = value["sourceName"] as? String,
              let sourceUploadedAt = value["sourceUploadedAt"] as? Double,
              let generatedAt = value["generatedAt"] as? Double,
              let rawAnchors = value["anchors"] as? [Any]
        else { return nil }

        let anchors = rawAnchors.compactMap { candidate -> CollKnowledgeAnchor? in
            guard let anchor = candidate as? [String: Any],
                  let id = anchor["id"] as? String,
                  let label = anchor["label"] as? String,
                  let detail = anchor["detail"] as? String,
                  let position = anchor["sourcePosition"] as? Double,
                  position.isFinite, position >= 0, position <= 1
            else { return nil }
            return CollKnowledgeAnchor(id: id, label: label, detail: detail, sourcePosition: position)
        }
        guard !anchors.isEmpty else { return nil }
        return CollKnowledgeDocument(
            version: 1,
            sourceName: sourceName,
            sourceUploadedAt: sourceUploadedAt,
            generatedAt: generatedAt,
            anchors: anchors
        )
    }

    /// `serializeCourseKnowledgeIndex` : encodage JSON, `nil` si l'encodage échoue.
    static func serialize(_ value: CollKnowledgeDocument) -> String? {
        guard let data = try? JSONEncoder().encode(value) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// `requiredCoursePositionFromKnowledge` : dernier point du cours nécessaire
    /// à un motif pédagogique, ou `nil` en cas de doute (un mot courant ne suffit
    /// jamais : il faut deux termes distinctifs, ou un terme long et rare).
    static func requiredPosition(_ index: CollKnowledgeDocument, reason: String?) -> Double? {
        guard let reason,
              !reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !index.anchors.isEmpty
        else { return nil }

        let queryWords = uniqueWords(reason)
        guard !queryWords.isEmpty else { return nil }

        let compiled = compiledIndex(index)
        var matchingPositions: [Double] = []
        for (anchorIndex, words) in compiled.anchorWords.enumerated() {
            let matches = queryWords.filter { words.contains($0) }
            let rareMatches = matches.filter {
                (compiled.frequencies[$0] ?? index.anchors.count) <= compiled.rareLimit
            }
            let mediumMatches = matches.filter {
                (compiled.frequencies[$0] ?? index.anchors.count) <= compiled.mediumLimit
            }
            let hasStrongSingleMatch = rareMatches.contains { $0.count >= 6 }
            if !hasStrongSingleMatch && mediumMatches.count < 2 { continue }
            matchingPositions.append(index.anchors[anchorIndex].sourcePosition)
        }
        return matchingPositions.max()
    }

    // MARK: - Normalisation des mots

    /// `uniqueWords` : mots distincts d'un texte.
    static func uniqueWords(_ value: String) -> Set<String> {
        Set(normalizedWords(value))
    }

    /// `normalizedWords` : minuscules sans accents, commandes LaTeX retirées,
    /// mots trop courts et mots courants écartés, pluriels ramenés au singulier.
    /// Extraction par le motif `[a-z][a-z0-9]{2,}|\bln\b` de la source.
    private static func normalizedWords(_ value: String) -> [String] {
        var text = value
            .folding(options: [.diacriticInsensitive], locale: Locale(identifier: "fr_FR"))
            .lowercased()
        text = text.replacingOccurrences(
            of: #"\\(?:begin|end)\{[^}]*\}"#,
            with: " ",
            options: .regularExpression
        )
        text = text.replacingOccurrences(
            of: #"\\[a-z]+"#,
            with: " ",
            options: .regularExpression
        )

        guard let regex = try? NSRegularExpression(pattern: #"[a-z][a-z0-9]{2,}|\bln\b"#) else {
            return []
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        let words = regex.matches(in: text, options: [], range: range).compactMap { match -> String? in
            guard let matchRange = Range(match.range, in: text) else { return nil }
            return String(text[matchRange])
        }
        return words.compactMap { word -> String? in
            let singular: String
            if word.count > 5, word.hasSuffix("es") {
                singular = String(word.dropLast(2))
            } else if word.count > 4, word.hasSuffix("s") {
                singular = String(word.dropLast(1))
            } else {
                singular = word
            }
            return stopWords.contains(singular) ? nil : singular
        }
    }

    /// `compiledCourseKnowledgeIndex` : mots par ancre, fréquence de chaque mot et
    /// seuils de rareté.
    private static func compiledIndex(_ index: CollKnowledgeDocument) -> (
        anchorWords: [Set<String>],
        frequencies: [String: Int],
        rareLimit: Int,
        mediumLimit: Int
    ) {
        let anchorWords = index.anchors.map { uniqueWords("\($0.label) \($0.detail)") }
        var frequencies: [String: Int] = [:]
        for words in anchorWords {
            for word in words { frequencies[word, default: 0] += 1 }
        }
        let count = Double(index.anchors.count)
        return (
            anchorWords,
            frequencies,
            max(2, Int(ceil(count * 0.2))),
            max(3, Int(ceil(count * 0.45)))
        )
    }
}

/// `courseDocumentBase64Payload` et `courseDocumentDataUri` : encodage d'une
/// image ou d'un PDF en URI `data:`. `nil` signale l'encodage invalide que la
/// source rejette par une exception.
enum CollDocumentData {
    private static let dataUriPrefix = "data:"

    /// `courseDocumentBase64Payload` : charge utile derrière un ou plusieurs
    /// préfixes `data:`.
    static func base64Payload(_ value: String) -> String? {
        var payload = value
        while payload.hasPrefix(dataUriPrefix) {
            guard let separator = payload.firstIndex(of: ",") else { return nil }
            payload = String(payload[payload.index(after: separator)...])
        }
        return payload
    }

    /// `courseDocumentDataUri` : URI `data:<mime>;base64,<payload>`.
    static func dataUri(_ value: String, mimeType: String) -> String? {
        guard let payload = base64Payload(value) else { return nil }
        return "data:\(mimeType);base64,\(payload)"
    }
}
