//
//  ChalScheduledRoom.swift
//  Duello
//
//  Lot S05 (vague 6) — salle planifiée d'un défi de classe : le **producteur**
//  du mode `.scheduled` de la file (écart 07#15, `useChallengeQueue.ts:173`).
//
//  Fichier source Expo porté (gardes et champs repris mot pour mot) :
//    - src/screens/ChallengesScreen.tsx
//        · `joinScheduledClassChallenge` (:1868-1911) : vérifie la salle
//          d'attente puis appelle `queue.enter(...)` avec
//          `scheduledChallengeId` / `scheduledStartAt` ;
//    - src/utils/challengeInvites.ts
//        · `CLASS_CHALLENGE_WAITING_ROOM_MS` (porté par
//          `DuelClassInvites.CLASS_CHALLENGE_WAITING_ROOM_MS`).
//
//  `QueueRequest` porte déjà `scheduledChallengeId` / `scheduledStartAt`
//  (`Models.swift`), et `ChalQueueController.enter` en déduit déjà le mode
//  `.scheduled` et `scheduledStartAt` (`ChalQueue.swift:101,111`) : il ne
//  manquait que l'entrée qui **remplit** ces deux champs. C'est l'objet de ce
//  fichier — l'appel d'écran (volet de défi de classe) reste à raccorder.
//
//  Cible : iOS 16, aucune API iOS 17.
//
import Foundation

/// Salle planifiée d'un défi de classe (`joinScheduledClassChallenge`).
enum ChalScheduledRoom {
    /// La salle est ouverte de `startsAt - CLASS_CHALLENGE_WAITING_ROOM_MS` à
    /// `startsAt` inclus (bornes en millisecondes epoch).
    static func isOpen(
        startsAt: Double,
        now: Double = Date().timeIntervalSince1970 * 1000
    ) -> Bool {
        now >= startsAt - Double(DuelClassInvites.CLASS_CHALLENGE_WAITING_ROOM_MS)
            && now <= startsAt
    }

    /// Construit la `QueueRequest` d'une salle planifiée : mêmes champs que la
    /// file libre, plus l'identifiant de la salle (`scheduledChallengeId`) et
    /// son départ prévu (`scheduledStartAt`). `subject` est la matière du défi
    /// de classe, `chapters`/`pools`/`startedExerciseIds` ceux calculés par
    /// l'écran pour cette salle.
    static func request(
        profile: UserProfile,
        challengeId: String,
        startsAt: Double,
        subject: String,
        chapters: [String],
        pools: [String: [String]],
        startedExerciseIds: [String],
        elo: Int = ChalHome2Launch.initialElo
    ) -> QueueRequest {
        QueueRequest(
            userId: DuelloAPI.publicProfileId(email: profile.email),
            displayName: profile.displayName.trimmingCharacters(in: .whitespacesAndNewlines),
            prepName: profile.prepName.trimmingCharacters(in: .whitespacesAndNewlines),
            track: profile.track,
            year: profile.year,
            specialty: profile.specialty.isEmpty ? nil : profile.specialty,
            subject: subject,
            chapters: chapters,
            exercisePools: pools,
            startedExerciseIds: startedExerciseIds,
            allowStartedExercises: false,
            maxExercises: ChalHome2Launch.maxExercisesPerChallenge,
            scheduledChallengeId: challengeId,
            scheduledStartAt: startsAt,
            elo: elo
        )
    }

    /// `joinScheduledClassChallenge` : hors de la salle d'attente ouverte, rien
    /// n'est déposé (`false`) ; sinon la file entre en mode planifié. Le quota
    /// de corrections est vérifié par l'appelant, comme dans la source.
    @MainActor
    @discardableResult
    static func join(
        queue: ChalQueueController,
        profile: UserProfile,
        challenge: ScheduledClassChallenge,
        startsAt: Double,
        chapters: [String],
        pools: [String: [String]],
        startedExerciseIds: [String],
        elo: Int = ChalHome2Launch.initialElo,
        now: Double = Date().timeIntervalSince1970 * 1000
    ) -> Bool {
        guard isOpen(startsAt: startsAt, now: now) else { return false }
        queue.enter(request(
            profile: profile,
            challengeId: challenge.id,
            startsAt: startsAt,
            subject: challenge.subject,
            chapters: chapters,
            pools: pools,
            startedExerciseIds: startedExerciseIds,
            elo: elo
        ))
        return true
    }
}
