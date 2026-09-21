//
//  PlanDateEngine+ProgramDays.swift
//  Duello
//
//  Écran « Plan » — moteur de dates : semaine JS, libellés de jour, week-end et construction des jours du programme.
//
import Foundation

extension PlanDateEngine {

    /// `getDayName` (EnhancedPlanScreen lignes 605-608) : `getDay()` JS place
    /// dimanche à 0, d'où la chaîne vide en tête du tableau.
    static func dayName(offset: Int, today: Date) -> String {
        let names = ["", "Lundi", "Mardi", "Mercredi", "Jeudi", "Vendredi", "Samedi"]
        let index = ((jsWeekday(today) + offset) % 7 + 7) % 7
        return names[index]
    }

    /// `isWeekend` (lignes 610-613).
    static func isWeekend(offset: Int, today: Date) -> Bool {
        let day = ((jsWeekday(today) + offset) % 7 + 7) % 7
        return day == 0 || day == 6
    }

    /// `new Date().getDay()` : dimanche = 0 … samedi = 6.
    static func jsWeekday(_ date: Date) -> Int {
        let weekday = gregorian.component(.weekday, from: date)
        return (weekday + 6) % 7
    }

    /// `getNextSevenDays` (date.ts lignes 35-50), jour par jour.
    static func day(for date: Date, offset: Int) -> PlanDay {
        let noon = noonDate(for: date)
        let short = shortWeekdayFormatter.string(from: noon).replacingOccurrences(of: ".", with: "")
        return PlanDay(
            dateKey: localDateKey(noon),
            date: noon,
            dayOffset: offset,
            dayLabel: String(short.prefix(3)),
            dayNumber: gregorian.component(.day, from: noon),
            fullLabel: PlanTaskAnalyzer.capitalize(monthDayFormatter.string(from: noon))
        )
    }

    /// Le jour 0 seul, sans construire tout l'horizon (premier rendu).
    static func firstDay(today: Date = Date()) -> PlanDay {
        day(for: today, offset: 0)
    }

    /// `getProgramDays` (date.ts lignes 63-69).
    static func programDays(today: Date = Date()) -> [PlanDay] {
        let start = noonDate(for: today)
        let horizon = programHorizon(today: start)
        let dayCount = max(1, Int((horizon.timeIntervalSince(start) / 86_400).rounded()) + 1)
        return (0..<dayCount).map { offset in
            day(for: addDays(offset, to: start), offset: offset)
        }
    }
}
