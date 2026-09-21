//
//  EvEventDateFormatting.swift
//  Duello
//
//  Étiquettes de date des cartes d'événement et du rappel d'agenda : jour de la
//  semaine abrégé, mois abrégé, numéro du jour, plage horaire, jour long et
//  heure locale.
//
//  Fichiers source Expo portés :
//    - src/components/EventsList.tsx  (`parseEventDay`, `eventWeekdayLabel`,
//      `eventTimeRange`, `eventMonthLabel`, `eventDayNumber`)
//    - src/utils/eventCalendar.ts     (`formatEventDay`, heure du rappel)
//
//  Cible : iOS 16.
//
import Foundation

enum EvEventDateFormatting {
    /// Décode « AAAA-MM-JJ » en date locale, sans piège de fuseau horaire.
    static func parseDay(_ date: String) -> Date? {
        let parts = date.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3, parts[0] > 0, parts[1] > 0, parts[2] > 0 else { return nil }
        var components = DateComponents()
        components.year = parts[0]
        components.month = parts[1]
        components.day = parts[2]
        return Calendar.current.date(from: components)
    }

    /// Étiquette du jour de la semaine au-dessus du numéro (« DIM », « LUN »…).
    static func weekdayLabel(_ date: String) -> String {
        let labels = ["DIM", "LUN", "MAR", "MER", "JEU", "VEN", "SAM"]
        guard let day = parseDay(date) else { return "" }
        let index = Calendar.current.component(.weekday, from: day) - 1
        return labels.indices.contains(index) ? labels[index] : ""
    }

    /// Mois abrégé (« nov. ») pour la pastille de date, sans le point.
    static func monthLabel(_ date: String) -> String {
        guard let day = parseDay(date) else { return "" }
        return formatter("MMM").string(from: day).replacingOccurrences(of: ".", with: "")
    }

    /// Numéro du jour dans le mois.
    static func dayNumber(_ date: String) -> Int {
        guard let day = parseDay(date) else { return 0 }
        return Calendar.current.component(.day, from: day)
    }

    /// Plage horaire « 16:00 – 17:00 », ou `nil` sans horaire de début.
    static func timeRange(_ event: EvEvent) -> String? {
        guard let start = event.startTime else { return nil }
        guard let end = event.endTime else { return start }
        return "\(start) – \(end)"
    }

    /// Jour long « dimanche 4 octobre », pour le rappel copié.
    static func longDay(_ date: String) -> String {
        guard let day = parseDay(date) else { return date }
        return formatter("EEEE d MMMM").string(from: day)
    }

    /// Heure locale « 16:04 » d'un instant, pour l'en-tête de salle d'attente.
    static func clock(_ at: Date) -> String {
        formatter("HH:mm").string(from: at)
    }

    /// Formateur français du module, au motif demandé.
    private static func formatter(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = format
        return formatter
    }
}
