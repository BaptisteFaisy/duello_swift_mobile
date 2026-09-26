//
//  ChalMatchmakingTraining.swift
//  Duello
//
//  V1 L5 (2026-09-26, U07 partB#3 + partD#4) — adversaire d'entraînement quand
//  la file reste vide : `buildTrainingMatch`, porté textuellement.
//
//  Fichier source Expo porté (tirage, graine et fabrication repris mot pour
//  mot) :
//    - src/utils/matchmaking.ts
//      (`TRAINING_OPPONENT`, `TRAINING_ELO_BONUS`,
//       `eligibleChallengeExerciseOptions`, `pickChallengeExerciseSequence`,
//       `seedFrom`, `trainingMatchId`, `buildTrainingMatch`)
//
//  La partie est préparée sur le téléphone et toujours annoncée comme un
//  entraînement (« ADVERSAIRE D'ENTRAÎNEMENT », carte du lot 11-C) ; l'écran
//  vérifiera néanmoins le quota serveur avant d'ouvrir le sujet.
//
//  Diff de types assumé (lisible ici, pas dans l'appelant) : `MatchView`
//  Swift ne porte ni `initial`, ni `track`/`year` d'adversaire, ni
//  `exercisePreviouslyStarted` / `opponentPreviouslyStarted` — tous à venir
//  avec les lots V2 (U07 partB#4 partD#6). Le nom « Léa M. », son initiale
//  (dérivée du nom par la carte), la prépa du demandeur et la cote bonusée
//  sont repris mot pour mot.
//
//  Cible : iOS 16, aucune API iOS 17.
//
import Foundation

/// Adversaire d'entraînement (`buildTrainingMatch` de `matchmaking.ts`).
enum ChalTrainingMatch {
    /// Nom et initiale affichés (`TRAINING_OPPONENT`).
    static let opponentDisplayName = "Léa M."
    /// Bonus de cote de l'adversaire d'entraînement (`TRAINING_ELO_BONUS`).
    static let eloBonus = 12

    /// Option encore jouable pour un joueur (`ChallengeExerciseOption`).
    struct Option {
        var chapterKey: String
        var exerciseIds: [String]
    }

    /// Partie contre l'adversaire d'entraînement, quand la file reste vide ou
    /// que le serveur est injoignable. `nil` quand aucun exercice n'est
    /// jouable : l'appelant revient alors au repos.
    static func build(
        request: QueueRequest,
        now: Double,
        durationMinutes: Int = ChalMatchmaking.challengeDurationMinutes
    ) -> MatchView? {
        let identity = "\(request.userId)|\(request.subject)|\(Int(now))"
        let seed = seed(from: identity)
        let capacity = min(request.maxExercises ?? 1, ChalHome2Launch.maxExercisesPerChallenge)
        let sequence = pickSequence(options: eligibleOptions(request), seed: seed, limit: capacity)
        guard let exercise = sequence.first else { return nil }
        return MatchView(
            id: trainingMatchId(identity: identity),
            seed: seed,
            subject: request.subject,
            chapterKey: exercise.chapterKey,
            exerciseId: exercise.exerciseId,
            exerciseSequence: sequence,
            durationMinutes: durationMinutes,
            startedAt: now,
            opponent: MatchView.Opponent(
                userId: nil,
                displayName: opponentDisplayName,
                prepName: request.prepName,
                elo: max(0, request.elo + eloBonus),
                training: true
            )
        )
    }

    /// Options encore jouables pour un joueur, hors exercices déjà commencés
    /// (`eligibleChallengeExerciseOptions`).
    static func eligibleOptions(_ request: QueueRequest) -> [Option] {
        selectedChapterKeys(request).compactMap { chapterKey in
            let exerciseIds = eligibleExerciseIds(request, chapterKey: chapterKey)
            return exerciseIds.isEmpty ? nil : Option(chapterKey: chapterKey, exerciseIds: exerciseIds)
        }
    }

    /// Tire sans remise jusqu'à trois exercices dans l'intersection acceptée
    /// (`pickChallengeExerciseSequence`). Le tri initial rend le résultat
    /// indépendant de l'ordre des banques envoyées par chaque téléphone.
    static func pickSequence(options: [Option], seed: Int, limit: Int) -> [ChallengeExerciseRef] {
        var remaining = options
            .flatMap { option in
                option.exerciseIds.map {
                    ChallengeExerciseRef(chapterKey: option.chapterKey, exerciseId: $0)
                }
            }
            .sorted {
                "\($0.chapterKey)|\($0.exerciseId)"
                    .compare("\($1.chapterKey)|\($1.exerciseId)") == .orderedAscending
            }
        var picked: [ChallengeExerciseRef] = []
        let maximum = min(max(0, limit), remaining.count)
        while picked.count < maximum, !remaining.isEmpty {
            let index = seed(from: "\(seed)|series|\(picked.count)") % remaining.count
            picked.append(remaining.remove(at: index))
        }
        return picked
    }

    /// Empreinte stable d'un texte, comme `publicProfileId` (FNV-1a 32 bits).
    static func seed(from text: String) -> Int {
        var hash: UInt32 = 0x811C_9DC5
        for unit in text.utf16 {
            hash ^= UInt32(unit)
            hash = hash &* 0x0100_0193
        }
        return Int(hash)
    }

    /// Clés de chapitres acceptées : la sélection, ou toute la matière quand
    /// elle est vide (`selectedChallengeChapterKeys`).
    private static func selectedChapterKeys(_ request: QueueRequest) -> [String] {
        let keys = request.chapters.isEmpty ? Array(request.exercisePools.keys) : request.chapters
        return Array(Set(keys)).sorted()
    }

    /// Identifiants encore jouables d'un chapitre, hors exercices déjà
    /// commencés (`eligibleExerciseIds`).
    private static func eligibleExerciseIds(_ request: QueueRequest, chapterKey: String) -> [String] {
        let started = Set(request.startedExerciseIds)
        return Array(Set(request.exercisePools[chapterKey] ?? []))
            .filter { !started.contains($0) }
            .sorted()
    }

    /// UUID déterministe accepté par le quota serveur, sans dépendance native
    /// (`trainingMatchId`).
    private static func trainingMatchId(identity: String) -> String {
        let hex = [0, 1, 2, 3]
            .map { String(seed(from: "\(identity)|\($0)"), radix: 16).leftPadded(to: 8) }
            .joined()
        let chars = Array(hex)
        let variant = String(((Int(String(chars[16]), radix: 16) ?? 0) & 0x3) | 0x8, radix: 16)
        return [
            String(chars[0 ..< 8]),
            String(chars[8 ..< 12]),
            "4" + String(chars[13 ..< 16]),
            variant + String(chars[17 ..< 20]),
            String(chars[20 ..< 32]),
        ].joined(separator: "-")
    }
}

// MARK: - Bourrage hexadécimal

extension String {
    /// `padStart(8, '0')` de la source : bourre à gauche jusqu'à la longueur.
    fileprivate func leftPadded(to length: Int) -> String {
        count >= length ? self : String(repeating: "0", count: length - count) + self
    }
}
