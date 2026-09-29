//
//  RankingSubjectXp.swift
//  Duello
//
//  XP gagnés en travaillant une matière, semaine par semaine.
//
//  Fichier source Expo porté (constantes, libellés et seuils repris mot pour mot) :
//    - src/utils/subjectXp.ts
//        `XP_ACTIVITIES`, `XP_BASE_BY_DIFFICULTY`, `XP_REFERENCE_MINUTES`,
//        `XP_FASTEST_FACTOR`, `XP_SLOWEST_FACTOR`, `XP_FLAWLESS_BONUS`,
//        `XP_ANNALIE_MULTIPLIER`, `RETAINED_WEEKS`, `shiftedWeekKey`,
//        `speedFactor`, `computeSubjectXp`, `weeklySubjectXp`,
//        `weeklySubjectItemCount`, `buildWeeklySubjectXp`, `formatWeekRange`.
//
//  La clé de semaine (`weekKey`) est déjà portée par `WeeklyXP.weekKey`
//  (`Models.swift:388`) : elle n'est pas rejouée ici. La persistance du journal
//  (`loadSubjectXp`/`recordSubjectXp`) vit dans `RankingSubjectXpStore.swift`.
//
//  Cible : iOS 16, aucune dépendance externe.
//
import Foundation

/// `XP_ACTIVITIES` : sujets classés. Un défi se joue déjà en Elo, il ne
/// rapporte pas d'XP ici.
let rankingXpActivities: [CollTrainingActivity] = [.exercice, .colle, .annale]

/// Barème et calcul des XP d'une matière (`utils/subjectXp.ts`).
enum RankingSubjectXp {

    // MARK: - Constantes (mêmes seuils que la source)

    /// `XP_BASE_BY_DIFFICULTY` : points d'un sujet réussi, avant temps et
    /// sans-faute. Le palier 6 (sommet éditorial) garde le barème du 5.
    static let baseByDifficulty: [Int: Int] = [1: 50, 2: 100, 3: 175, 4: 275, 5: 400, 6: 400]

    /// `XP_REFERENCE_MINUTES` : durée attendue pour un sujet de ce palier.
    static let referenceMinutes: [Int: Int] = [1: 5, 2: 10, 3: 20, 4: 35, 5: 50, 6: 50]

    /// `XP_FASTEST_FACTOR` / `XP_SLOWEST_FACTOR` : bornes du facteur de rapidité.
    static let fastestFactor = 1.4
    static let slowestFactor = 0.6

    /// `XP_FLAWLESS_BONUS` : supplément d'un sujet réussi sans réponse fausse.
    static let flawlessBonus = 0.25

    /// `XP_ANNALIE_MULTIPLIER` : une annale réussie compte triple.
    static let annaleMultiplier: Double = 3

    /// `RETAINED_WEEKS` : semaines conservées dans le journal.
    static let retainedWeeks = 8

    // MARK: - Calcul d'un sujet

    /// `SubjectXpInput` : ce qui détermine les points d'un sujet.
    struct Input {
        var difficulty: Int
        var outcome: ItemOutcome
        /// Temps réellement passé, `nil` lorsqu'il n'a pas été mesuré.
        var minutes: Double?
        /// Vrai lorsque aucune réponse fausse n'a été soumise.
        var flawless: Bool
        /// Type de sujet : une annale réussie rapporte trois fois plus.
        var activity: CollTrainingActivity = .exercice
    }

    /// `computeSubjectXp` : points rapportés par un sujet, arrondis à l'unité,
    /// jamais moins d'un point. Un sujet non entièrement réussi rend zéro.
    static func computeSubjectXp(_ input: Input) -> Int {
        guard input.outcome == .success else { return 0 }
        let base = Double(baseByDifficulty[input.difficulty] ?? baseByDifficulty[3] ?? 175)
        let bonus = input.flawless ? 1 + flawlessBonus : 1
        let product = base
            * speedFactor(minutes: input.minutes, difficulty: input.difficulty)
            * bonus
            * multiplier(for: input.activity)
        return max(1, Int(product.rounded()))
    }

    /// `speedFactor` : deux fois plus vite que la durée attendue vaut le
    /// maximum, deux fois plus lent le minimum, l'intervalle parcouru
    /// continûment ; un temps non mesuré ne module rien.
    static func speedFactor(minutes: Double?, difficulty: Int) -> Double {
        guard let minutes, minutes.isFinite, minutes >= 0 else { return 1 }
        let reference = Double(referenceMinutes[difficulty] ?? 20)
        if minutes <= reference / 2 { return fastestFactor }
        if minutes >= reference * 2 { return slowestFactor }
        if minutes <= reference {
            let progress = (minutes - reference / 2) / (reference / 2)
            return fastestFactor - progress * (fastestFactor - 1)
        }
        let progress = (minutes - reference) / reference
        return 1 - progress * (1 - slowestFactor)
    }

    /// `XP_MULTIPLIER_BY_ACTIVITY` : seule l'annale, qui couvre tout un sujet
    /// d'épreuve, bénéficie d'un multiplicateur.
    static func multiplier(for activity: CollTrainingActivity) -> Double {
        activity == .annale ? annaleMultiplier : 1
    }

    // MARK: - Agrégats hebdomadaires

    /// `weeklySubjectXp` : points gagnés dans une matière une semaine donnée.
    static func weeklySubjectXp(_ log: SubjectXpLog, subject: String, week: String) -> Int {
        let wanted = subject.trimmingCharacters(in: .whitespacesAndNewlines)
        return log.awards.reduce(0) { total, award in
            award.subject == wanted && award.week == week ? total + award.xp : total
        }
    }

    /// `weeklySubjectItemCount` : sujets comptés dans une matière une semaine.
    static func weeklySubjectItemCount(_ log: SubjectXpLog, subject: String, week: String) -> Int {
        let wanted = subject.trimmingCharacters(in: .whitespacesAndNewlines)
        return log.awards.filter { $0.subject == wanted && $0.week == week }.count
    }

    /// `buildWeeklySubjectXp` : totaux publiables, la semaine la plus récente
    /// en tête ; seules les semaines conservées sortent.
    static func buildWeeklySubjectXp(_ log: SubjectXpLog, at date: Date = Date()) -> [WeeklySubjectXp] {
        let floor = retentionFloor(at: date)
        var totals: [String: WeeklySubjectXp] = [:]
        for award in log.awards {
            if award.week < floor { continue }
            let key = "\(award.week)::\(award.subject)"
            if var existing = totals[key] {
                existing.xp += award.xp
                totals[key] = existing
            } else {
                totals[key] = WeeklySubjectXp(subject: award.subject, week: award.week, xp: award.xp)
            }
        }
        return totals.values.sorted { first, second in
            if first.week != second.week { return first.week > second.week }
            if first.xp != second.xp { return first.xp > second.xp }
            return first.subject.localizedCompare(second.subject) == .orderedAscending
        }
    }

    // MARK: - Semaines

    /// `shiftedWeekKey` : lundi de la semaine ouverte `steps` semaines avant
    /// celle de `date`, au format AAAA-MM-JJ.
    static func shiftedWeekKey(at date: Date = Date(), steps: Int) -> String {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        // getDay() côté JS : dimanche = 0, qui termine la semaine.
        let weekday = calendar.component(.weekday, from: start)
        let daysSinceMonday = (weekday + 5) % 7
        let monday = calendar.date(
            byAdding: .day,
            value: -daysSinceMonday + steps * 7,
            to: start
        ) ?? start
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: monday)
    }

    /// `retentionFloor` : première semaine conservée, bornes incluses.
    static func retentionFloor(at date: Date = Date()) -> String {
        shiftedWeekKey(at: date, steps: -(retainedWeeks - 1))
    }

    /// `formatWeekRange` : semaine en mots, « du 28 juillet au 3 août ».
    static func formatWeekRange(_ week: String, at date: Date = Date()) -> String {
        let months = [
            "janvier", "février", "mars", "avril", "mai", "juin",
            "juillet", "août", "septembre", "octobre", "novembre", "décembre",
        ]
        let calendar = Calendar.current
        let start = parseWeek(week) ?? date
        let end = calendar.date(byAdding: .day, value: 6, to: start) ?? start
        let startMonth = calendar.component(.month, from: start)
        let endMonth = calendar.component(.month, from: end)

        func label(_ day: Date, withMonth: Bool) -> String {
            let value = calendar.component(.day, from: day)
            guard withMonth else { return "\(value)" }
            let month = calendar.component(.month, from: day)
            return "\(value) \(months[month - 1])"
        }

        return "du \(label(start, withMonth: startMonth != endMonth)) au \(label(end, withMonth: true))"
    }

    /// Midi du jour « AAAA-MM-JJ » : l'heure évite tout glissement de fuseau.
    private static func parseWeek(_ week: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        guard let parsed = formatter.date(from: week) else { return nil }
        var components = Calendar.current.dateComponents([.year, .month, .day], from: parsed)
        components.hour = 12
        return Calendar.current.date(from: components)
    }
}

/// Total d'une semaine, matière par matière : c'est ce que le profil publie
/// (`WeeklySubjectXp`).
struct WeeklySubjectXp: Equatable, Codable {
    var subject: String
    var week: String
    var xp: Int
}
