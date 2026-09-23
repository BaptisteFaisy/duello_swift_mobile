import Foundation

// MARK: - Lecture

/// Lectures et agrégats de `ProgressStore` : avancement item par item, bilans
/// d'entraînement, défis, cote, séries de jours et formatage. Extraits de
/// `ProgressStore.swift` pour respecter la limite de 10 fonctions par fichier.
extension ProgressStore {

    /// Fraction de remplissage de la barre d'avancement d'un item, d'après son
    /// meilleur résultat (voir `progressFraction` d'`exerciseProgress.ts`) :
    /// 0,25 après un échec, 0,6 après une réussite partielle, 1 une fois réussi.
    func progressFraction(for itemId: String) -> Double {
        guard let best = items[itemId]?.bestOutcome else { return 0 }
        switch best {
        case .fail: return 0.25
        case .partial: return 0.6
        case .success: return 1
        }
    }

    /// Agrège l'entraînement d'une matière sur les items de sa banque servie.
    /// Seuls les items disponibles sont comptés, comme `trainingStats` (Expo).
    func trainingStat(forItemIds itemIds: [String]) -> TrainingStat {
        var stat = TrainingStat()
        stat.total = itemIds.count
        for itemId in itemIds {
            guard let item = items[itemId] else { continue }
            if item.attempts > 0 {
                stat.attempted += 1
                stat.attempts += item.attempts
            }
            if item.bestOutcome == .success {
                stat.mastered += 1
            }
        }
        return stat
    }

    /// Défis joués et gagnés dans une matière.
    func duelStat(for subject: String) -> DuelStat {
        duels[subject] ?? DuelStat()
    }

    /// Cote d'une matière : 1100 tant qu'aucun défi ne l'a déplacée
    /// (`getSubjectElo` d'`subjectElo.ts`).
    func subjectElo(for subject: String) -> Int {
        subjectElos[subject] ?? Self.initialElo
    }

    /// Nombre de journées travaillées (`activity.activeDays.length`).
    func activeDayCount() -> Int {
        activeDays.count
    }

    /// Jours travaillés consécutifs se terminant aujourd'hui ou, à défaut, hier
    /// (`currentStreak` d'`activity.ts`) : 0 quand ni aujourd'hui ni hier ne
    /// sont actifs.
    func currentStreak(at date: Date = Date()) -> Int {
        guard !activeDays.isEmpty else { return 0 }

        let days = Set(activeDays)
        let calendar = Calendar.current
        // Midi, pour qu'un changement d'heure ne fasse pas basculer le jour.
        var cursor = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: date) ?? date

        // Une série reste vivante tant que la journée en cours n'est pas terminée.
        if !days.contains(Self.dayKey(at: cursor)) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: cursor) else {
                return 0
            }
            cursor = yesterday
            if !days.contains(Self.dayKey(at: cursor)) { return 0 }
        }

        var streak = 0
        while days.contains(Self.dayKey(at: cursor)) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else {
                break
            }
            cursor = previous
        }
        return streak
    }

    /// Temps d'entraînement cumulé, formaté (« 3 h 20 »).
    func formattedTrainingTime() -> String {
        Self.formatTrainingTime(minutes: exerciseMinutes)
    }

    /// Minutes formatées pour l'affichage, reprises de `formatTrainingTime` :
    /// « 45 min » sous l'heure, « 3 h » pile, « 3 h 20 » au-delà.
    static func formatTrainingTime(minutes: Int) -> String {
        let safeMinutes = max(0, minutes)
        guard safeMinutes >= 60 else { return "\(safeMinutes) min" }

        let hours = safeMinutes / 60
        let rest = safeMinutes % 60
        guard rest > 0 else { return "\(hours) h" }
        return "\(hours) h \(String(format: "%02d", rest))"
    }

    // MARK: Jour d'activité

    /// Jour local au format `AAAA-MM-JJ`, pour compter des journées et non des
    /// instants (voir `dayKey` d'`activity.ts`).
    static func dayKey(at date: Date = Date()) -> String {
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            parts.year ?? 0,
            parts.month ?? 0,
            parts.day ?? 0
        )
    }
}
