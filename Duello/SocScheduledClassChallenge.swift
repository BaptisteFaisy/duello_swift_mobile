//
//  SocScheduledClassChallenge.swift
//  Duello
//
//  Défi de classe planifié : modèle et lecture tolérante de la réponse serveur.
//
//  Fichiers source Expo portés (formes et champs repris mot pour mot) :
//    - src/utils/socialApi.ts
//      (`ScheduledClassChallenge`, `parseScheduledClassChallenge`)
//
//  Un défi de classe est planifié par un organisateur (prépa + classe + date et
//  heure locales) et rejoint par un code d'accès lisible (`classChallengeAccessCode`,
//  `DuelClassInvites`). Le serveur le renvoie sous `GET/POST
//  /scheduled-class-challenges` : le câblage réseau (création, recherche) est du
//  ressort de la couche sociale (`socialApi.ts:1635/1655`) ; ce fichier ne porte
//  que la forme et sa lecture, comme la source.
//
//  Cible : iOS 16, aucune API iOS 17.
//
import Foundation

/// Défi de classe planifié (`ScheduledClassChallenge`).
struct SocScheduledClassChallenge: Codable, Equatable, Identifiable {
    var id: String
    var prepName: String
    var className: String
    /// Date locale `AAAA-MM-JJ` (convertie en instant par `scheduledClassChallengeStartsAt`).
    var date: String
    /// Date déjà mise en forme par le serveur, affichée telle quelle.
    var displayDate: String
    /// Heure locale `HH:MM`.
    var time: String
    /// Code d'accès lisible du défi (`CL-XXXXXX`).
    var accessCode: String
    var organizerId: String
    var subject: String
    var durationMinutes: Double
    var createdAt: Double
    var updatedAt: Double
}

/// Lecture tolérante des défis de classe planifiés (`parseScheduledClassChallenge`).
enum SocScheduledClassChallenges {
    /// Forme brute : tous les champs optionnels, lus puis validés.
    private struct Raw: Decodable {
        var id: String?
        var prepName: String?
        var className: String?
        var date: String?
        var displayDate: String?
        var time: String?
        var accessCode: String?
        var organizerId: String?
        var subject: String?
        var durationMinutes: Double?
        var createdAt: Double?
        var updatedAt: Double?
    }

    /// Décode un défi depuis un objet JSON déjà analysé
    /// (`parseScheduledClassChallenge`). Renvoie `nil` si un champ manque ou n'a
    /// pas le type attendu, comme la source.
    static func parse(_ value: Any) -> SocScheduledClassChallenge? {
        guard JSONSerialization.isValidJSONObject(value),
              let data = try? JSONSerialization.data(withJSONObject: value)
        else { return nil }
        return parse(data)
    }

    /// Décode un défi depuis les octets d'une réponse serveur.
    static func parse(_ data: Data) -> SocScheduledClassChallenge? {
        guard let raw = try? JSONDecoder().decode(Raw.self, from: data),
              let id = raw.id,
              let prepName = raw.prepName,
              let className = raw.className,
              let date = raw.date,
              let displayDate = raw.displayDate,
              let time = raw.time,
              let accessCode = raw.accessCode,
              let organizerId = raw.organizerId,
              let subject = raw.subject,
              let durationMinutes = raw.durationMinutes,
              let createdAt = raw.createdAt,
              let updatedAt = raw.updatedAt
        else { return nil }
        return SocScheduledClassChallenge(
            id: id,
            prepName: prepName,
            className: className,
            date: date,
            displayDate: displayDate,
            time: time,
            accessCode: accessCode,
            organizerId: organizerId,
            subject: subject,
            durationMinutes: durationMinutes,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    /// Liste de défis : un élément illisible est écarté, comme la source
    /// (`fetchScheduledClassChallenges`).
    static func parseList(_ value: Any) -> [SocScheduledClassChallenge] {
        guard let array = value as? [Any] else { return [] }
        return array.compactMap { parse($0) }
    }
}
