//
//  RankingWarmup.swift
//  Duello
//
//  Port de src/utils/rankingWarmup.ts (RN) — préchauffage des deux classements
//  avant leur première ouverture.
//
//  Les écrans rendent leur liste dès qu'une copie en cache existe : lancer les
//  deux requêtes pendant une accalmie du premier plan rend l'ouverture du
//  classement immédiate au lieu d'attendre le réseau. L'échec d'un
//  préchargement reste silencieux, l'écran relançant sa propre requête.
//
//  Notes datées (2026-09-24) — limites assumées :
//  - `prefetchRankingsForProfile` évalue aussi l'écran paresseux
//    (`import('../screens/LeaderboardScreen')`) dans la même accalmie. En
//    Swift natif, `LeaderboardScreen` est déjà compilé et instancié par la
//    navigation : il n'y a pas de module paresseux à évaluer, seule la partie
//    réseau est portée.
//  - La cohorte Elo est désormais portée (`RankingEloCohort.swift`,
//    `eloLeaderboardCohortForProfile`) : `DuelloAPI.subjectLeaderboard` accepte
//    un paramètre `cohort` et le préchauffage le transmet, comme `subjectLeaderboard.ts`.
//  - `socialApi.ts` (caches mémoire + persistance au fil des réponses) est
//    porté par `RankingSnapshotCache` : la réponse validée alimente la mémoire
//    puis le disque (`save`), les écrans relisant avant le réseau.
//
//  Cible : iOS 16.
//
import Foundation

/// Matière classée par les deux classements pour le moment (`RANKING_SUBJECT`).
let rankingWarmupSubject = "Mathématiques"

/// Profil académique minimal pour choisir la cohorte du classement Elo
/// (`RankingAcademicProfile`).
struct RankingWarmupProfile {
    var track: String?
    var year: String?
    var specialty: String?
    var currentTrack: String?

    init(
        track: String? = nil,
        year: String? = nil,
        specialty: String? = nil,
        currentTrack: String? = nil
    ) {
        self.track = track
        self.year = year
        self.specialty = specialty
        self.currentTrack = currentTrack
    }
}

// MARK: - Coutures

/// Cohorte Elo d'un profil (`eloLeaderboardCohortForProfile`).
protocol RankingsEloCohortResolving {
    func cohort(for profile: RankingWarmupProfile) -> String?
}

/// Implémentation par défaut : la cohorte du profil, portée de
/// `src/utils/subjectLeaderboard.ts` (`eloLeaderboardCohortForProfile`).
struct RankingEloCohortResolver: RankingsEloCohortResolving {
    func cohort(for profile: RankingWarmupProfile) -> String? {
        eloLeaderboardCohortForProfile(
            EloLeaderboardAcademicProfile(
                track: profile.track,
                year: profile.year,
                specialty: profile.specialty,
                currentTrack: profile.currentTrack
            )
        )
    }
}

/// Service de classements du préchauffage (couture vers `socialApi.ts`).
protocol RankingsWarmupServing {
    func prefetchSubjectLeaderboard(
        subject: String,
        profile: RankingWarmupProfile
    ) async throws -> [LeaderboardEntry]

    func prefetchWeeklyXpLeaderboard(
        subject: String,
        week: String
    ) async throws -> [LeaderboardEntry]
}

/// Implémentation par défaut : appelle `DuelloAPI` et persiste la réponse
/// comme le fait `socialApi.ts` côté RN (`saveRankingsSnapshot`).
struct DuelloAPIRankingsWarmupService: RankingsWarmupServing {
    var token: String?
    var cohortResolver: RankingsEloCohortResolving = RankingEloCohortResolver()
    var cache: RankingsSnapshotCache = .shared

    func prefetchSubjectLeaderboard(
        subject: String,
        profile: RankingWarmupProfile
    ) async throws -> [LeaderboardEntry] {
        let cohort = cohortResolver.cohort(for: profile)
        let entries = try await DuelloAPI.subjectLeaderboard(
            subject: subject,
            cohort: cohort,
            token: token
        )
        let key = rankingsSubjectLeaderboardCacheKey(
            subject: subject,
            cohort: cohort
        )
        cache.save(.subjectLeaderboard, key: key, entries: entries)
        return entries
    }

    func prefetchWeeklyXpLeaderboard(
        subject: String,
        week: String
    ) async throws -> [LeaderboardEntry] {
        let entries = try await DuelloAPI.weeklyXpLeaderboard(
            subject: subject,
            week: week,
            token: token
        )
        let key = rankingsWeeklyXpLeaderboardCacheKey(subject: subject, week: week)
        cache.save(.weeklyXpLeaderboard, key: key, entries: entries)
        return entries
    }
}

// MARK: - Clés de cache (`socialApi.ts`)

/// Clé de cache d'un classement de matière (`subjectLeaderboardCacheKey`) :
/// matière et cohorte repliées en minuscules, jointes par `|`.
func rankingsSubjectLeaderboardCacheKey(subject: String, cohort: String?) -> String {
    [subject, cohort ?? ""]
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        .joined(separator: "|")
}

/// Clé de cache d'un classement hebdo (`weeklyXpLeaderboardCacheKey`) :
/// matière et semaine repliées en minuscules, jointes par `|`.
func rankingsWeeklyXpLeaderboardCacheKey(subject: String, week: String) -> String {
    [subject, week]
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        .joined(separator: "|")
}

// MARK: - Préchauffage

/// Remplit les caches des deux classements avant leur première ouverture
/// (`prefetchRankingsForProfile`). Renvoie `true` si les deux requêtes ont
/// abouti, `false` sinon (échec silencieux côté écran).
@discardableResult
func prefetchRankingsForProfile(
    _ profile: RankingWarmupProfile,
    service: RankingsWarmupServing
) async -> Bool {
    await prefetchRankingsDataForProfile(profile, service: service)
}

/// Lance seulement les deux requêtes réseau, sans évaluer d'écran paresseux
/// (`prefetchRankingsDataForProfile`). L'échec reste journalisé, l'écran
/// relançant sa propre requête.
@discardableResult
func prefetchRankingsDataForProfile(
    _ profile: RankingWarmupProfile,
    service: RankingsWarmupServing
) async -> Bool {
    do {
        async let subject = service.prefetchSubjectLeaderboard(
            subject: rankingWarmupSubject,
            profile: profile
        )
        async let weekly = service.prefetchWeeklyXpLeaderboard(
            subject: rankingWarmupSubject,
            week: WeeklyXP.weekKey()
        )
        _ = try await (subject, weekly)
        return true
    } catch {
        logRankingWarmupFailure(error)
        return false
    }
}

/// Journal d'un préchauffage impossible (`console.log('préchauffage des
/// classements impossible :', error)`).
private func logRankingWarmupFailure(_ error: Error) {
    print("préchauffage des classements impossible : \(error)")
}
