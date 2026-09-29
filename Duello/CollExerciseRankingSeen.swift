//
//  CollExerciseRankingSeen.swift
//  Duello
//
//  Dernière soumission dont le classement a été ouvert, exercice par exercice,
//  et pastille « nouveau résultat » du trophée.
//
//  Fichiers source Expo portés (libellés repris mot pour mot) :
//    - src/utils/exerciseRankingSeen.ts
//        `ExerciseRankingSeenMap`, `latestExerciseSubmissionId`,
//        `hasUnseenExerciseResult`, `loadExerciseRankingSeen`,
//        `markExerciseRankingSeen`.
//    - src/components/ExerciseTrophyButton.tsx
//        `unreadDot` : point noir posé sur la coupe tant que la dernière
//        correction n'a pas été vue dans le classement.
//
//  Le repère appartient à l'exercice, pas à l'écran : quitter sans ouvrir garde
//  la notification à la prochaine visite, et une nouvelle soumission la rallume.
//  Cible : iOS 16, aucune dépendance externe.
//
import Foundation
import SwiftUI

/// Repère « classement vu » par exercice (`ExerciseRankingSeenMap`).
enum CollExerciseRankingSeen {
    /// `ACCOUNT_STORAGE_KEYS.exerciseRankingSeen`.
    static let storageKey = "prepapp-exercise-ranking-seen:v1"

    /// `latestExerciseSubmissionId` : identifiant de la dernière soumission.
    static func latestSubmissionId(_ history: [AnnMetricHistoryEntry]) -> String? {
        guard let last = history.last else { return nil }
        return last.submissionId.isEmpty ? nil : last.submissionId
    }

    /// `hasUnseenExerciseResult` : vrai quand la dernière soumission n'a pas
    /// encore été vue dans le classement.
    static func hasUnseen(history: [AnnMetricHistoryEntry], seenSubmissionId: String?) -> Bool {
        guard let latest = latestSubmissionId(history) else { return false }
        return latest != seenSubmissionId
    }

    /// `loadExerciseRankingSeen` : une carte illisible repart à vide.
    static func load() -> [String: String] {
        guard let raw = UserDefaults.standard.string(forKey: storageKey),
              let data = raw.data(using: .utf8),
              let parsed = try? JSONSerialization.jsonObject(with: data),
              let object = parsed as? [String: Any]
        else { return [:] }
        return object.reduce(into: [String: String]()) { result, pair in
            guard let value = pair.value as? String, !value.isEmpty else { return }
            result[pair.key] = value
        }
    }

    /// `markExerciseRankingSeen` : éteint le point quand le classement s'ouvre.
    static func mark(itemId: String, submissionId: String) {
        var seen = load()
        guard seen[itemId] != submissionId else { return }
        seen[itemId] = submissionId
        guard let data = try? JSONSerialization.data(withJSONObject: seen),
              let raw = String(data: data, encoding: .utf8)
        else { return }
        UserDefaults.standard.set(raw, forKey: storageKey)
    }
}

/// `unreadDot` de `ExerciseTrophyButton.tsx` : point noir du trophée, masqué aux
/// lecteurs d'écran (le libellé « nouveau résultat » porte l'information).
///
/// À raccorder (vague 5) : `ExGTrophyButton` (`ExGExerciseLeaderboard.swift`)
/// n'expose pas encore `hasUnreadResult` ; poser ce point en superposition du
/// déclencheur et appeler `CollExerciseRankingSeen.mark` à l'ouverture.
struct CollUnreadResultDot: View {
    var body: some View {
        Circle()
            .fill(Theme.ink)
            .frame(width: 9, height: 9)
            .overlay(Circle().stroke(Theme.surface, lineWidth: 1.5))
            .accessibilityHidden(true)
    }
}
