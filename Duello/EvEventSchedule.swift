//
//  EvEventSchedule.swift
//  Duello
//
//  Horloge des phases d'un événement : début, durée réelle, ouverture de la
//  salle d'attente, fin réelle de la participation et découpage du décompte.
//  Les phases vivent du seul horaire affiché : aucun état local ne décide.
//
//  Fichier source Expo porté : `src/utils/eventSchedule.ts`.
//  `formatEventCountdown` et `formatEventClock` — exportés par le module mais
//  consommés uniquement par ses tests, par aucun composant de l'espace
//  événement — ne sont pas portés ici.
//
//  Cible : iOS 16.
//
import Foundation

enum EvEventSchedule {
    /// Durée par défaut d'un sujet : une heure (`EVENT_DURATION_MS`).
    static let defaultDuration: TimeInterval = 60 * 60
    /// Ouverture de la salle d'attente : dix minutes avant le début.
    static let waitingRoomLead: TimeInterval = 10 * 60
    /// Fin réelle : la fin affichée moins une seconde.
    static let joinDeadlineLag: TimeInterval = 1

    /// Instant de début, dans le fuseau local, ou `nil` si l'horaire est illisible.
    static func startDate(_ event: EvEvent) -> Date? {
        let day = event.date.split(separator: "-").compactMap { Int($0) }
        guard day.count == 3, day[0] > 0, day[1] > 0, day[2] > 0 else { return nil }
        let time = (event.startTime ?? "00:00").split(separator: ":").compactMap { Int($0) }
        guard time.count == 2 else { return nil }
        return date(year: day[0], month: day[1], day: day[2], hour: time[0], minute: time[1])
    }

    /// Durée réelle de l'épreuve : l'écart affiché entre le début et la fin,
    /// jamais moins d'une heure.
    static func duration(_ event: EvEvent) -> TimeInterval {
        guard let start = startDate(event), let endTime = event.endTime else { return defaultDuration }
        let day = event.date.split(separator: "-").compactMap { Int($0) }
        let time = endTime.split(separator: ":").compactMap { Int($0) }
        guard day.count == 3, time.count == 2,
              let end = date(year: day[0], month: day[1], day: day[2], hour: time[0], minute: time[1])
        else { return defaultDuration }
        return max(defaultDuration, end.timeIntervalSince(start))
    }

    /// Fin réelle de la participation, ou `nil` si l'horaire est illisible.
    static func joinDeadline(_ event: EvEvent) -> Date? {
        guard let start = startDate(event) else { return nil }
        return start.addingTimeInterval(duration(event) - joinDeadlineLag)
    }

    /// Phase courante, déduite du seul horaire affiché.
    static func phase(_ event: EvEvent, now: Date) -> EvEventPhase {
        guard let start = startDate(event), let deadline = joinDeadline(event) else { return .finished }
        if now >= deadline { return .finished }
        if now >= start { return .live }
        if now >= start.addingTimeInterval(-waitingRoomLead) { return .waiting }
        return .upcoming
    }

    /// Segments du décompte, du plus grand au plus petit ; les jours nuls sont
    /// omis pour qu'une épreuve à quelques heures n'affiche pas un « 0 j ».
    static func countdownSegments(targetAt: Date, now: Date) -> [EvCountdownSegment] {
        let total = Int(floor(max(0, targetAt.timeIntervalSince(now))))
        let days = total / 86_400
        let hours = (total % 86_400) / 3_600
        let minutes = (total % 3_600) / 60
        let seconds = total % 60
        let segments = [
            EvCountdownSegment(value: days, unit: "j"),
            EvCountdownSegment(value: hours, unit: "h"),
            EvCountdownSegment(value: minutes, unit: "min"),
            EvCountdownSegment(value: seconds, unit: "s"),
        ]
        return days > 0 ? segments : Array(segments.dropFirst())
    }

    /// Compose une date locale à partir de ses composants.
    private static func date(year: Int, month: Int, day: Int, hour: Int, minute: Int) -> Date? {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.second = 0
        return Calendar.current.date(from: components)
    }
}
