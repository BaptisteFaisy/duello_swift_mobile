//
//  EvEventCalendar.swift
//  Duello
//
//  Rappel d'événement dans l'agenda du téléphone, sans module natif : le rappel
//  complet (titre, jour, horaire) est copié dans le presse-papiers, puis
//  l'application Calendrier est ouverte ; en repli, la création dans Google
//  Agenda est préremplie par un lien.
//
//  Fichier source Expo porté : `src/utils/eventCalendar.ts`.
//  `Linking.openURL('calshow://')` d'Expo devient `UIApplication.open` : le
//  système seul décide, donc aucune autorisation ni reconstruction native.
//
//  Cible : iOS 16.
//
import Foundation
import UIKit

/// Voie d'ouverture de l'agenda (`EventCalendarOutcome`).
enum EvCalendarOutcome: Equatable {
    case native, google, none
}

enum EvEventCalendar {
    /// Message à coller dans un nouveau rappel d'agenda.
    static func reminder(_ event: EvEvent) -> String {
        let minutes = Int((EvEventSchedule.duration(event) / 60).rounded())
        let day = EvEventDateFormatting.longDay(event.date)
        let when: String
        if let start = EvEventSchedule.startDate(event) {
            when = "Le \(day) à \(EvEventDateFormatting.clock(start)) (\(minutes) min)."
        } else {
            when = "Le \(day) (\(minutes) min)."
        }
        return [
            "\(event.title) — concours blanc Duello",
            when,
            "Ouvre Duello quelques minutes avant pour rejoindre la salle d’attente.",
        ].joined(separator: "\n")
    }

    /// Copie le rappel ; renvoie vrai si le presse-papiers a servi.
    static func copyReminder(_ event: EvEvent) -> Bool {
        UIPasteboard.general.string = reminder(event)
        return true
    }

    /// Ouvre l'application d'agenda de l'appareil ; en repli, Google Agenda
    /// prérempli, comme `openEventCalendar` de la source.
    static func open(_ event: EvEvent) async -> EvCalendarOutcome {
        if let url = URL(string: "calshow://"), await openUrl(url) {
            return .native
        }
        return await openGoogleTemplate(event) ? .google : .none
    }

    /// Lien de création Google Agenda, prérempli du titre et des horaires.
    private static func openGoogleTemplate(_ event: EvEvent) async -> Bool {
        guard let start = EvEventSchedule.startDate(event) else { return false }
        let end = start.addingTimeInterval(EvEventSchedule.duration(event))
        var components = URLComponents(string: "https://calendar.google.com/calendar/render")
        components?.queryItems = [
            URLQueryItem(name: "action", value: "TEMPLATE"),
            URLQueryItem(name: "text", value: "\(event.title) — Duello"),
            URLQueryItem(name: "dates", value: "\(stamp(start))/\(stamp(end))"),
        ]
        guard let url = components?.url else { return false }
        return await openUrl(url)
    }

    /// Horodatage compact attendu par Google Agenda (« 20261004T160000Z »).
    private static func stamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        return formatter.string(from: date)
    }

    /// Ouvre une URL système et rend vrai si le système l'a acceptée.
    private static func openUrl(_ url: URL) async -> Bool {
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                UIApplication.shared.open(url, options: [:]) { accepted in
                    continuation.resume(returning: accepted)
                }
            }
        }
    }
}
