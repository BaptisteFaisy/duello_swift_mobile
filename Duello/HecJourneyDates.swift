import Foundation

/// Dates du parcours HEC : normalisation, bornes de l'année scolaire,
/// vacances officielles et mise en forme française.
///
/// Porté de `src/utils/hecJourneyTimeline.ts` — `DAY_MS`,
/// `startOfLocalDay`, `normalizeHecJourneyDate`, `hecJourneySummerBreakDate`,
/// `hecJourneySecondYearEndDate`, `SCHOOL_HOLIDAY_TITLES`,
/// `SCHOOL_HOLIDAY_STARTS_2026_2027`, `hecJourneySchoolHolidayStarts` et
/// `formatHecJourneyDate` (`Intl.DateTimeFormat('fr-FR', …)`).
///
/// Tout est calculé dans le calendrier et le fuseau locaux, comme la source
/// (`new Date(...)`), et les dates restent ramenées au début du jour local.
enum HecJourneyDates {

    /// `DAY_MS`, en secondes.
    static let dayInterval: TimeInterval = 86_400

    private static let frenchLocale = Locale(identifier: "fr_FR")

    // MARK: Normalisation

    /// `startOfLocalDay`.
    static func startOfLocalDay(_ date: Date) -> Date {
        Calendar.current.startOfDay(for: date)
    }

    /// `normalizeHecJourneyDate` : jamais avant le jour d'inscription, et une
    /// valeur illisible (absente ou négative) retombe sur aujourd'hui.
    static func normalize(_ value: Date, registeredAt: Date) -> Date {
        let registration = isUsable(registeredAt) ? registeredAt : Date()
        let candidate = isUsable(value) ? value : Date()
        return max(startOfLocalDay(registration), startOfLocalDay(candidate))
    }

    /// `Number.isFinite(value) && value > 0` côté Expo.
    static func isUsable(_ date: Date) -> Bool {
        let seconds = date.timeIntervalSince1970
        return seconds.isFinite && seconds > 0
    }

    // MARK: Mise en forme

    /// `formatHecJourneyDate` : « 01 septembre ».
    static func format(_ date: Date) -> String {
        dayMonthFormatter.string(from: date)
    }

    /// En-tête du calendrier : « septembre 2026 »
    /// (`CALENDAR_MONTH_FORMATTER`).
    static func monthLabel(_ date: Date) -> String {
        monthYearFormatter.string(from: date)
    }

    private static let dayMonthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = frenchLocale
        formatter.setLocalizedDateFormatFromTemplate("ddMMMM")
        return formatter
    }()

    private static let monthYearFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = frenchLocale
        formatter.setLocalizedDateFormatFromTemplate("yyyyMMMM")
        return formatter
    }()

    // MARK: Bornes de l'année scolaire

    /// `hecJourneySummerBreakDate` : les deux frises se rejoignent le 1er
    /// juillet qui suit l'inscription (même année avant juillet, année
    /// suivante à partir de juillet).
    static func summerBreakDate(registeredAt: Date) -> Date {
        let registration = normalize(registeredAt, registeredAt: registeredAt)
        let month = Calendar.current.component(.month, from: registration)
        let year = Calendar.current.component(.year, from: registration)
        return date(year: month >= 7 ? year + 1 : year, month: 7, day: 1)
    }

    /// `hecJourneySecondYearEndDate` : premier 1er août strictement postérieur
    /// à l'inscription.
    static func secondYearEndDate(registeredAt: Date) -> Date {
        let registration = normalize(registeredAt, registeredAt: registeredAt)
        let year = Calendar.current.component(.year, from: registration)
        let augustFirst = date(year: year, month: 8, day: 1)
        return registration < augustFirst ? augustFirst : date(year: year + 1, month: 8, day: 1)
    }

    // MARK: Vacances scolaires

    /// `hecJourneySchoolHolidayStarts` : débuts officiels de métropole pour
    /// l'année scolaire 2026-2027, par zone.
    static func schoolHolidayStarts(
        _ holiday: HecJourneySchoolHoliday,
        zone: HecJourneySchoolZone
    ) -> [(title: String, date: Date)] {
        let holidays = holiday == .toutes ? HecJourneySchoolHoliday.individual : [holiday]
        return holidays.compactMap { candidate in
            guard let start = starts2026_2027[zone]?[candidate] else { return nil }
            return (title: candidate.label, date: date(year: start.year, month: start.month, day: start.day))
        }
    }

    /// `SCHOOL_HOLIDAY_STARTS_2026_2027` (mois en clair, 1 = janvier).
    private static let starts2026_2027: [HecJourneySchoolZone: [HecJourneySchoolHoliday: (year: Int, month: Int, day: Int)]] = [
        .a: [
            .toussaint: (2026, 10, 17), .noel: (2026, 12, 19), .hiver: (2027, 2, 13),
            .printemps: (2027, 4, 10), .ete: (2027, 7, 3),
        ],
        .b: [
            .toussaint: (2026, 10, 17), .noel: (2026, 12, 19), .hiver: (2027, 2, 20),
            .printemps: (2027, 4, 17), .ete: (2027, 7, 3),
        ],
        .c: [
            .toussaint: (2026, 10, 17), .noel: (2026, 12, 19), .hiver: (2027, 2, 6),
            .printemps: (2027, 4, 3), .ete: (2027, 7, 3),
        ],
    ]

    // MARK: Utilitaires

    /// Minuit local pour une date donnée.
    static func date(year: Int, month: Int, day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return Calendar.current.date(from: components) ?? Date()
    }

    /// `startOfMonth` de `HecJourney.tsx`.
    static func startOfMonth(_ date: Date) -> Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: components) ?? date
    }
}
