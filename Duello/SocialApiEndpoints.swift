//
//  SocialApiEndpoints.swift
//  Duello
//
//  Lot T06 (vague 4 « couche transverse ») — TR-06 : endpoints sociaux absents
//  de `DuelloAPI` (abonnements, classement d'exercice, défis de classe
//  planifiés).
//
//  Fichiers source Expo portés (routes, corps et règles repris mot pour mot) :
//    - src/utils/socialApi.ts (`publishFollowedIds` → `PUT /follows`,
//      `recordExerciseResult` → `POST /exercise-leaderboard`,
//      `createScheduledClassChallenge` → `POST /scheduled-class-challenges`,
//      `fetchScheduledClassChallenges` → `GET /scheduled-class-challenges`) ;
//    - src/utils/followPublicationQueue.ts (`createFollowPublicationQueue`) ;
//    - src/utils/exerciseLeaderboard.ts (`ExerciseResult`,
//      `parseExerciseResult`, `scoreImprovementPercentage`).
//
//  L'annuaire social n'est pas exposé par `DuelloAPI` : ce client local réutilise
//  le relais (`DuelloAPI.request`), comme `ExGLeaderboardClient` et
//  `ReportSafetyAPI`. `DuelloAPI.swift` n'est pas modifié.
//
//  Cible : iOS 16, aucune API iOS 17.
//
import Foundation

// MARK: - Défi de classe planifié

/// `ScheduledClassChallenge` de `utils/socialApi.ts` : un défi de classe
/// programmé, tel que le serveur le publie.
struct ScheduledClassChallenge: Identifiable, Equatable {
    var id: String
    var prepName: String
    var className: String
    var date: String
    var displayDate: String
    var time: String
    var accessCode: String
    var organizerId: String
    var subject: String
    var durationMinutes: Double
    var createdAt: Double
    var updatedAt: Double

    /// `parseScheduledClassChallenge` : rejette tout champ absent ou d'un type
    /// inattendu, plutôt que de deviner.
    static func parse(_ value: Any?) -> ScheduledClassChallenge? {
        guard let candidate = value as? [String: Any],
              let id = candidate["id"] as? String,
              let prepName = candidate["prepName"] as? String,
              let className = candidate["className"] as? String,
              let date = candidate["date"] as? String,
              let displayDate = candidate["displayDate"] as? String,
              let time = candidate["time"] as? String,
              let accessCode = candidate["accessCode"] as? String,
              let organizerId = candidate["organizerId"] as? String,
              let subject = candidate["subject"] as? String,
              let durationMinutes = candidate["durationMinutes"] as? Double,
              let createdAt = candidate["createdAt"] as? Double,
              let updatedAt = candidate["updatedAt"] as? Double
        else { return nil }
        return ScheduledClassChallenge(
            id: id, prepName: prepName, className: className, date: date,
            displayDate: displayDate, time: time, accessCode: accessCode,
            organizerId: organizerId, subject: subject,
            durationMinutes: durationMinutes, createdAt: createdAt, updatedAt: updatedAt
        )
    }
}

/// Corps de `POST /scheduled-class-challenges` (`createScheduledClassChallenge`).
struct ScheduledClassChallengeDraft: Encodable {
    var prepName: String
    var className: String
    var date: String
    var time: String
    var accessCode: String
    var organizerId: String
    var subject: String
    var durationMinutes: Double
}

// MARK: - Résultat de correction

/// `ExerciseResult` de `utils/exerciseLeaderboard.ts` : place obtenue par une
/// correction terminée.
struct ExGExerciseResult: Equatable {
    var score: Double
    var previousScore: Double?
    var improvementPercentage: Double?
    var attemptNumber: Int
    var bestScore: Double
    var rank: Int?

    /// `score` : nombre fini dans `[0, 20]`, arrondi au dixième, sinon `nil`.
    static func parseScore(_ value: Any?) -> Double? {
        guard let number = value as? Double, number.isFinite,
              number >= 0, number <= 20 else { return nil }
        return (number * 10).rounded() / 10
    }

    /// `scoreImprovementPercentage` : progression relative, `nil` sans note
    /// précédente, `100` depuis zéro vers une note non nulle.
    static func improvement(current: Double, previous: Double?) -> Double? {
        guard let previous else { return nil }
        if previous == 0 { return current == 0 ? 0 : 100 }
        return (((current - previous) / previous) * 100).rounded()
    }

    /// `parseExerciseResult` : `nil` quand un champ requis manque ou est illisible.
    static func parse(_ value: Any?) -> ExGExerciseResult? {
        guard let candidate = value as? [String: Any],
              let score = parseScore(candidate["score"]),
              let bestScore = parseScore(candidate["bestScore"]),
              let attempt = candidate["attemptNumber"] as? Int,
              attempt >= 1
        else { return nil }
        let previous: Double?
        if candidate["previousScore"] is NSNull {
            previous = nil
        } else if let raw = candidate["previousScore"] {
            guard let parsed = parseScore(raw) else { return nil }
            previous = parsed
        } else {
            previous = nil
        }
        let rank: Int?
        if let value = candidate["rank"] as? Int, value > 0 { rank = value } else { rank = nil }
        return ExGExerciseResult(
            score: score,
            previousScore: previous,
            improvementPercentage: improvement(current: score, previous: previous),
            attemptNumber: attempt,
            bestScore: bestScore,
            rank: rank
        )
    }
}

// MARK: - Client des endpoints sociaux

/// Endpoints sociaux absents de `DuelloAPI` (`utils/socialApi.ts`).
enum SocialApiEndpoints {

    /// `publishFollowedIds` : publie la **liste entière** des abonnements (et pas
    /// seulement le dernier ajout), sérialisée par compte.
    static func publishFollowedIds(
        email: String,
        followedIds: [String],
        token: String?,
        queue: SocialFollowPublicationQueue = .shared
    ) async throws {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let userId = DuelloAPI.publicProfileId(email: trimmed)
        let body = try DuelloAPI.encodeBody(FollowsBody(userId: userId, followedIds: followedIds))
        try await queue.enqueue(userId: userId, body: body) { payload in
            _ = try await DuelloAPI.request("follows", method: "PUT", token: token, body: payload)
        }
    }

    /// `recordExerciseResult` : enregistre une correction terminée et récupère la
    /// place de la meilleure note. Une réponse illisible lève, jamais ne devine.
    static func recordExerciseResult(
        subject: String,
        itemId: String,
        activity: ExGLeaderboardActivity,
        score: Double,
        submissionId: String,
        firstTry: Bool,
        token: String?
    ) async throws -> ExGExerciseResult {
        let input = ExerciseResultInput(
            subject: subject, itemId: itemId, activity: activity.rawValue,
            score: score, submissionId: submissionId, firstTry: firstTry
        )
        let body = try DuelloAPI.encodeBody(input)
        let data = try await DuelloAPI.request(
            "exercise-leaderboard", method: "POST", token: token, body: body
        )
        let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        guard let result = ExGExerciseResult.parse(object["result"]) else {
            throw DirectoryError(message: "Résultat de correction illisible")
        }
        return result
    }

    /// `createScheduledClassChallenge` : programme un défi de classe. Un défi
    /// illisible lève, jamais ne devine.
    static func createScheduledClassChallenge(
        _ challenge: ScheduledClassChallengeDraft,
        token: String?
    ) async throws -> ScheduledClassChallenge {
        let body = try DuelloAPI.encodeBody(challenge)
        let data = try await DuelloAPI.request(
            "scheduled-class-challenges", method: "POST", token: token, body: body
        )
        let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        guard let created = ScheduledClassChallenge.parse(object["challenge"]) else {
            throw DirectoryError(message: "Défi de classe illisible")
        }
        return created
    }

    /// `fetchScheduledClassChallenges` : défis planifiés d'une classe, ceux que
    /// le serveur sait relire (les entrées illisibles sont écartées).
    static func fetchScheduledClassChallenges(
        prepName: String,
        className: String,
        accessCode: String,
        token: String?
    ) async throws -> [ScheduledClassChallenge] {
        let data = try await DuelloAPI.request(
            "scheduled-class-challenges",
            token: token,
            query: [
                URLQueryItem(name: "prepName", value: prepName),
                URLQueryItem(name: "className", value: className),
                URLQueryItem(name: "accessCode", value: accessCode),
            ]
        )
        let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        guard let list = object["challenges"] as? [Any] else { return [] }
        return list.compactMap { ScheduledClassChallenge.parse($0) }
    }
}

/// Corps `{ userId, followedIds }` de `PUT /follows`.
private struct FollowsBody: Encodable {
    var userId: String
    var followedIds: [String]
}

/// Corps `{ subject, itemId, activity, score, submissionId, firstTry }`.
private struct ExerciseResultInput: Encodable {
    var subject: String
    var itemId: String
    var activity: String
    var score: Double
    var submissionId: String
    var firstTry: Bool
}

// MARK: - File de publication des abonnements

/// `createFollowPublicationQueue` : garantit que deux listes complètes
/// d'abonnements arrivent dans leur ordre, et qu'une liste identique n'est pas
/// renvoyée deux fois.
actor SocialFollowPublicationQueue {
    /// File partagée par l'application (`enqueueFollowPublication`).
    static let shared = SocialFollowPublicationQueue()

    private var published: [String: Data] = [:]
    private var tails: [String: Task<Void, Never>] = [:]

    /// Sérialise la publication derrière les précédentes du même compte.
    func enqueue(
        userId: String,
        body: Data,
        _ publish: @escaping (Data) async throws -> Void
    ) async throws {
        if published[userId] == body { return }
        let previous = tails[userId]
        let work = Task { () -> Void in
            _ = await previous?.value
            if published[userId] == body { return }
            try await publish(body)
            published[userId] = body
        }
        tails[userId] = Task { _ = try? await work.value }
        try await work.value
    }
}
