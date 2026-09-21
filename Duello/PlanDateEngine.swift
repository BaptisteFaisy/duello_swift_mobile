//
//  PlanDateEngine.swift
//  Duello
//
//  Écran « Plan » — moteur de dates : calendrier grégorien, midi de référence, horizon du programme, clé de date locale (portage de date.ts).
//
import Foundation

// MARK: - Moteur de dates (`utils/date.ts`)

/// Portage des utilitaires de date utilisés par l'écran : jours du programme,
/// clé de date locale, formatage français et lecture de la saisie `JJ/MM/AAAA`.
enum PlanDateEngine {
    static let frenchLocale = Locale(identifier: "fr_FR")

    private static func makeFormatter(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = frenchLocale
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = format
        return formatter
    }

    /// `longDateFormatter` (EnhancedPlanScreen ligne 18) : « 21 septembre 2026 ».
    private static let longFormatter = makeFormatter("d MMMM yyyy")
    /// `monthDayFormatter` (date.ts ligne 11) : « 21 septembre ».
    private static let monthDayFormatter = makeFormatter("d MMMM")
    /// `shortWeekdayFormatter` (date.ts ligne 7) : « lun. » → « lun ».
    private static let shortWeekdayFormatter = makeFormatter("EEE")
    /// `toLocalDateKey` (date.ts ligne 71) : AAAA-MM-JJ.
    private static let keyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
    /// `formatDateInput` (EnhancedPlanScreen lignes 467-471).
    private static let inputFormatter = makeFormatter("dd/MM/yyyy")

    static var gregorian: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = frenchLocale
        calendar.timeZone = TimeZone.current
        return calendar
    }

    /// Toutes les dates de l'écran sont construites à **12:00**, comme la source :
    /// un passage d'heure d'été ne peut pas faire basculer une date de jour.
    static func noonDate(for date: Date) -> Date {
        let calendar = gregorian
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let noon = DateComponents(
            year: components.year,
            month: components.month,
            day: components.day,
            hour: 12,
            minute: 0,
            second: 0
        )
        return calendar.date(from: noon) ?? date
    }

    static func addDays(_ days: Int, to date: Date) -> Date {
        let calendar = gregorian
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let shifted = DateComponents(
            year: components.year,
            month: components.month,
            day: (components.day ?? 1) + days,
            hour: 12,
            minute: 0,
            second: 0
        )
        return calendar.date(from: shifted) ?? date
    }

    /// `getProgramHorizonDate` (date.ts lignes 57-61) : 21 septembre, reporté à
    /// l'année suivante une fois la date passée.
    static func programHorizon(today: Date) -> Date {
        let calendar = gregorian
        let year = calendar.component(.year, from: today)
        let thisYear = DateComponents(year: year, month: 9, day: 21, hour: 12)
        let horizon = calendar.date(from: thisYear) ?? today
        guard today > horizon else { return horizon }
        let nextYear = DateComponents(year: year + 1, month: 9, day: 21, hour: 12)
        return calendar.date(from: nextYear) ?? horizon
    }

    /// `toLocalDateKey` (date.ts lignes 71-76).
    static func localDateKey(_ date: Date) -> String {
        keyFormatter.string(from: date)
    }
}
