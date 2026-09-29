//
//  DuelClassInvites.swift
//  Duello
//
//  Inviter quelqu'un à un défi : la salle d'attente, le code d'accès de classe
//  et les messages de partage. Port de `src/utils/challengeInvites.ts` (RN),
//  fonctions `scheduledClassChallengeStartsAt`, `classChallengeWaitingRoomIsOpen`,
//  `classChallengeAccessCode`, `classChallengeCodeMatches`,
//  `normalizeClassChallengeCode`, `scheduledClassInviteMessage(s)` et la
//  constante `CLASS_CHALLENGE_WAITING_ROOM_MS` (lignes 19-142).
//
//  Choix de type : la source renvoie un instant en millisecondes epoch
//  (`number | null`) ; côté Swift on renvoie un `Date?` — la comparaison en ms
//  de la salle d'attente se fait via `timeIntervalSince1970 * 1000`, ce qui
//  reste équivalent à la source.
//
//  Cible : iOS 16.
//
import Foundation

/// Invitation à un défi de classe (salle d'attente, code d'accès, messages).
enum DuelClassInvites {
    /// Le jour et l'heure enregistrés pour un défi de classe
    /// (`{ date: string; time: string }` de la source).
    struct ScheduledClassChallenge {
        var date: String
        var time: String
    }

    /// La salle d'attente d'un défi de classe ouvre cinq minutes avant son
    /// départ (`CLASS_CHALLENGE_WAITING_ROOM_MS`).
    static let CLASS_CHALLENGE_WAITING_ROOM_MS = 5 * 60_000

    /// Convertit le jour et l'heure enregistrés en instant local sur le
    /// téléphone (`scheduledClassChallengeStartsAt`). `nil` si la date ou
    /// l'heure est mal formée, ou si un composant reconstruit ne correspond pas
    /// (ex. 30 février).
    static func scheduledClassChallengeStartsAt(_ challenge: ScheduledClassChallenge) -> Date? {
        guard let dateMatch = captures(#"^(\d{4})-(\d{2})-(\d{2})$"#, in: challenge.date),
              let timeMatch = captures(#"^(\d{2}):(\d{2})$"#, in: challenge.time),
              dateMatch.count == 3, timeMatch.count == 2,
              let year = Int(dateMatch[0]), let month = Int(dateMatch[1]),
              let day = Int(dateMatch[2]),
              let hours = Int(timeMatch[0]), let minutes = Int(timeMatch[1]),
              // `new Date(0…99, …)` de JS décale l'année de 1900, ce que la
              // validation de la source rejette : même refus ici.
              year >= 100 else {
            return nil
        }
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hours
        components.minute = minutes
        let calendar = Calendar.current
        guard let value = calendar.date(from: components) else { return nil }
        let check = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: value)
        guard check.year == year, check.month == month, check.day == day,
              check.hour == hours, check.minute == minutes else {
            return nil
        }
        return value
    }

    /// La salle d'attente est ouverte de `startsAt - 5 min` à `startsAt`
    /// inclus (`classChallengeWaitingRoomIsOpen`, `now` en ms epoch).
    static func classChallengeWaitingRoomIsOpen(
        _ challenge: ScheduledClassChallenge,
        now: Double = Date().timeIntervalSince1970 * 1000
    ) -> Bool {
        guard let startsAt = scheduledClassChallengeStartsAt(challenge) else { return false }
        let startsAtMs = startsAt.timeIntervalSince1970 * 1000
        return now >= startsAtMs - Double(CLASS_CHALLENGE_WAITING_ROOM_MS) && now <= startsAtMs
    }

    /// Texte d'invitation à un défi de classe, lien stable dans le corps
    /// (`scheduledClassInviteMessage`).
    static func scheduledClassInviteMessage(
        prepName: String,
        className: String,
        date: String,
        time: String,
        accessCode: String,
        stableDownloadUrl: String
    ) -> String {
        [
            "Défi Duello · \(prepName) · \(className)",
            "Rendez-vous le \(date) à \(time) pour un défi.",
            "Ouvre Duello pour participer. Le code d’accès est envoyé dans le message suivant.",
            "Télécharge Duello ici : \(stableDownloadUrl)",
        ].joined(separator: "\n")
    }

    /// Les deux messages envoyés l'un après l'autre par les boutons de partage
    /// (`scheduledClassInviteMessages`) : le texte d'invitation, puis le code.
    static func scheduledClassInviteMessages(
        prepName: String,
        className: String,
        date: String,
        time: String,
        accessCode: String,
        stableDownloadUrl: String
    ) -> [String] {
        [
            scheduledClassInviteMessage(
                prepName: prepName,
                className: className,
                date: date,
                time: time,
                accessCode: accessCode,
                stableDownloadUrl: stableDownloadUrl
            ),
            accessCode,
        ]
    }

    /// Code lisible à transmettre dans un groupe, sans exposer d'identifiant de
    /// compte (`classChallengeAccessCode`). Hash FNV-1a 32 bits sur les unités
    /// UTF-16, rendu en base 36 sur les 6 derniers caractères.
    static func classChallengeAccessCode(prepName: String, className: String) -> String {
        let source = [prepName, className]
            .map { value in
                value.trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
                    .uppercased()
            }
            .joined(separator: "|")
        var hash: UInt32 = 0x811c9dc5
        for unit in source.utf16 {
            hash ^= UInt32(unit)
            hash = hash &* 0x01000193
        }
        var text = String(hash, radix: 36, uppercase: true)
        while text.count < 6 { text = "0" + text }
        return "CL-" + String(text.suffix(6))
    }

    /// Le code saisi correspond-il à celui de la classe (`classChallengeCodeMatches`).
    static func classChallengeCodeMatches(prepName: String, className: String, code: String) -> Bool {
        normalizeClassChallengeCode(code) == classChallengeAccessCode(prepName: prepName, className: className)
    }

    /// Met un code au format canonique pour comparaison
    /// (`normalizeClassChallengeCode`) : trim, majuscules, sans aucun espace.
    static func normalizeClassChallengeCode(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
            .replacingOccurrences(of: #"\s+"#, with: "", options: .regularExpression)
    }

    /// Groupes capturés (1..n) d'une correspondance ancrée, ou `nil` si aucune.
    private static func captures(_ pattern: String, in text: String) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: range) else { return nil }
        return (1..<match.numberOfRanges).map { index in
            guard let captured = Range(match.range(at: index), in: text) else { return "" }
            return String(text[captured])
        }
    }
}
