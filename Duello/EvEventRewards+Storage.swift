//
//  EvEventRewards+Storage.swift
//  Duello
//
//  Persistance des récompenses d'événement : activité (projection), cotes par
//  matière et historique Elo. Complète `EvEventRewards.swift`.
//
//  Fichier source Expo porté (clés et règles repris mot pour mot) :
//    - src/utils/activity.ts  (`ACTIVITY_STORAGE_KEYS.activity` = `prepapp-xp-activity`,
//      `loadActivity`, `saveActivity`, `dayKey`) ;
//    - src/utils/subjectElo.ts (`SUBJECT_ELO_KEY` = `prepapp-subject-elo:v1`,
//      `SUBJECT_ELO_HISTORY_KEY` = `prepapp-subject-elo-history:v1`,
//      `loadSubjectElos`, `saveSubjectElos`, `normalizeSubjectElos`,
//      `recordEloPoint`, `appendEloPoint`, `ELO_HISTORY_LIMIT` = 200).
//
//  Notes (réduit / approché / limite assumée, 24/09/2026) :
//   - `saveActivity` **fusionne** les champs de la projection dans l'objet JSON
//     déjà persisté : les autres champs du modèle d'activité complet
//     (`challengesCompleted`, `challengeXp`, `sessions`…) ne sont jamais écrasés
//     par ce module. En revanche `RewCompletion.swift` (module existant) écrit
//     la même clé avec sa propre projection : l'unification des deux modèles est
//     un câblage à faire (voir wiring/U14.md) ;
//   - l'historique Elo n'est pas réécrit « à zéro » : il est relu, complété et
//     rogné à 200 points, comme `appendEloPoint`.
//
//  Cible : iOS 16. Aucune dépendance externe.
//
import Foundation

/// Accès disque de `eventRewards.ts`.
enum EvEventRewardsStore {
    /// `ACTIVITY_STORAGE_KEYS.activity` (clé partagée avec `RewCompletion`).
    static let activityKey = "prepapp-xp-activity"
    /// `SUBJECT_ELO_KEY`.
    static let subjectEloKey = "prepapp-subject-elo:v1"
    /// `SUBJECT_ELO_HISTORY_KEY`.
    static let subjectEloHistoryKey = "prepapp-subject-elo-history:v1"
    /// `ELO_HISTORY_LIMIT` : points conservés dans l'historique Elo.
    static let eloHistoryLimit = 200

    /// `loadActivity` : projette la lecture d'activité sur les champs utiles.
    static func loadActivity(_ storage: EvEventRewardsStorage) async -> EvRewardActivity {
        guard let raw = await storage.getItem(activityKey),
              let data = raw.data(using: .utf8),
              let activity = try? JSONDecoder().decode(EvRewardActivity.self, from: data)
        else { return EvRewardActivity() }
        return activity
    }

    /// `saveActivity` : fusionne la projection dans l'activité persistée.
    static func saveActivity(_ storage: EvEventRewardsStorage, _ activity: EvRewardActivity) async {
        var object: [String: Any] = [:]
        if let raw = await storage.getItem(activityKey),
           let data = raw.data(using: .utf8),
           let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            object = parsed
        }
        object["exerciseMinutes"] = activity.exerciseMinutes
        object["subjectMinutes"] = activity.subjectMinutes
        object["activeDays"] = activity.activeDays
        object["rewardedEventIds"] = activity.rewardedEventIds
        if let encoded = try? JSONEncoder().encode(activity.history),
           let history = try? JSONSerialization.jsonObject(with: encoded) {
            object["history"] = history
        }
        guard let data = try? JSONSerialization.data(withJSONObject: object),
              let text = String(data: data, encoding: .utf8) else { return }
        await storage.setItem(activityKey, text)
    }

    /// `loadSubjectElos` : cotes par matière, filtrées et ramenées à des entiers ≥ 0.
    static func loadSubjectElos(_ storage: EvEventRewardsStorage) async -> EvSubjectEloMap {
        guard let raw = await storage.getItem(subjectEloKey),
              let data = raw.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return [:] }
        var elos: EvSubjectEloMap = [:]
        for (subject, value) in object {
            let trimmed = subject.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            if let number = value as? Double, number.isFinite {
                elos[trimmed] = max(0, Int(number.rounded()))
            } else if let number = value as? Int {
                elos[trimmed] = max(0, number)
            }
        }
        return elos
    }

    /// `saveSubjectElos` : écrit la carte des cotes par matière.
    static func saveSubjectElos(_ storage: EvEventRewardsStorage, _ elos: EvSubjectEloMap) async {
        var object: [String: Int] = [:]
        for (subject, elo) in elos {
            let trimmed = subject.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            object[trimmed] = max(0, elo)
        }
        guard let data = try? JSONSerialization.data(withJSONObject: object),
              let text = String(data: data, encoding: .utf8) else { return }
        await storage.setItem(subjectEloKey, text)
    }

    /// `recordEloPoint` : ajoute un point à l'historique, en gardant les 200 récents.
    static func recordEloPoint(_ storage: EvEventRewardsStorage, point: EvEloPoint) async {
        var history: [EvEloPoint] = []
        if let raw = await storage.getItem(subjectEloHistoryKey),
           let data = raw.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([EvEloPoint].self, from: data) {
            history = decoded
        }
        let next = Array((history + [point]).suffix(eloHistoryLimit))
        guard let data = try? JSONEncoder().encode(next),
              let text = String(data: data, encoding: .utf8) else { return }
        await storage.setItem(subjectEloHistoryKey, text)
    }

    /// `dayKey` : jour local `AAAA-MM-JJ`.
    static func dayKey(_ at: Double) -> String {
        let parts = Calendar.current.dateComponents(
            [.year, .month, .day],
            from: Date(timeIntervalSince1970: at / 1000)
        )
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    /// Entrée d'historique d'un concours blanc (« Concours blanc · <matière> »).
    static func eventEntry(input: EvEventRewardsInput, minutes: Int, xp: Int) -> EvRewardEntry {
        EvRewardEntry(
            id: "xp-event-\(input.eventId)",
            kind: "exercise",
            subject: input.subjectTitle,
            label: "Concours blanc · \(input.subjectTitle)",
            detail: "Épreuve de \(minutes) min",
            xp: Double(xp),
            at: input.at
        )
    }
}

// MARK: - Couture de stockage

/// Stockage clé/valeur de compte (`AccountStorage` réduit au nécessaire).
protocol EvEventRewardsStorage {
    /// Cloisonne la file d'écriture par compte.
    var accountId: String { get }
    func getItem(_ key: String) async -> String?
    func setItem(_ key: String, _ value: String) async
}
