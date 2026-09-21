//
//  PlanDateEngine+Formatting.swift
//  Duello
//
//  Écran « Plan » — moteur de dates : formatage lisible, saisie JJ/MM/AAAA, heures et durées.
//
import Foundation

extension PlanDateEngine {

    /// `longDateFormatter` : « 21 septembre 2026 » (affichage hors saisie).
    static func longDate(_ date: Date) -> String {
        longFormatter.string(from: date)
    }

    /// `formatDateInput` : « 21/09/2026 ».
    static func inputDate(_ date: Date) -> String {
        inputFormatter.string(from: date)
    }

    /// `maskDateInput` (lignes 474-478) : séparateurs insérés à la place de
    /// l'élève, 8 chiffres au plus.
    static func maskInput(_ value: String) -> String {
        let digits = String(value.filter { $0.isNumber }.prefix(8))
        var parts: [String] = []
        if digits.count > 0 { parts.append(String(digits.prefix(2))) }
        if digits.count > 2 { parts.append(String(digits.dropFirst(2).prefix(2))) }
        if digits.count > 4 { parts.append(String(digits.dropFirst(4).prefix(4))) }
        return parts.joined(separator: "/")
    }

    /// `parseDateInput` (lignes 481-496) : accepte JJ/MM, JJ/MM/AA et
    /// JJ/MM/AAAA ; l'année omise se déduit du programme en cours et bascule sur
    /// l'année suivante si la date est déjà passée.
    static func parseDate(_ value: String, reference: Date) -> Date? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let pattern = "^(\\d{1,2})/(\\d{1,2})(?:/(\\d{2}|\\d{4}))?$"
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: trimmed, options: [], range: NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)) else {
            return nil
        }
        func group(_ index: Int) -> String? {
            guard let range = Range(match.range(at: index), in: trimmed) else { return nil }
            return String(trimmed[range])
        }
        guard let dayText = group(1), let monthText = group(2),
              let day = Int(dayText), let month = Int(monthText) else { return nil }

        let rawYear = group(3)
        let year: Int
        if let rawYear, let parsedYear = Int(rawYear) {
            year = parsedYear < 100 ? 2000 + parsedYear : parsedYear
        } else {
            year = gregorian.component(.year, from: reference)
        }

        let calendar = gregorian
        guard let date = calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12)) else { return nil }
        let check = calendar.dateComponents([.day, .month], from: date)
        guard check.day == day, check.month == month else { return nil }
        if rawYear == nil && date < reference {
            return calendar.date(from: DateComponents(year: year + 1, month: month, day: day, hour: 12)) ?? date
        }
        return date
    }

    /// `findDayForInput` (lignes 498-503).
    static func findDay(for value: String, in days: [PlanDay]) -> PlanDay? {
        guard let reference = days.first?.date else { return nil }
        guard let parsed = parseDate(value, reference: reference) else { return nil }
        let key = localDateKey(parsed)
        return days.first { $0.dateKey == key }
    }

    /// `timeToMinutes` (lignes 615-618).
    static func timeToMinutes(_ time: String) -> Int {
        let parts = time.split(separator: ":").map { Int($0) ?? 0 }
        let hours = parts.first ?? 0
        let minutes = parts.count > 1 ? parts[1] : 0
        return hours * 60 + minutes
    }

    /// `minutesToTime` (lignes 620-623), borné à 23:59.
    static func minutesToTime(_ minutes: Int) -> String {
        let safe = max(0, min(minutes, 23 * 60 + 59))
        return String(format: "%02d:%02d", safe / 60, safe % 60)
    }

    /// `formatDuration` (lignes 368-374) : « 1 h 05 », « 2 h », « 45 min ».
    static func formatDuration(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        if hours > 0 && mins > 0 { return "\(hours) h \(String(format: "%02d", mins))" }
        if hours > 0 { return "\(hours) h" }
        return "\(mins) min"
    }
}
