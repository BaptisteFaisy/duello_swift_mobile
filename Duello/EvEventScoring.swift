//
//  EvEventScoring.swift
//  Duello
//
//  Barème des événements : note sur 20 issue des verdicts par question, XP de
//  participation proportionnels à la durée, groupement du classement publié et
//  formatage français de la note.
//
//  Fichier source Expo porté : `src/utils/eventScoring.ts`.
//  `scoreOutOf20` est le miroir client du barème serveur
//  (`server/event-participations.mjs`) : conservé pour la parité du module.
//
//  Cible : iOS 16.
//
import Foundation

/// Groupement du classement publié (`EventLeaderboardTier`).
enum EvEventLeaderboardTier: Equatable {
    case top, second, rest
}

enum EvEventScoring {
    /// Note maximale affichée par le classement (`EVENT_SCORE_OUT_OF`).
    static let scoreOutOf: Double = 20
    /// Décimales conservées sur la note (`EVENT_SCORE_DECIMALS`).
    static let scoreDecimals = 3
    /// XP de participation pour un sujet d'une heure (`EVENT_XP_PER_HOUR`).
    static let xpPerHour = 300
    /// Les 3 premiers forment le premier groupe (`LEADERBOARD_TOP_COUNT`).
    static let leaderboardTopCount = 3
    /// Les 7 suivants forment le deuxième groupe (`LEADERBOARD_SECOND_COUNT`).
    static let leaderboardSecondCount = 7

    /// Poids des verdicts, identiques à ceux du correcteur d'exercices.
    static let verdictWeights: [EvQuestionVerdict: Double] = [
        .perfect: 1, .correct: 0.8, .partial: 0.4, .incorrect: 0,
    ]

    private static let scoreFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = scoreDecimals
        return formatter
    }()

    /// Note sur 20, avec trois décimales au plus, d'une copie corrigée par
    /// question. Un verdict manquant compte pour zéro.
    static func scoreOutOf20(questions: [EvQuestionSummary], results: [String: EvQuestionResult]) -> Double {
        let total = questions.reduce(0) { $0 + max(0, $1.points) }
        guard total > 0 else { return 0 }
        var earned = 0.0
        for (index, question) in questions.enumerated() {
            let key = question.id.isEmpty ? String(index) : question.id
            let weight = results[key].flatMap { verdictWeights[$0.verdict] } ?? 0
            earned += weight * Double(max(0, question.points))
        }
        let score = earned / Double(total) * scoreOutOf
        let factor = pow(10.0, Double(scoreDecimals))
        return (score * factor).rounded() / factor
    }

    /// XP de participation, proportionnels à la durée du sujet (300 XP par heure).
    static func participationXp(durationMinutes: Int) -> Int {
        Int((Double(max(0, durationMinutes)) / 60 * Double(xpPerHour)).rounded())
    }

    /// Groupement du classement : les 3 premiers, puis les 7 suivants, puis tous
    /// les autres. Les ex æquo restent ensemble, le groupement suit le rang.
    static func leaderboardTier(rank: Int?) -> EvEventLeaderboardTier {
        guard let rank else { return .rest }
        if rank <= leaderboardTopCount { return .top }
        if rank <= leaderboardTopCount + leaderboardSecondCount { return .second }
        return .rest
    }

    /// Formate la note : trois décimales au plus, sans zéros traînés, virgule
    /// française (« 14,5 » et « 12 » plutôt que « 14,500 »).
    static func formatScore(_ score: Double) -> String {
        scoreFormatter.string(from: NSNumber(value: score)) ?? String(score)
    }
}
