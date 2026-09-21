//
//  CollTrainingTime.swift
//  Duello
//
//  Temps de travail réellement passé, jour par jour, matière par matière.
//
//  Fichiers source Expo portés :
//    - src/utils/trainingTime.ts
//        `TrainingActivity`, `TRAINING_ACTIVITIES`, `TRAINING_ACTIVITY_LABELS`,
//        `ITEM_ACTIVITIES`, `TrainingTimeEntry`, `TrainingTimeLog`,
//        `normalizeTrainingTime`, `trainingSubjects`, `subjectTrainingMinutes`,
//        `DailyTrainingPoint`, `buildDailyTrainingSeries`, `totalTrainingSeconds`.
//    - src/utils/activity.ts
//        `dayKey` (jour local AAAA-MM-JJ).
//
//  Cible : iOS 16, aucune dépendance externe.
//
import Foundation

/// Les quatre façons de travailler une matière (`TrainingActivity`).
enum CollTrainingActivity: String, Codable, CaseIterable {
    case exercice
    case colle
    case annale
    case defi

    /// `TRAINING_ACTIVITY_LABELS`.
    var label: String {
        switch self {
        case .exercice: return "Exercices"
        case .colle: return "Colles"
        case .annale: return "Annales"
        case .defi: return "Défis"
        }
    }

    /// `TRAINING_ACTIVITIES` : l'ordre du graphique.
    static let order: [CollTrainingActivity] = [.exercice, .colle, .annale, .defi]

    /// `ITEM_ACTIVITIES` : activités mesurées par le lecteur de sujets (les défis
    /// sont déjà comptés dans `XpActivity`).
    static let itemActivities: [CollTrainingActivity] = [.exercice, .colle, .annale]
}

/// Temps passé sur un type de sujet, une matière et une journée donnés.
struct CollTrainingTimeEntry: Codable, Equatable {
    /// Jour local AAAA-MM-JJ, comparable comme du texte.
    var day: String
    var subject: String
    var activity: CollTrainingActivity
    var seconds: Double
}

/// Journal de temps de travail (`TrainingTimeLog`).
struct CollTrainingTimeLog: Codable, Equatable {
    var version: Int
    var entries: [CollTrainingTimeEntry]

    /// `EMPTY_TRAINING_TIME`.
    static let empty = CollTrainingTimeLog(version: 1, entries: [])
}

/// Mesure à ajouter au journal (`TrainingTimeMeasure`).
struct CollTrainingTimeMeasure {
    var subject: String
    var activity: CollTrainingActivity
    /// Temps mesuré depuis le dernier versement.
    var milliseconds: Double
    var at: Double?
}

/// Une journée du graphique (`DailyTrainingPoint`).
struct CollDailyTrainingPoint: Equatable {
    var day: String
    /// Midi de la journée, pour la mettre en mots sans dépendre du fuseau.
    var at: Double
    var seconds: [CollTrainingActivity: Double]
    var totalSeconds: Double
}

/// Options du graphique quotidien (`DailyTrainingOptions`).
struct CollTrainingTimeOptions {
    /// Matière suivie ; toutes matières confondues si absente.
    var subject: String?
    /// Nombre de journées affichées, la dernière étant celle de `at`.
    var days: Int
    var at: Double = CollCompletion.now()
}

/// `normalizeTrainingTime` et les lectures du journal.
enum CollTrainingTime {
    /// Jours conservés : le graphique en montre 30 au plus, la marge reste large.
    private static let retainedDays = 180

    /// Jour local AAAA-MM-JJ (`dayKey` de `utils/activity.ts`).
    static func dayKey(at: Double) -> String {
        let date = Date(timeIntervalSince1970: at / 1000)
        let components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }

    /// `normalizeTrainingTime` : une mesure par jour, matière et activité, les
    /// journées trop anciennes en moins, puis tri stable.
    static func normalize(_ log: CollTrainingTimeLog?, at: Double = CollCompletion.now()) -> CollTrainingTimeLog {
        guard let entries = log?.entries else { return .empty }
        let floor = retentionFloor(at: at)
        var merged: [String: CollTrainingTimeEntry] = [:]

        for entry in entries {
            let day = entry.day
            let subject = entry.subject.trimmingCharacters(in: .whitespacesAndNewlines)
            let seconds = positiveSeconds(entry.seconds)
            guard day >= floor,
                  day.range(of: #"^\d{4}-\d{2}-\d{2}$"#, options: .regularExpression) != nil,
                  !subject.isEmpty,
                  seconds > 0
            else { continue }

            let key = "\(day)::\(subject)::\(entry.activity.rawValue)"
            let existing = merged[key]
            merged[key] = CollTrainingTimeEntry(
                day: day,
                subject: subject,
                activity: entry.activity,
                seconds: (existing?.seconds ?? 0) + seconds
            )
        }

        let sorted = merged.values.sorted { first, second in
            if first.day != second.day { return first.day < second.day }
            if first.subject != second.subject { return first.subject < second.subject }
            return activityRank(first.activity) < activityRank(second.activity)
        }
        return CollTrainingTimeLog(version: 1, entries: sorted)
    }

    /// `trainingSubjects` : matières mesurées, la plus travaillée en tête.
    static func subjects(_ log: CollTrainingTimeLog) -> [String] {
        var totals: [String: Double] = [:]
        for entry in log.entries { totals[entry.subject, default: 0] += entry.seconds }
        return totals.sorted { first, second in
            first.value != second.value ? first.value > second.value : first.key < second.key
        }.map { $0.key }
    }

    /// `subjectTrainingMinutes` : minutes mesurées par matière, limitées aux
    /// activités demandées.
    static func subjectMinutes(
        _ log: CollTrainingTimeLog,
        activities: [CollTrainingActivity] = CollTrainingActivity.order
    ) -> [String: Int] {
        var seconds: [String: Double] = [:]
        for entry in log.entries where activities.contains(entry.activity) {
            seconds[entry.subject, default: 0] += entry.seconds
        }
        return seconds.mapValues { Int(($0 / 60).rounded()) }
    }

    /// `buildDailyTrainingSeries` : journées de la plus ancienne à aujourd'hui,
    /// les journées sans travail restant présentes et vides.
    static func buildDailySeries(
        _ log: CollTrainingTimeLog,
        options: CollTrainingTimeOptions
    ) -> [CollDailyTrainingPoint] {
        let span = max(1, options.days)
        let calendar = Calendar.current
        var points: [CollDailyTrainingPoint] = []
        var indexByDay: [String: Int] = [:]

        for offset in stride(from: span - 1, through: 0, by: -1) {
            let base = Date(timeIntervalSince1970: options.at / 1000)
            let noon = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: base) ?? base
            let cursor = calendar.date(byAdding: .day, value: -offset, to: noon) ?? noon
            let stamp = cursor.timeIntervalSince1970 * 1000
            let point = CollDailyTrainingPoint(
                day: dayKey(at: stamp),
                at: stamp,
                seconds: [:],
                totalSeconds: 0
            )
            indexByDay[point.day] = points.count
            points.append(point)
        }

        for entry in log.entries {
            if let subject = options.subject, entry.subject != subject { continue }
            guard let index = indexByDay[entry.day] else { continue }
            points[index].seconds[entry.activity, default: 0] += entry.seconds
            points[index].totalSeconds += entry.seconds
        }
        return points
    }

    /// `totalTrainingSeconds` : cumul d'une série, activité par activité.
    static func totalSeconds(_ points: [CollDailyTrainingPoint]) -> [CollTrainingActivity: Double] {
        var totals: [CollTrainingActivity: Double] = [:]
        for point in points {
            for activity in CollTrainingActivity.order {
                totals[activity, default: 0] += point.seconds[activity] ?? 0
            }
        }
        return totals
    }

    // MARK: - Helpers

    /// `positiveSeconds` : un temps strictement positif, sinon zéro.
    private static func positiveSeconds(_ value: Double) -> Double {
        value.isFinite && value > 0 ? value : 0
    }

    /// Jour à partir duquel les mesures sont conservées, bornes incluses.
    private static func retentionFloor(at: Double) -> String {
        let calendar = Calendar.current
        let base = Date(timeIntervalSince1970: at / 1000)
        let noon = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: base) ?? base
        let floorDate = calendar.date(byAdding: .day, value: -(retainedDays - 1), to: noon) ?? noon
        return dayKey(at: floorDate.timeIntervalSince1970 * 1000)
    }

    /// Rang d'une activité dans l'ordre du graphique.
    private static func activityRank(_ activity: CollTrainingActivity) -> Int {
        CollTrainingActivity.order.firstIndex(of: activity) ?? CollTrainingActivity.order.count
    }
}
