//
//  EvEventSanitizers.swift
//  Duello
//
//  Assainissement des réponses de l'API événement : le serveur peut renvoyer
//  des champs absents, nuls ou d'un type inattendu ; chaque valeur est bornée
//  exactement comme dans la passerelle Expo.
//
//  Fichier source Expo porté : `src/utils/eventApi.ts` (fonctions `sanitize*`).
//
//  Cible : iOS 16.
//
import Foundation

enum EvEventSanitizers {
    /// Réponses transcrites : clés bornées à 64 caractères, valeurs à 20 000.
    static func answers(_ value: Any?) -> [String: String] {
        guard let object = value as? [String: Any] else { return [:] }
        var result: [String: String] = [:]
        for (key, answer) in object {
            guard !key.isEmpty, let text = answer as? String else { continue }
            result[String(key.prefix(64))] = String(text.prefix(20_000))
        }
        return result
    }

    /// Un verdict reconnu, sinon `nil` (`sanitizeResult`).
    static func result(_ value: Any?) -> EvQuestionResult? {
        guard let object = value as? [String: Any],
              let raw = object["verdict"] as? String,
              let verdict = EvQuestionVerdict(rawValue: raw)
        else { return nil }
        let feedback = (object["feedback"] as? String) ?? ""
        return EvQuestionResult(verdict: verdict, feedback: String(feedback.prefix(4_000)))
    }

    /// Copie d'un participant (`sanitizeParticipation`), ou `nil`.
    static func participation(_ value: Any?) -> EvParticipation? {
        guard let object = value as? [String: Any] else { return nil }
        var results: [String: EvQuestionResult] = [:]
        if let raw = object["results"] as? [String: Any] {
            for (key, entry) in raw {
                if let parsed = result(entry) { results[key] = parsed }
            }
        }
        let graded = (object["graded"] as? Bool) ?? false
        let photos = (object["photoUris"] as? [Any])?.compactMap { $0 as? String } ?? []
        return EvParticipation(
            eventId: string(object["eventId"], ""),
            displayName: string(object["displayName"], "Utilisateur Duello"),
            answers: answers(object["answers"]),
            photoUris: Array(photos.prefix(24)),
            submittedAt: number(object["submittedAt"]),
            graded: graded,
            score: number(object["score"]),
            results: graded ? results : nil,
            xpAwarded: whole(object["xpAwarded"], minimum: 0),
            eloDelta: number(object["eloDelta"])
        )
    }

    /// Lignes du classement publié (`sanitizeLeaderboard`), ou `nil`.
    static func leaderboard(_ value: Any?) -> [EvLeaderboardEntry]? {
        guard let array = value as? [Any] else { return nil }
        var entries: [EvLeaderboardEntry] = []
        for (index, element) in array.enumerated() {
            guard let object = element as? [String: Any] else { continue }
            entries.append(EvLeaderboardEntry(
                id: string(object["id"], "entry-\(index)"),
                displayName: string(object["displayName"], "Utilisateur Duello"),
                score: number(object["score"]) ?? 0,
                rank: max(1, whole(object["rank"], fallback: index + 1)),
                eloDelta: number(object["eloDelta"]) ?? 0,
                xpAwarded: whole(object["xpAwarded"], minimum: 0),
                photoUri: object["photoUri"] as? String
            ))
        }
        return entries
    }

    /// Compteurs d'interactions (`sanitizeInteractionCounts`).
    static func interactions(_ value: Any?) -> EvInteractionCounts {
        let object = (value as? [String: Any]) ?? [:]
        return EvInteractionCounts(
            viewers: whole(object["viewers"], minimum: 0),
            shares: whole(object["shares"], minimum: 0)
        )
    }

    /// Barème de questions renvoyé par le serveur (`fetchEventResults`).
    static func questions(_ value: Any?) -> [EvQuestionSummary] {
        guard let array = value as? [Any] else { return [] }
        return array.compactMap { element in
            guard let object = element as? [String: Any] else { return nil }
            return EvQuestionSummary(
                id: string(object["id"], ""),
                label: string(object["label"], "Question"),
                points: whole(object["points"], minimum: 0)
            )
        }
    }

    /// Chaîne exploitable d'une valeur JSON, remplacée par `fallback` sinon.
    private static func string(_ value: Any?, _ fallback: String) -> String {
        (value as? String) ?? fallback
    }

    /// Nombre exploitable et fini d'une valeur JSON (`true`/`false` exclus),
    /// `nil` sinon — l'équivalent de `Number.isFinite` côté Expo.
    private static func number(_ value: Any?) -> Double? {
        if value is Bool { return nil }
        if let double = value as? Double { return double.isFinite ? double : nil }
        if let integer = value as? Int { return Double(integer) }
        return nil
    }

    /// Entier borné d'une valeur JSON : arrondi vers le bas, jamais sous le
    /// minimum ; `fallback` quand la valeur n'est pas un nombre exploitable.
    private static func whole(_ value: Any?, minimum: Int = Int.min, fallback: Int = 0) -> Int {
        guard let number = number(value) else { return max(minimum, fallback) }
        return max(minimum, Int(number.rounded(.down)))
    }
}
