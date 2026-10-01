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
    case year
    case max

    /// Adjectif repris dans les libellés d'accessibilité (« quotidienne »…).
    /// La source ne distingue que le jour et la semaine : au-delà, elle retombe
    /// sur « mensuelle » (`granularityName` de `SubjectTimeTrendChart.tsx`,
    /// ternaire `day ? … : week ? … : 'mensuelle'` des trois `…Chart.tsx`).
    var name: String {
        switch self {
        case .day: return "quotidienne"
        case .week: return "hebdomadaire"
        case .month, .year, .max: return "mensuelle"
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

/// `ActivitySession` de `types.ts` réduit au temps travaillé et aux exercices.
struct ChartActivitySession: Hashable {
    var at: Double
    var subject: String
    var minutes: Double
    /// Exercices terminés dans la session (`exercises`). Repli à zéro tant que
    /// le journal local ne porte pas encore ce compteur.
    var exercises: Double = 0
}

/// `ExerciseCountBucket` de `utils/subjectTimeSeries.ts` : exercices terminés
/// par période.
struct ChartExerciseBucket: Identifiable, Hashable {
    /// Début de la période, à minuit : identifie la colonne.
    var start: Double
    /// Exercices terminés dans la période.
    var exercises: Double
    var id: Double { start }
}

/// `buildSubjectTimeSeries` et ses dépendances (`utils/subjectTimeSeries.ts`).
enum ChartTimeSeries {
    /// `MIN_MAX_BUCKETS` : le maximum montre au moins sept mois, sinon un point
    /// seul ne se lit pas comme une courbe.
    static let minMaxBuckets = 7

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
        case .month, .year, .max:
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
            case .month, .year, .max: return .month
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
        count: Int? = nil,
        registeredAt: Double? = nil
    ) -> [ChartTimeBucket] {
        let columns = max(1, count ?? bucketCount(granularity))
        let reference = at ?? milliseconds(Date())
        let current = bucketStart(reference, granularity)
        let registered = registeredAt ?? 0
        let hasRegistration = registered.isFinite && registered > 0
        var start = startBucket(
            sessions: sessions,
            granularity: granularity,
            current: current,
            columns: columns,
            hasRegistration: hasRegistration,
            registered: registered,
            weight: { $0.minutes }
        )

        var buckets: [ChartTimeBucket] = []
        var byStart: [Double: Int] = [:]
        while start <= current {
            buckets.append(ChartTimeBucket(start: start, minutesBySubject: [:], minutes: 0))
            byStart[start] = buckets.count - 1
            let next = shift(start, granularity, 1)
            if next <= start { break }
            start = next
        }
        if granularity == .max && buckets.count > columns {
            capToColumns(&buckets, &byStart, columns, startOf: { $0.start })
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
        case .month, .year, .max:
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
        case .month, .year, .max:
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
        case .max:
            return "Tout l’historique"
        case .month, .year:
            return count > 1 ? "\(count) derniers mois" : "Ce mois-ci"
        case .week:
            return count > 1 ? "\(count) dernières semaines" : "Cette semaine"
        case .day:
            return count > 1 ? "\(count) derniers jours" : "Aujourd’hui"
        }
    }
}
