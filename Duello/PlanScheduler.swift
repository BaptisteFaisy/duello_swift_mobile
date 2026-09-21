//
//  PlanScheduler.swift
//  Duello
//
//  Écran « Plan » — répartition automatique des tâches sur les jours du programme (distributeTasks, nextAvailableMinute).
//
import Foundation

// MARK: - Répartition (`distributeTasks`, `nextAvailableMinute`)

/// Portage de `distributeTasks` (EnhancedPlanScreen lignes 505-559) et de
/// `nextAvailableMinute` (lignes 561-582) : chaque tâche est posée au plus tôt,
/// en évitant cours, séances déjà placées, dîner, douche et nuit.
enum PlanScheduler {
    static func distribute(
        tasks: [PlanTask],
        schedule: [PlanScheduleSlot],
        dayCount: Int,
        routine: PlanRoutine,
        today: Date = Date()
    ) -> [PlanSession] {
        guard dayCount > 0 else { return [] }

        // Curseurs initiaux : aujourd'hui 17:00, week-end 09:00, semaine 17:00.
        var cursors: [Int] = (0..<dayCount).map { day in
            if day == 0 { return 17 * 60 }
            return PlanDateEngine.isWeekend(offset: day, today: today) ? 9 * 60 : 17 * 60
        }

        var sessions: [PlanSession] = []

        for task in tasks {
            let latestDay = min(
                deadlineOffset(task.deadline, dayCount: dayCount, postponedDays: task.postponedDays, today: today),
                dayCount - 1
            )
            let duration = min(120, max(25, task.estimatedDuration ?? 45))

            var chosenDay = max(0, latestDay)
            var chosenStart = Int.max

            if latestDay >= 0 {
                for day in 0...latestDay {
                    let candidate = nextAvailableMinute(
                        start: cursors[day],
                        duration: duration,
                        dayOffset: day,
                        schedule: schedule,
                        sessions: sessions,
                        routine: routine,
                        today: today
                    )
                    if candidate < chosenStart {
                        chosenStart = candidate
                        chosenDay = day
                    }
                }
            }

            // Aucun créneau avant 21:00 : la tâche glisse au jour suivant, 09:00
            // le week-end et 17:00 en semaine.
            if chosenStart == Int.max || chosenStart + duration > 21 * 60 {
                chosenDay = min(latestDay + 1, dayCount - 1)
                chosenStart = nextAvailableMinute(
                    start: PlanDateEngine.isWeekend(offset: chosenDay, today: today) ? 9 * 60 : 17 * 60,
                    duration: duration,
                    dayOffset: chosenDay,
                    schedule: schedule,
                    sessions: sessions,
                    routine: routine,
                    today: today
                )
            }

            let visual = PlanSubjects.visual(for: task.subject)
            let end = chosenStart + duration
            sessions.append(
                PlanSession(
                    id: "scheduled-\(task.id)",
                    taskId: task.id,
                    dayOffset: chosenDay,
                    startTime: PlanDateEngine.minutesToTime(chosenStart),
                    endTime: PlanDateEngine.minutesToTime(end),
                    durationMinutes: duration,
                    title: task.subject,
                    subtitle: task.title,
                    priority: task.priority,
                    deadline: task.deadline,
                    colorHex: visual.colorHex,
                    icon: visual.icon,
                    isDone: task.isDone
                )
            )
            cursors[chosenDay] = end + PlanMetrics.blockGapMinutes
        }

        return sessions.sorted { left, right in
            left.dayOffset == right.dayOffset ? left.startTime < right.startTime : left.dayOffset < right.dayOffset
        }
    }

    /// `nextAvailableMinute` (lignes 561-582) : décale le candidat de 15 minutes
    /// après chaque chevauchement, dans l'ordre des blocages.
    static func nextAvailableMinute(
        start: Int,
        duration: Int,
        dayOffset: Int,
        schedule: [PlanScheduleSlot],
        sessions: [PlanSession],
        routine: PlanRoutine,
        today: Date
    ) -> Int {
        var candidate = start
        let dayName = PlanDateEngine.dayName(offset: dayOffset, today: today)

        var blocked: [(start: Int, end: Int)] = []
        blocked += schedule
            .filter { $0.day == dayName }
            .map { (PlanDateEngine.timeToMinutes($0.startTime), PlanDateEngine.timeToMinutes($0.endTime)) }
        blocked += sessions
            .filter { $0.dayOffset == dayOffset }
            .map { (PlanDateEngine.timeToMinutes($0.startTime), PlanDateEngine.timeToMinutes($0.endTime)) }
        blocked.append((PlanDateEngine.timeToMinutes(routine.dinnerTime), PlanDateEngine.timeToMinutes(routine.dinnerTime) + routine.dinnerDurationMinutes))
        blocked.append((PlanDateEngine.timeToMinutes(routine.showerTime), PlanDateEngine.timeToMinutes(routine.showerTime) + routine.showerDurationMinutes))
        blocked.append((PlanDateEngine.timeToMinutes(routine.bedtime), 24 * 60))

        for interval in blocked.sorted(by: { $0.start < $1.start }) where candidate < interval.end && candidate + duration > interval.start {
            candidate = interval.end + PlanMetrics.blockGapMinutes
        }
        return candidate
    }

    /// `deadlineOffset` (lignes 584-603), augmenté du report local
    /// (`postponedDays`), borné aux jours du programme.
    static func deadlineOffset(
        _ deadline: String?,
        dayCount: Int,
        postponedDays: Int = 0,
        today: Date = Date()
    ) -> Int {
        guard let deadline, !deadline.isEmpty else {
            return clamp(min(6, dayCount - 1) + postponedDays, dayCount: dayCount)
        }

        let normalized = PlanTaskAnalyzer.normalize(deadline)
        var base: Int

        if normalized.contains("aujourd'hui") || normalized.contains("ce soir") {
            base = 0
        } else if normalized.contains("apres-demain") {
            base = 2
        } else if normalized.contains("demain") {
            base = 1
        } else if let numeric = numericOffset(normalized, dayCount: dayCount, today: today) {
            base = numeric
        } else if let weekday = weekdayOffset(normalized, today: today) {
            base = weekday
        } else {
            base = min(6, dayCount - 1)
        }

        return clamp(base + postponedDays, dayCount: dayCount)
    }

    /// `/(\d{1,2})\/(\d{1,2})(?:\/(\d{2,4}))?/` (ligne 590).
    private static func numericOffset(_ normalized: String, dayCount: Int, today: Date) -> Int? {
        let pattern = "(\\d{1,2})/(\\d{1,2})(?:/(\\d{2,4}))?"
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: normalized, options: [], range: NSRange(normalized.startIndex..<normalized.endIndex, in: normalized)) else {
            return nil
        }
        func group(_ index: Int) -> String? {
            guard let range = Range(match.range(at: index), in: normalized) else { return nil }
            return String(normalized[range])
        }
        guard let dayText = group(1), let monthText = group(2),
              let day = Int(dayText), let month = Int(monthText) else { return nil }

        let calendar = PlanDateEngine.gregorian
        let noon = PlanDateEngine.noonDate(for: today)
        let suppliedYear = group(3).flatMap { Int($0) } ?? calendar.component(.year, from: noon)
        let fullYear = suppliedYear < 100 ? 2000 + suppliedYear : suppliedYear
        guard var target = calendar.date(from: DateComponents(year: fullYear, month: month, day: day, hour: 12)) else { return nil }
        if group(3) == nil && target < noon {
            target = calendar.date(from: DateComponents(year: fullYear + 1, month: month, day: day, hour: 12)) ?? target
        }
        let days = Int((target.timeIntervalSince(noon) / 86_400).rounded())
        return max(0, min(dayCount - 1, days))
    }

    /// `['dimanche', 'lundi', …].findIndex` (ligne 600) : prochain jour nommé.
    private static func weekdayOffset(_ normalized: String, today: Date) -> Int? {
        let names = ["dimanche", "lundi", "mardi", "mercredi", "jeudi", "vendredi", "samedi"]
        guard let target = names.firstIndex(where: { normalized.contains($0) }) else { return nil }
        return (target - PlanDateEngine.jsWeekday(today) + 7) % 7
    }

    private static func clamp(_ value: Int, dayCount: Int) -> Int {
        max(0, min(dayCount - 1, value))
    }
}
