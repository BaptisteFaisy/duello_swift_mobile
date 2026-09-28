//
//  ReportLocalSnapshot.swift
//  Duello
//
//  Extrait de `ReportPublicProfileSeams.swift` (ratchet ≤ 500 l./≤ 10 fonct.) :
//  lecture et reconstruction de l'instantané public local
//  (`loadPublicProfileSnapshot` de `src/utils/publicProfileSnapshot.ts`).
//
//  Détaché : `ReportPublicProfileSnapshotProviding`, `ReportLocalProgress`,
//  `ReportLocalEloEntry`, `ReportLocalXpEntry`, `ReportLocalSnapshotProvider`
//  (alias `ReportUnwiredSnapshotProvider`) et `ReportLocalSnapshot`.
//
//  Cible : iOS 16, aucune dépendance externe.
//
import Foundation

// MARK: - Lecture de l'instantané

/// `loadPublicProfileSnapshot` : relit toutes les sources du compte avant une
/// publication distante. Le port Swift lit l'instantané local persisté par
/// `ProgressStore` (`ReportLocalProgress`) et le profil passé par le publieur.
protocol ReportPublicProfileSnapshotProviding {
    func load(
        accountId: String,
        profile: UserProfile,
        registeredAt: Double
    ) async throws -> ReportPublicProfileSnapshot
}

/// Photographie locale des données publiques, relue depuis le stockage de
/// `ProgressStore` (`UserDefaults.standard`, clé `com.duello.ios.progress` —
/// `ProgressStore.swift:152,201`).
///
/// Pourquoi le stockage et pas le store : `ProgressStore` n'a pas d'instance
/// partagée (créé en `@StateObject` dans `DuelloApp`) et le publieur est monté
/// par `MainTabView` (fichier partagé, non éditable ici) qui ne lui injecte
/// aucune dépendance. Lire le JSON persisté est le seul accès honnête aux
/// données locales sans modifier ces fichiers partagés ; le décodage est
/// tolérant (un champ absent vaut zéro, comme `ProgressSnapshot`).
struct ReportLocalProgress: Decodable {
    var totalXp: Double = 0
    var competitionProgramPercent: Int = 0
    var exercisesCompleted: Int = 0
    var challengesCompleted: Int = 0
    var exerciseMinutes: Int = 0
    var activeDays: [String] = []
    var subjectElos: [String: Int] = [:]
    var eloHistory: [ReportLocalEloEntry] = []
    var xpHistory: [ReportLocalXpEntry] = []

    /// Clé de `ProgressStore.storageKey` (`ProgressStore.swift:152`).
    static let storageKey = "com.duello.ios.progress"

    enum CodingKeys: String, CodingKey {
        case totalXp, competitionProgramPercent, exercisesCompleted
        case challengesCompleted, exerciseMinutes, activeDays, subjectElos
        case eloHistory, xpHistory
    }

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        totalXp = max(0, (try? c.decode(Double.self, forKey: .totalXp)) ?? 0)
        competitionProgramPercent = min(
            100,
            max(0, (try? c.decode(Int.self, forKey: .competitionProgramPercent)) ?? 0)
        )
        exercisesCompleted = max(0, (try? c.decode(Int.self, forKey: .exercisesCompleted)) ?? 0)
        challengesCompleted = max(0, (try? c.decode(Int.self, forKey: .challengesCompleted)) ?? 0)
        exerciseMinutes = max(0, (try? c.decode(Int.self, forKey: .exerciseMinutes)) ?? 0)
        activeDays = (try? c.decode([String].self, forKey: .activeDays)) ?? []
        subjectElos = (try? c.decode([String: Int].self, forKey: .subjectElos)) ?? [:]
        eloHistory = (try? c.decode([ReportLocalEloEntry].self, forKey: .eloHistory)) ?? []
        xpHistory = (try? c.decode([ReportLocalXpEntry].self, forKey: .xpHistory)) ?? []
    }

    /// Relit l'instantané persisté ; un stockage vide rend une photographie à
    /// zéro (jamais une erreur : un compte neuf n'a rien à publier de plus).
    static func read() -> ReportLocalProgress {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let snapshot = try? JSONDecoder().decode(ReportLocalProgress.self, from: data)
        else { return ReportLocalProgress() }
        return snapshot
    }
}

/// `history` de `useSubjectElo` : cote d'une matière après un défi.
struct ReportLocalEloEntry: Decodable {
    var subject: String = ""
    var elo: Int = 0
    var at: Double = 0

    enum CodingKeys: String, CodingKey { case subject, elo, at }

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        subject = (try? c.decode(String.self, forKey: .subject)) ?? ""
        elo = (try? c.decode(Int.self, forKey: .elo)) ?? 0
        at = (try? c.decode(Double.self, forKey: .at)) ?? 0
    }
}

/// `activity.history` : gain d'XP horodaté.
struct ReportLocalXpEntry: Decodable {
    var xp: Double = 0
    var at: Double = 0

    enum CodingKeys: String, CodingKey { case xp, at }

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        xp = (try? c.decode(Double.self, forKey: .xp)) ?? 0
        at = (try? c.decode(Double.self, forKey: .at)) ?? 0
    }
}

/// Implémentation réelle : reconstruit l'instantané public depuis les données
/// locales (`buildPublicProfileSnapshot` de `utils/publicProfileSnapshot.ts`).
///
/// Repli documenté : faute de store de notes, de tâches de programme et de
/// sessions d'activité portés côté iOS, `performance.average/trend/gradeCount`
/// valent le repli (`—`, `—`, 0) et `timeSeries` / `subjectSuccesses` /
/// `veryHardExerciseSuccessIds` sont vides — le reste (XP, Elo, activité,
/// complétion, série, série d'XP) est publié réellement.
struct ReportLocalSnapshotProvider: ReportPublicProfileSnapshotProviding {
    func load(
        accountId: String,
        profile: UserProfile,
        registeredAt: Double
    ) async throws -> ReportPublicProfileSnapshot {
        let local = ReportLocalProgress.read()
        return ReportPublicProfileSnapshot(
            performance: ReportLocalSnapshot.performance(local),
            details: ReportLocalSnapshot.details(
                profile: profile,
                local: local,
                registeredAt: registeredAt
            ),
            xpAwards: [],
            premium: false
        )
    }
}

/// Nom conservé : le publieur (fichier partagé `ReportPublicProfilePublisher.swift:84`)
/// instancie encore `ReportUnwiredSnapshotProvider()`. Cette couture n'est plus
/// « non branchée » : elle lit désormais les stores locaux.
typealias ReportUnwiredSnapshotProvider = ReportLocalSnapshotProvider

/// Calculs de `buildPublicProfileSnapshot` (`utils/publicProfileSnapshot.ts`,
/// `utils/subjectElo.ts`, `utils/xpSeries.ts`).
enum ReportLocalSnapshot {

    /// `performance` : XP, série et complétion locales ; moyenne et tendance de
    /// notes restent au repli (aucun store de notes porté).
    static func performance(_ local: ReportLocalProgress) -> ReportPublicPerformance {
        ReportPublicPerformance(
            average: "—",
            trend: "—",
            gradeCount: 0,
            completion: Double(local.competitionProgramPercent),
            streak: currentStreak(local.activeDays),
            xp: local.totalXp
        )
    }

    /// `details` : identité, activité, séries d'Elo (globale + matières) et
    /// série d'XP. `timeSeries`, `subjectSuccesses` et `veryHardExerciseSuccessIds`
    /// sont vides (sources non portées, cf. `ReportLocalSnapshotProvider`).
    static func details(
        profile: UserProfile,
        local: ReportLocalProgress,
        registeredAt: Double
    ) -> ReportPublicProfileDetails {
        let subjects = historySubjects(local.eloHistory)
        let overallPoints = eloSeries(
            history: local.eloHistory,
            subject: nil,
            registeredAt: registeredAt
        )
        let elos = Array(local.subjectElos.values)
        let average = elos.isEmpty
            ? nil
            : Int((Double(elos.reduce(0, +)) / Double(elos.count)).rounded())
        let overall = ReportPublicEloSeries(
            label: subjects.count == 1 ? subjects[0] : "Moyenne des matières",
            current: overallPoints.isEmpty ? nil : average,
            points: overallPoints
        )
        let subjectSeries = subjects.map { subject in
            ReportPublicEloSeries(
                label: subject,
                current: local.subjectElos[subject] ?? ProgressStore.initialElo,
                points: eloSeries(
                    history: local.eloHistory,
                    subject: subject,
                    registeredAt: registeredAt
                )
            )
        }
        let xpPoints = ChartXpSeries.build(
            history: local.xpHistory.map { ChartXpEntry(xp: $0.xp, at: $0.at) },
            total: local.totalXp,
            registeredAt: registeredAt
        ).map { ReportPublicXpPoint(xp: $0.xp, at: $0.at) }
        return ReportPublicProfileDetails(
            currentTrack: profile.followedTrack,
            specialty: LoginScrProviderReuse.accountAcademicOptionLabel(
                track: profile.track,
                currentOption: profile.academicPath?.currentOption ?? profile.specialty,
                legacySpecialty: profile.specialty
            ),
            personalGoal: profile.personalGoal,
            activity: ReportPublicActivity(
                challengesCompleted: local.challengesCompleted,
                exercisesCompleted: local.exercisesCompleted,
                exerciseMinutes: local.exerciseMinutes
            ),
            elo: ReportPublicEloDetails(overall: overall, subjects: subjectSeries),
            timeSeries: ReportPublicTimeSeries(day: [], week: [], month: []),
            subjectSuccesses: [],
            veryHardExerciseSuccessIds: [],
            xpSeries: xpPoints
        )
    }

    /// `historySubjects` : matières jouées, dans leur ordre d'apparition.
    static func historySubjects(_ history: [ReportLocalEloEntry]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for entry in history where !entry.subject.isEmpty && !seen.contains(entry.subject) {
            seen.insert(entry.subject)
            result.append(entry.subject)
        }
        return result
    }

    /// `buildEloSeries` : une matière (`subject`) ou la moyenne de toutes les
    /// matières jouées, départ à `INITIAL_SUBJECT_ELO` à l'inscription.
    static func eloSeries(
        history: [ReportLocalEloEntry],
        subject: String?,
        registeredAt: Double
    ) -> [ReportPublicEloPoint] {
        let startAt = registeredAt > 0 ? registeredAt : 0
        let played = (subject == nil ? history : history.filter { $0.subject == subject })
            .filter { startAt == 0 || $0.at >= startAt }
            .sorted { $0.at < $1.at }
        guard !played.isEmpty else {
            return startAt > 0 ? [ReportPublicEloPoint(elo: ProgressStore.initialElo, at: startAt)] : []
        }
        var latest: [String: Int] = [:]
        var points: [ReportPublicEloPoint] = []
        for entry in played {
            latest[entry.subject] = entry.elo
            let average = Double(latest.values.reduce(0, +)) / Double(latest.count)
            points.append(ReportPublicEloPoint(elo: Int(average.rounded()), at: entry.at))
        }
        return [ReportPublicEloPoint(elo: ProgressStore.initialElo, at: startAt)] + points
    }

    /// `currentStreak` : jours travaillés consécutifs jusqu'à aujourd'hui (ou
    /// hier), rejoué ici pour éviter de dépendre d'une instance de `ProgressStore`.
    static func currentStreak(_ activeDays: [String], at date: Date = Date()) -> Int {
        guard !activeDays.isEmpty else { return 0 }
        let days = Set(activeDays)
        let calendar = Calendar.current
        var cursor = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: date) ?? date
        if !days.contains(ProgressStore.dayKey(at: cursor)) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: cursor) else { return 0 }
            cursor = yesterday
            if !days.contains(ProgressStore.dayKey(at: cursor)) { return 0 }
        }
        var streak = 0
        while days.contains(ProgressStore.dayKey(at: cursor)) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return streak
    }
}
