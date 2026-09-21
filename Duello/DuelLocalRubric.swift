import Foundation

// MARK: - Barème local de secours (port de scoreProduction, duel.ts)

/// Note une réponse sur 100 à partir de ce qu'elle contient : travail engagé,
/// justifications, structure, avancement et rigueur technique. Ce barème de
/// secours ne vérifie pas la vérité mathématique : il mesure des indices.
enum LocalRubric {
    private static let connectors = [
        "car", "donc", "puisque", "ainsi", "soit", "on a", "comme", "d'où",
        "par suite", "en effet", "because", "therefore", "however",
    ]
    private static let conclusionMarkers = [
        "donc", "conclusion", "finalement", "on conclut", "on trouve",
        "la limite", "réponse", "to conclude", "in conclusion",
    ]
    private static let technicalTokens = [
        "=", "≤", "≥", "∫", "√", "→", "%", "∈", "π", "ω", "ξ", "τ", "²", "def ",
    ]

    /// Longueur d'une copie qui a vraiment traité quelque chose.
    private static let workedLength = 200
    /// Au-delà, l'avancement est plein.
    private static let progressLength = 400

    private static func distinctMatches(_ haystack: String, _ needles: [String]) -> Int {
        needles.filter { haystack.contains($0) }.count
    }

    /// Nombre d'étapes distinctes : sauts de ligne et fins de phrase.
    private static func stepCount(_ text: String) -> Int {
        let breaks = text.components(separatedBy: "\n").count - 1
        let sentences = matches(of: "[.;:][^.;:]", in: text).count
        return breaks + sentences
    }

    private static func matches(of pattern: String, in text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, range: range).compactMap { Range($0.range, in: text).map { String(text[$0]) } }
    }

    static func scoreProduction(_ production: String) -> Int {
        let text = production.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty { return 0 }

        let lower = text.lowercased()
        let connectorCount = distinctMatches(lower, connectors)
        let steps = stepCount(text)
        let hasConclusion = conclusionMarkers.contains { lower.contains($0) }
        let technical = distinctMatches(text, technicalTokens)

        let workScore = Double(min(Double(text.count) / Double(workedLength), 1)) * 28
        let progressScore = Double(min(max(Double(text.count - workedLength), 0) / Double(progressLength), 1)) * 12
        let connectorScore = Double(min(Double(connectorCount) / 4, 1)) * 24
        let structureScore = Double(min(Double(steps) / 4, 1)) * 14
        let conclusionScore: Double = hasConclusion ? 8 : 0
        let technicalScore = Double(min(Double(technical) / 4, 1)) * 14

        return Int((workScore + progressScore + connectorScore + structureScore + conclusionScore + technicalScore).rounded())
    }

    /// Commentaire court : le point le plus saillant de la réponse.
    private static func assess(score: Int, length: Int, connectors: Int, hasConclusion: Bool) -> String {
        if length == 0 { return "Aucune réponse rendue." }
        if score >= 78 {
            return "Beaucoup de terrain couvert dans le temps imparti, avec des étapes justifiées."
        }
        if length < 80 {
            return "Copie à peine amorcée : les premières étapes du raisonnement manquent."
        }
        if connectors < 2 {
            return "Résultats présents mais peu justifiés : les étapes manquent de liens logiques."
        }
        if !hasConclusion {
            return "Raisonnement bien engagé ; noter le résultat partiel atteint aurait valorisé la copie."
        }
        return "Copie solide pour le temps imparti, encore perfectible sur la rigueur."
    }

    /// Note une copie sans réseau, sur des indices de rigueur.
    static func gradeLocally(_ production: String, _ statement: String?) -> ProductionAssessment {
        if let statement, let deterministic = DuelCopyPolicy.deterministicStatementGrade(statement, production) {
            return deterministic
        }
        let text = production.trimmingCharacters(in: .whitespacesAndNewlines)
        let score = scoreProduction(text)
        let connectorCount = distinctMatches(text.lowercased(), connectors)
        let hasConclusion = conclusionMarkers.contains { text.lowercased().contains($0) }
        return ProductionAssessment(
            score: score,
            note: assess(score: score, length: text.count, connectors: connectorCount, hasConclusion: hasConclusion)
        )
    }
}
