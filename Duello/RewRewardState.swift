//
//  RewRewardState.swift
//  Duello
//
//  État des bonus de fin d'exercice : jours de pratique et reçus.
//
//  Fichier source Expo porté (commentaires repris mot pour mot) :
//    - src/utils/exerciseRewardState.ts
//        `ExerciseRewardState`, `normalizePracticeDays`, `isReceipt`,
//        `normalizeExerciseRewardState`, `exerciseBonusTotal`.
//
//  Le barème `EXERCISE_BONUS_RULES` est déjà porté par `ExGBonusRules` et le
//  reçu par `ExGBonusReceipt` (`ExGXpFoundation.swift`) : ce module les
//  réutilise sans les redéfinir. `RewRewardState` porte l'état persisté et sa
//  normalisation, et devient `Codable` pour la réécriture de l'activité
//  (`RewCompletion`) — le reçu réutilisé reste `Equatable` seul, d'où un
//  miroir `Codable` privé.
//
//  Cible : iOS 16, aucune dépendance externe.
//
import Foundation

/// État des bonus d'exercice (`ExerciseRewardState`).
struct RewRewardState: Equatable {
    /// Jours de pratique (AAAA-MM-JJ), dédupliqués et triés.
    var practiceDays: [String] = []
    /// Reçus de bonus, un par soumission primée.
    var receipts: [ExGBonusReceipt] = []

    /// `normalizePracticeDays` : jours valides, dédupliqués, triés.
    static func normalizePracticeDays(_ value: [String]) -> [String] {
        let valid = value.filter { day in
            day.range(of: #"^\d{4}-\d{2}-\d{2}$"#, options: .regularExpression) != nil
        }
        return Array(Set(valid)).sorted()
    }

    /// `isReceipt` : un reçu n'est retenu que complet et plausible.
    static func isReceipt(_ receipt: ExGBonusReceipt) -> Bool {
        guard !receipt.submissionId.isEmpty,
              normalizePracticeDays([receipt.day]).count == 1
        else { return false }
        let numbers = [receipt.firstOfDay, receipt.firstChapterDifficulty,
                       Double(receipt.practiceDays), receipt.practice, receipt.gained,
                       receipt.totalBefore, receipt.totalAfter]
        return numbers.allSatisfy { $0.isFinite && $0 >= 0 }
    }

    /// `normalizeExerciseRewardState` : les anciens comptes restent à zéro
    /// bonus, aucune revalorisation rétroactive. Un reçu est unique par
    /// soumission (le dernier gagne, à la position de la première occurrence).
    static func normalize(_ value: RewRewardState?) -> RewRewardState {
        var seen = Set<String>()
        var unique: [ExGBonusReceipt] = []
        for receipt in (value?.receipts ?? []).filter(isReceipt).reversed() {
            if seen.insert(receipt.submissionId).inserted { unique.append(receipt) }
        }
        return RewRewardState(
            practiceDays: normalizePracticeDays(value?.practiceDays ?? []),
            receipts: Array(unique.reversed())
        )
    }

    /// `exerciseBonusTotal` : somme des gains des reçus, zéro sans état.
    static func bonusTotal(_ state: RewRewardState?) -> Double {
        (state?.receipts ?? []).reduce(0) { $0 + $1.gained }
    }
}

// MARK: - Sérialisation

extension RewRewardState: Codable {
    /// Reçu sérialisé (`ExerciseBonusReceipt`), mêmes clés que la source.
    private struct Receipt: Codable {
        var submissionId: String
        var chapterDifficultyKey: String
        var day: String
        var firstOfDay: Double
        var firstChapterDifficulty: Double
        var practiceDays: Int
        var practice: Double
        var gained: Double
        var totalBefore: Double
        var totalAfter: Double

        init(_ receipt: ExGBonusReceipt) {
            submissionId = receipt.submissionId
            chapterDifficultyKey = receipt.chapterDifficultyKey
            day = receipt.day
            firstOfDay = receipt.firstOfDay
            firstChapterDifficulty = receipt.firstChapterDifficulty
            practiceDays = receipt.practiceDays
            practice = receipt.practice
            gained = receipt.gained
            totalBefore = receipt.totalBefore
            totalAfter = receipt.totalAfter
        }

        var receipt: ExGBonusReceipt {
            ExGBonusReceipt(
                submissionId: submissionId,
                chapterDifficultyKey: chapterDifficultyKey,
                day: day,
                firstOfDay: firstOfDay,
                firstChapterDifficulty: firstChapterDifficulty,
                practiceDays: practiceDays,
                practice: practice,
                gained: gained,
                totalBefore: totalBefore,
                totalAfter: totalAfter
            )
        }
    }

    enum CodingKeys: String, CodingKey { case practiceDays, receipts }

    /// Décodage tolérant : un état partiel est complété, jamais rejeté.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        practiceDays = RewRewardState.normalizePracticeDays(
            (try? container.decode([String].self, forKey: .practiceDays)) ?? []
        )
        let raw = (try? container.decode([Receipt].self, forKey: .receipts)) ?? []
        receipts = raw.map { $0.receipt }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(practiceDays, forKey: .practiceDays)
        try container.encode(receipts.map(Receipt.init), forKey: .receipts)
    }
}
