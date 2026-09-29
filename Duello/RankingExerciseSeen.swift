//
//  RankingExerciseSeen.swift
//  Duello
//
//  Repère de consultation du classement d'un exercice.
//
//  Fichier source Expo porté (libellés et seuils repris mot pour mot) :
//    - src/utils/exerciseRankingSeen.ts
//        `ExerciseRankingSeenMap`, `latestExerciseSubmissionId`,
//        `hasUnseenExerciseResult`, `loadExerciseRankingSeen`,
//        `markExerciseRankingSeen`, écrits sous la clé
//        `ACCOUNT_STORAGE_KEYS.exerciseRankingSeen`
//        (`prepapp-exercise-ranking-seen:v1`).
//
//  Une correction terminée allume un point noir sur la coupe du classement ;
//  ouvrir le classement l'éteint. Le repère appartient à l'exercice, pas à
//  l'écran : quitter sans ouvrir garde la notification à la prochaine visite,
//  et une nouvelle soumission la rallume.
//
//  L'historique est celui des essais d'un exercice
//  (`ChartMetricHistoryEntry`, `ChartExerciseMetricHistory.swift`, port de
//  `AnnaleMetricHistoryEntry` réduit).
//
//  Cible : iOS 16, aucune dépendance externe.
//
import Foundation

/// `exerciseRankingSeen.ts` : dernière soumission dont le classement a été
/// ouvert, exercice par exercice.
enum RankingExerciseSeen {

    /// `ACCOUNT_STORAGE_KEYS.exerciseRankingSeen`.
    static let storageKey = "prepapp-exercise-ranking-seen:v1"

    /// `latestExerciseSubmissionId` : dernière soumission de l'historique, `nil`
    /// quand il est vide.
    static func latestSubmissionId(_ history: [ChartMetricHistoryEntry]?) -> String? {
        history?.last?.submissionId
    }

    /// `hasUnseenExerciseResult` : vrai quand la dernière soumission n'a pas
    /// encore été vue dans le classement.
    static func hasUnseenResult(
        _ history: [ChartMetricHistoryEntry]?,
        seenSubmissionId: String?
    ) -> Bool {
        guard let latest = latestSubmissionId(history) else { return false }
        return latest != seenSubmissionId
    }

    /// `loadExerciseRankingSeen` : relit le repère ; une entrée illisible rend un
    /// repère vide, jamais une erreur. Les valeurs vides sont écartées.
    static func load() -> [String: String] {
        guard let raw = UserDefaults.standard.string(forKey: storageKey),
              let data = raw.data(using: .utf8),
              let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return [:] }
        var result: [String: String] = [:]
        for (itemId, value) in parsed {
            guard let submissionId = value as? String, !submissionId.isEmpty else { continue }
            result[itemId] = submissionId
        }
        return result
    }

    /// `markExerciseRankingSeen` : retient la soumission vue pour un exercice ;
    /// une valeur identique ne réécrit rien.
    static func mark(itemId: String, submissionId: String) {
        var seen = load()
        if seen[itemId] == submissionId { return }
        seen[itemId] = submissionId
        guard let data = try? JSONSerialization.data(withJSONObject: seen),
              let raw = String(data: data, encoding: .utf8)
        else { return }
        UserDefaults.standard.set(raw, forKey: storageKey)
    }
}
