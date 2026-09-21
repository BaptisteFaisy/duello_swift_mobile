//
//  ChartTimeSeries.swift
//  Duello
//
//  Découpage du temps par matière (lot D « Graphiques », préfixe `Chart`).
//
//  Fichier source Expo porté (noms et libellés repris) :
//    - src/utils/subjectTimeSeries.ts (`TimeGranularity`, `BUCKET_COUNTS`,
//      `SubjectTimeBucket`, `bucketStart`, `shiftBucket`,
//      `buildSubjectTimeSeries`, `subjectTotals`, `bucketAxisLabel`,
//      `bucketTitle`, `windowLabel`)
//
//  Les libellés de dates suivent `fr-FR` : initiales `L M M J V S D`, mois
//  abrégés à la française, semaine commençant le lundi. Cible iOS 16.
//
import Foundation

/// `TimeGranularity` de `utils/subjectTimeSeries.ts`.
enum ChartTimeGranularity: String, CaseIterable, Hashable {
    case day
    case week
    case month

    /// Adjectif repris dans les libellés d'accessibilité (« quotidienne »…).
    var name: String {
        switch self {
        case .day: return "quotidienne"
        case .week: return "hebdomadaire"
        case .month: return "mensuelle"
        }
    }
}

/// `SubjectTimeBucket` de `utils/subjectTimeSeries.ts`.
struct ChartTimeBucket: Identifiable, Hashable {
    /// Début de la période, à minuit : identifie la colonne.
    var start: Double
    /// Minutes travaillées dans la période, matière par matière.
    var minutesBySubject: [String: Double]
    /// Total de la période.
    var minutes: Double
    var id: Double { start }
}

/// `ActivitySession` de `types.ts` réduit au temps travaillé.
struct ChartActivitySession: Hashable {
    var at: Double
    var subject: String
    var minutes: Double
}

/// `buildSubjectTimeSeries` et ses dépendances (`utils/subjectTimeSeries.ts`).
enum ChartTimeSeries {
    /// `BUCKET_COUNTS` : sept colonnes pour chaque niveau de lecture.
    static let bucketCounts = 7

    private static let weekdayInitials = ["L", "M", "M", "J", "V", "S", "D"]
    private static let weekdays = [
        "Lundi", "Mardi", "Mercredi", "Jeudi", "Vendredi", "Samedi", "Dimanche",
    ]
    private static let months = [
        "janvier", "février", "mars", "avril", "mai", "juin", "juillet",
        "août", "septembre", "octobre", "novembre", "décembre",
    ]
    private static let monthAbbreviations = [
        "janv.", "févr.", "mars", "avr.", "mai", "juin", "juil.",
        "août", "sept.", "oct.", "nov.", "déc.",
    ]

    private static var calendar: Calendar { Calendar.current }

    /// `Date` à partir d'un horodatage en millisecondes.
    static func date(_ milliseconds: Double) -> Date {
        Date(timeIntervalSince1970: milliseconds / 1000)
    }

    /// Horodatage en millisecondes d'une `Date`.
    static func milliseconds(_ date: Date) -> Double {
        date.timeIntervalSince1970 * 1000
    }

    /// Lundi de la semaine, à minuit : une semaine de travail commence le lundi.
    private static func startOfWeek(_ at: Double) -> Date {
        let start = calendar.startOfDay(for: date(at))
        let weekday = calendar.component(.weekday, from: start) // 1 = dimanche
        let sinceMonday = (weekday + 5) % 7
        return calendar.date(byAdding: .day, value: -sinceMonday, to: start) ?? start
    }

    /// Début de la période contenant `at`.
    static func bucketStart(_ at: Double, _ granularity: ChartTimeGranularity) -> Double {
        switch granularity {
        case .day:
            return milliseconds(calendar.startOfDay(for: date(at)))
        case .week:
            return milliseconds(startOfWeek(at))
        case .month:
            let components = calendar.dateComponents([.year, .month], from: date(at))
            return milliseconds(calendar.date(from: components) ?? date(at))
        }
    }

    /// Décale une borne de période de `steps` jours, semaines ou mois.
    static func shift(
        _ start: Double,
        _ granularity: ChartTimeGranularity,
        _ steps: Int
    ) -> Double {
        let component: Calendar.Component = {
            switch granularity {
            case .month: return .month
            case .week: return .weekOfYear
            case .day: return .day
            }
        }()
        let shifted = calendar.date(byAdding: component, value: steps, to: date(start))
            ?? date(start)
        // Un changement d'heure ne doit pas décaler la colonne d'une journée.
        return milliseconds(calendar.startOfDay(for: shifted))
    }

    /// Répartit les sessions terminées de l'inscription à la période en cours.
    /// Les périodes sans entraînement sont conservées : l'axe reste régulier.
    static func build(
        sessions: [ChartActivitySession],
        granularity: ChartTimeGranularity,
        at: Double? = nil,
        count: Int = 7,
        registeredAt: Double? = nil
    ) -> [ChartTimeBucket] {
        let columns = max(1, count)
        let reference = at ?? milliseconds(Date())
        let current = bucketStart(reference, granularity)
        let registered = registeredAt ?? 0
        let hasRegistration = registered.isFinite && registered > 0
        let defaultStart = shift(current, granularity, -(columns - 1))
        var start = hasRegistration
            ? min(bucketStart(registered, granularity), defaultStart)
            : defaultStart

        var buckets: [ChartTimeBucket] = []
        var byStart: [Double: Int] = [:]
        while start <= current {
            buckets.append(ChartTimeBucket(start: start, minutesBySubject: [:], minutes: 0))
            byStart[start] = buckets.count - 1
            let next = shift(start, granularity, 1)
            if next <= start { break }
            start = next
        }

        for session in sessions {
            if session.minutes <= 0 { continue }
            if hasRegistration && session.at < registered { continue }
            guard let index = byStart[bucketStart(session.at, granularity)] else { continue }
            buckets[index].minutes += session.minutes
            buckets[index].minutesBySubject[session.subject, default: 0] += session.minutes
        }
        return buckets
    }

    /// Minutes cumulées par matière sur la fenêtre affichée.
    static func totals(_ buckets: [ChartTimeBucket]) -> [String: Double] {
        var totals: [String: Double] = [:]
        for bucket in buckets {
            for (subject, minutes) in bucket.minutesBySubject {
                totals[subject, default: 0] += minutes
            }
        }
        return totals
    }

    /// Étiquette sous une colonne : « J », « 21/07 » ou « juil. ».
    static func axisLabel(_ start: Double, _ granularity: ChartTimeGranularity) -> String {
        let components = calendar.dateComponents(
            [.year, .month, .day, .weekday],
            from: date(start)
        )
        let month = (components.month ?? 1) - 1
        switch granularity {
        case .month:
            return monthAbbreviations[month]
        case .week:
            let day = String(format: "%02d", components.day ?? 1)
            let number = String(format: "%02d", components.month ?? 1)
            return "\(day)/\(number)"
        case .day:
            return weekdayInitials[((components.weekday ?? 1) + 5) % 7]
        }
    }

    /// Période nommée en entier, du jour au mois.
    static func title(_ start: Double, _ granularity: ChartTimeGranularity) -> String {
        let components = calendar.dateComponents(
            [.year, .month, .day, .weekday],
            from: date(start)
        )
        let month = (components.month ?? 1) - 1
        let day = "\(components.day ?? 1) \(months[month])"
        switch granularity {
        case .month:
            let name = months[month]
            let capitalized = name.prefix(1).uppercased() + String(name.dropFirst())
            return "\(capitalized) \(components.year ?? 0)"
        case .week:
            return "Semaine du \(day)"
        case .day:
            return "\(weekdays[((components.weekday ?? 1) + 5) % 7]) \(day)"
        }
    }

    /// Étendue couverte par le graphique, pour titrer le détail par matière.
    static func windowLabel(_ count: Int, _ granularity: ChartTimeGranularity) -> String {
        switch granularity {
        case .month:
            return count > 1 ? "\(count) derniers mois" : "Ce mois-ci"
        case .week:
            return count > 1 ? "\(count) dernières semaines" : "Cette semaine"
        case .day:
            return count > 1 ? "\(count) derniers jours" : "Aujourd’hui"
        }
    }
}
