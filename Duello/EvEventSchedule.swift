//
//  EvEventSchedule.swift
//  Duello
//
//  Horloge des phases d'un événement : début, durée réelle, ouverture de la
//  salle d'attente, fin réelle de la participation, découpage du décompte,
//  pastille de statut (`eventStatusBadge`) et ouverture du chat
//  (`isEventChatOpen`). Les phases vivent du seul horaire affiché : aucun état
//  local ne décide.
//
//  Fichier source Expo porté : `src/utils/eventSchedule.ts`.
//  `formatEventCountdown` et `formatEventClock` — exportés par le module mais
//  consommés uniquement par ses tests, par aucun composant de l'espace
//  événement — ne sont pas portés ici.
//
//  Écarts assumés (29/09/2026) : aucun.
//
//  Cible : iOS 16.
//
import Foundation

enum EvEventSchedule {
    /// Durée par défaut d'un sujet : une heure (`EVENT_DURATION_MS`), pour un
    /// événement sans horaire de fin valable.
    static let defaultDuration: TimeInterval = 60 * 60
    /// Durée minimale d'un sujet : une minute, plancher du minuteur
    /// (`EVENT_MIN_DURATION_MS`). Les épreuves courtes (défis de 5 min,
    /// événements de 10 min) vivent leur vraie durée.
    static let minDuration: TimeInterval = 60
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
    /// jamais moins d'une minute (`EVENT_MIN_DURATION_MS`) ; une heure
    /// (`EVENT_DURATION_MS`) seulement sans horaire de fin valable.
    static func duration(_ event: EvEvent) -> TimeInterval {
        guard let start = startDate(event), let endTime = event.endTime else { return defaultDuration }
        let day = event.date.split(separator: "-").compactMap { Int($0) }
        let time = endTime.split(separator: ":").compactMap { Int($0) }
        guard day.count == 3, time.count == 2,
              let end = date(year: day[0], month: day[1], day: day[2], hour: time[0], minute: time[1])
        else { return defaultDuration }
        return max(minDuration, end.timeIntervalSince(start))
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
    /// omis pour qu'une épreuve à quelques heures n'affiche pas un « 0 jours ».
    static func countdownSegments(targetAt: Date, now: Date) -> [EvCountdownSegment] {
        let total = Int(floor(max(0, targetAt.timeIntervalSince(now))))
        let days = total / 86_400
        let hours = (total % 86_400) / 3_600
        let minutes = (total % 3_600) / 60
        let seconds = total % 60
        let segments = [
            EvCountdownSegment(value: days, unit: "jours"),
            EvCountdownSegment(value: hours, unit: "heures"),
            EvCountdownSegment(value: minutes, unit: "minutes"),
            EvCountdownSegment(value: seconds, unit: "secondes"),
        ]
        return days > 0 ? segments : Array(segments.dropFirst())
    }

    /// Le chat d'un événement est ouvert dès que la page est accessible, puis
    /// fermé pendant l'épreuve, et rouvert dès la fin : seule la phase « live »
    /// le verrouille (`isEventChatOpen`).
    static func isChatOpen(_ event: EvEvent, now: Date) -> Bool {
        phase(event, now: now) != .live
    }

    /// Pastille de statut d'un événement, en majuscule sur les cartes :
    /// « EN COURS » pendant l'épreuve, « TERMINÉ » une fois fini. Avant le
    /// début, aucune pastille. Sur les cartes, `results` est inconnu
    /// (`undefined` côté source) : un passé y est simplement terminé.
    static func statusBadge(_ event: EvEvent, now: Date) -> EvEventStatusBadgeKey? {
        let phase = phase(event, now: now)
        if phase == .live { return .enCours }
        if phase != .finished { return nil }
        return .termine
    }

    /// Pastille de statut sur la page de l'événement, où l'état de correction
    /// est connu : `results` à `nil` pendant le chargement (la correction est le
    /// cas courant à la fin), puis l'état relu du serveur. Sans copie, il n'y a
    /// rien à corriger : l'événement est terminé (`eventStatusBadge`).
    static func statusBadge(_ event: EvEvent, now: Date, results: EvResultsState?) -> EvEventStatusBadgeKey? {
        let phase = phase(event, now: now)
        if phase == .live { return .enCours }
        if phase != .finished { return nil }
        guard let results else { return .correctionEnCours }
        if results.leaderboard != nil { return .termine }
        return results.participants > 0 ? .correctionEnCours : .termine
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
