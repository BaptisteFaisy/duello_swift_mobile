//
//  AdmAnalytics.swift
//  Duello
//
//  Agrégation des indicateurs d'usage, portée de `src/admin/adminAnalytics.ts`
//  (`AnalyticsRange`, `AnalyticsDay`, `AnalyticsSummary`,
//  `buildAnalyticsSummary`, `analyticsToday`).
//
//  Règles reprises telles quelles :
//    - seules les journées présentes dans la période comptent ;
//    - une journée est « active » si du temps a été passé, qu'une session a été
//      ouverte ou qu'un exercice a été terminé ;
//    - le classement d'engagement garde les 8 premiers comptes, triés par temps
//      actif puis par exercices terminés.
//
//  Cible : iOS 16. Aucune dépendance externe.
//

import Foundation

/// `AnalyticsRange` : les trois périodes proposées par l'écran.
enum AdmAnalyticsRange: Int, CaseIterable, Identifiable {
    case seven = 7
    case thirty = 30
    case ninety = 90

    var id: Int { rawValue }

    /// Libellé du bouton de période : « 7 jours », « 30 jours », « 90 jours ».
    var title: String { "\(rawValue) jours" }
}

/// `AnalyticsDay` : une journée agrégée.
struct AdmAnalyticsDay: Identifiable {
    var date: String
    var activeUsers: Int
    var activeSeconds: Double
    var exercises: Int
    var sessions: Int

    var id: String { date }
}

/// `AnalyticsSummary['topUsers'][number]` : un compte du classement d'engagement.
struct AdmTopUser: Identifiable {
    var id: String
    var displayName: String
    var activeSeconds: Double
    var exercises: Int
}

/// `AnalyticsSummary` : indicateurs d'une période.
struct AdmAnalyticsSummary {
    var registeredUsers: Int
    var trackedUsers: Int
    var activeUsers: Int
    var activeUserDays: Int
    var totalSeconds: Double
    var averageDailySeconds: Double
    var totalExercises: Int
    var totalChallenges: Int
    var today: AdmAnalyticsDay
    var pageSeconds: [AdmUsagePage: Double]
    var pageVisits: [AdmUsagePage: Int]
    var days: [AdmAnalyticsDay]
    var topUsers: [AdmTopUser]
}

/// Accumulateur interne de `buildAnalyticsSummary`.
private struct AdmAnalyticsAggregate {
    var byDate: [String: AdmAnalyticsDay]
    var pageSeconds: [AdmUsagePage: Double] = [:]
    var pageVisits: [AdmUsagePage: Int] = [:]
    var totalChallenges = 0
    var activeUserDays = 0
    var topUsers: [AdmTopUser] = []

    init(dates: [String]) {
        var days: [String: AdmAnalyticsDay] = [:]
        for date in dates {
            days[date] = AdmAnalyticsDay(
                date: date,
                activeUsers: 0,
                activeSeconds: 0,
                exercises: 0,
                sessions: 0
            )
        }
        byDate = days
    }

    /// Ajoute l'activité d'un compte sur la période demandée.
    mutating func add(_ user: AdmUserRecord, wanted: Set<String>) {
        var seconds: Double = 0
        var exercises = 0
        for day in user.usage?.daily ?? [] where wanted.contains(day.date) {
            guard var aggregate = byDate[day.date] else { continue }
            let isActive = day.activeSeconds > 0
                || day.sessions > 0
                || day.actions.exerciseCompleted > 0
            if isActive {
                aggregate.activeUsers += 1
                activeUserDays += 1
            }
            aggregate.activeSeconds += day.activeSeconds
            aggregate.exercises += day.actions.exerciseCompleted
            aggregate.sessions += day.sessions
            byDate[day.date] = aggregate

            seconds += day.activeSeconds
            exercises += day.actions.exerciseCompleted
            totalChallenges += day.actions.challengeCompleted
            for page in AdmUsagePage.allCases {
                pageSeconds[page, default: 0] += day.pageSeconds.seconds(for: page)
                pageVisits[page, default: 0] += day.pageVisits.count(for: page)
            }
        }
        if seconds > 0 || exercises > 0 {
            topUsers.append(
                AdmTopUser(
                    id: user.id,
                    displayName: AdmUserText.analyticsDisplayName(user.displayName),
                    activeSeconds: seconds,
                    exercises: exercises
                )
            )
        }
    }

    /// `users.filter(...).length` : comptes ayant au moins une journée active.
    func activeUsers(_ users: [AdmUserRecord], wanted: Set<String>) -> Int {
        users.filter { isActive(user: $0, wanted: wanted) }.count
    }

    /// Vrai si le compte a au moins une journée active dans la période.
    private func isActive(user: AdmUserRecord, wanted: Set<String>) -> Bool {
        for day in user.usage?.daily ?? [] where wanted.contains(day.date) {
            if day.activeSeconds > 0 || day.sessions > 0 || day.actions.exerciseCompleted > 0 {
                return true
            }
        }
        return false
    }

    /// `topUsers.sort(...).slice(0, 8)`.
    func rankedTopUsers() -> [AdmTopUser] {
        let sorted = topUsers.sorted { left, right in
            if left.activeSeconds == right.activeSeconds {
                return left.exercises > right.exercises
            }
            return left.activeSeconds > right.activeSeconds
        }
        return Array(sorted.prefix(8))
    }
}

/// `buildAnalyticsSummary` de `adminAnalytics.ts`.
enum AdmAnalyticsEngine {
    /// `analyticsToday` : clé du jour courant (`yyyy-MM-dd`, heure locale).
    static func today(now: Date = Date()) -> String {
        AdmFormat.dayKey(now)
    }

    /// `buildAnalyticsSummary(users, range, today)`.
    static func build(
        users: [AdmUserRecord],
        range: AdmAnalyticsRange,
        today: String
    ) -> AdmAnalyticsSummary {
        let dates = rangeDates(range: range, today: today)
        let wanted = Set(dates)
        var aggregate = AdmAnalyticsAggregate(dates: dates)
        for user in users {
            aggregate.add(user, wanted: wanted)
        }

        let days = dates.compactMap { aggregate.byDate[$0] }
        let totalSeconds = days.reduce(0.0) { $0 + $1.activeSeconds }
        let emptyToday = AdmAnalyticsDay(
            date: today,
            activeUsers: 0,
            activeSeconds: 0,
            exercises: 0,
            sessions: 0
        )
        return AdmAnalyticsSummary(
            registeredUsers: users.count,
            trackedUsers: users.filter { $0.usage != nil }.count,
            activeUsers: aggregate.activeUsers(users, wanted: wanted),
            activeUserDays: aggregate.activeUserDays,
            totalSeconds: totalSeconds,
            averageDailySeconds: aggregate.activeUserDays > 0
                ? totalSeconds / Double(aggregate.activeUserDays)
                : 0,
            totalExercises: days.reduce(0) { $0 + $1.exercises },
            totalChallenges: aggregate.totalChallenges,
            today: aggregate.byDate[today] ?? emptyToday,
            pageSeconds: aggregate.pageSeconds,
            pageVisits: aggregate.pageVisits,
            days: days,
            topUsers: aggregate.rankedTopUsers()
        )
    }

    /// `rangeDates` : les `range` derniers jours, du plus ancien au jour courant.
    /// L'ancre est placée à midi comme le source (`new Date(y, m-1, d, 12)`),
    /// pour rester juste les jours de changement d'heure.
    private static func rangeDates(range: AdmAnalyticsRange, today: String) -> [String] {
        guard let day = AdmFormat.day(from: today) else { return [today] }
        let end = Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: day) ?? day
        let count = range.rawValue
        return (0..<count).compactMap { index in
            let offset = -(count - 1 - index)
            guard let date = Calendar.current.date(byAdding: .day, value: offset, to: end) else {
                return nil
            }
            return AdmFormat.dayKey(date)
        }
    }
}
