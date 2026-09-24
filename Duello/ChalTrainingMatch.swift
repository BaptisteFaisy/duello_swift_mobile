//
//  ChalTrainingMatch.swift
//  Duello
//
//  Adversaire d'entraînement fabriqué sur le téléphone quand la file reste vide
//  ou que le serveur est injoignable : tirage de série, identité du match et
//  adversaire toujours annoncé comme un entraînement.
//
//  Fichier source Expo porté (règles, constantes et libellés repris mot pour mot) :
//    - src/utils/matchmaking.ts
//        `TRAINING_OPPONENT` (`Léa M.` / `L`), `TRAINING_ELO_BONUS` (12),
//        `MAX_CHALLENGE_EXERCISES` (3), `ChallengeExercisePools`,
//        `ChallengeExerciseOption`, `ChallengeExerciseRef`, `MatchOpponent`,
//        `MatchView`, `seedFrom`, `selectedChallengeChapterKeys`,
//        `eligibleExerciseIds`, `eligibleChallengeExerciseOptions`,
//        `pickChallengeExerciseSequence`, `firstInitial`, `trainingMatchId`,
//        `buildTrainingMatch`.
//
//  Réutilise sans les recréer : `QueueRequest` et `MatchView` (`Models.swift`).
//  `buildTrainingMatch` renvoie un `ChalTrainingMatch` (vue plus riche que
//  `MatchView`, qui ne porte ni la série ni les drapeaux « déjà commencé ») ;
//  `matchView()` fournit la projection attendue par la file existante.
//
//  Notes (réduit / approché / limite assumée, 24/09/2026) :
//   - `seedFrom` hache les scalaires Unicode là où `charCodeAt` hache les unités
//     UTF-16 : identique pour les identifiants ASCII et les lettres latines
//     accentuées (BMP) qui composent les entrées réelles ;
//   - le tri `localeCompare` de la source est approché par l'ordre `<` de Swift,
//     équivalent pour ces clés ASCII (`chapitre|exercice`) ;
//   - `MAX_CHALLENGE_EXERCISES` recoupe `ChalHome2Launch.maxExercisesPerChallenge`
//     (même valeur 3), volontairement non référencé pour garder ce fichier
//     autonome.
//
//  Cible : iOS 16. Aucune dépendance externe.
//
import Foundation

/// `ChallengeExerciseRef` : chapitre + exercice d'un tour de série.
struct ChalExerciseRef: Codable, Equatable, Hashable {
    var chapterKey: String
    var exerciseId: String
}

/// `ChallengeExerciseOption` : chapitre et exercices jouables.
struct ChalExerciseOption: Codable, Equatable {
    var chapterKey: String
    var exerciseIds: [String]
}

/// `MatchOpponent` d'un entraînement : toujours annoncé comme tel.
struct ChalTrainingOpponent: Codable, Equatable {
    var displayName: String
    var initial: String
    var prepName: String
    var track: String
    var year: String
    var elo: Int
    /// Vrai pour l'adversaire d'entraînement, jamais présenté comme un joueur réel.
    var training: Bool
}

/// `MatchView` d'un entraînement préparé sur le téléphone.
struct ChalTrainingMatch: Codable, Equatable, Identifiable {
    var id: String
    var seed: Int
    var subject: String
    var chapterKey: String
    var exerciseId: String
    /// Série commune ; le premier élément reprend `chapterKey` et `exerciseId`.
    var exerciseSequence: [ChalExerciseRef]
    /// Vrai si ce joueur avait déjà ouvert l'exercice avant ce défi.
    var exercisePreviouslyStarted: Bool
    /// Vrai si l'adversaire (d'entraînement : jamais) avait déjà ouvert l'exercice.
    var opponentPreviouslyStarted: Bool
    var durationMinutes: Int
    var startedAt: Double
    var opponent: ChalTrainingOpponent

    /// Projection vers la vue consommée par la file (`MatchView`).
    func matchView() -> MatchView {
        MatchView(
            id: id,
            seed: seed,
            subject: subject,
            chapterKey: chapterKey,
            exerciseId: exerciseId,
            durationMinutes: durationMinutes,
            startedAt: startedAt,
            opponent: MatchView.Opponent(
                userId: nil,
                displayName: opponent.displayName,
                prepName: opponent.prepName,
                elo: opponent.elo,
                training: opponent.training
            )
        )
    }
}

/// Fabrique d'un match d'entraînement (`buildTrainingMatch`).
enum ChalTrainingMatchFactory {
    /// `TRAINING_OPPONENT.displayName`.
    static let trainingOpponentDisplayName = "Léa M."
    /// `TRAINING_OPPONENT.initial`.
    static let trainingOpponentInitial = "L"
    /// `TRAINING_ELO_BONUS` : l'adversaire est réglé juste au-dessus du joueur.
    static let trainingEloBonus = 12
    /// `MAX_CHALLENGE_EXERCISES` : nombre maximal d'exercices d'une série.
    static let maxChallengeExercises = 3

    /// `seedFrom` : empreinte stable FNV-1a 32 bits, comme `publicProfileId`.
    static func seedFrom(_ text: String) -> UInt32 {
        var hash: UInt32 = 0x811c_9dc5
        for scalar in text.unicodeScalars {
            hash ^= scalar.value
            hash = hash &* 0x0100_0193
        }
        return hash
    }

    /// `selectedChallengeChapterKeys` : chapitres acceptés, ou toute la matière.
    static func selectedChallengeChapterKeys(_ request: QueueRequest) -> [String] {
        let keys = request.chapters.isEmpty ? Array(request.exercisePools.keys) : request.chapters
        return Array(Set(keys)).sorted()
    }

    /// `eligibleExerciseIds` : exercices du chapitre, hors exercices commencés.
    static func eligibleExerciseIds(_ request: QueueRequest, chapterKey: String) -> [String] {
        let started = Set(request.startedExerciseIds)
        let pool = request.exercisePools[chapterKey] ?? []
        return Array(Set(pool)).filter { !started.contains($0) }.sorted()
    }

    /// `eligibleChallengeExerciseOptions` : options encore jouables pour un joueur.
    static func eligibleChallengeExerciseOptions(_ request: QueueRequest) -> [ChalExerciseOption] {
        selectedChallengeChapterKeys(request).compactMap { chapterKey in
            let ids = eligibleExerciseIds(request, chapterKey: chapterKey)
            return ids.isEmpty ? nil : ChalExerciseOption(chapterKey: chapterKey, exerciseIds: ids)
        }
    }

    /// `pickChallengeExerciseSequence` : tire sans remise jusqu'à `limit`
    /// exercices, dans un ordre qui ne dépend que de la graine.
    static func pickChallengeExerciseSequence(
        _ options: [ChalExerciseOption],
        seed: UInt32,
        limit: Int = maxChallengeExercises
    ) -> [ChalExerciseRef] {
        var remaining = options
            .flatMap { option in
                option.exerciseIds.map {
                    ChalExerciseRef(chapterKey: option.chapterKey, exerciseId: $0)
                }
            }
            .sorted {
                "\($0.chapterKey)|\($0.exerciseId)" < "\($1.chapterKey)|\($1.exerciseId)"
            }
        var picked: [ChalExerciseRef] = []
        let maximum = min(max(0, limit), remaining.count)
        while picked.count < maximum {
            let index = Int(seedFrom("\(seed)|series|\(picked.count)") % UInt32(remaining.count))
            picked.append(remaining.remove(at: index))
        }
        return picked
    }

    /// `firstInitial` : première lettre du nom, ou `?`.
    static func firstInitial(_ displayName: String) -> String {
        guard let first = displayName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .first
        else { return "?" }
        return String(first).uppercased()
    }

    /// `trainingMatchId` : UUID déterministe accepté par le quota serveur.
    static func trainingMatchId(_ identity: String) -> String {
        var hex = ""
        for part in 0..<4 {
            hex += String(format: "%08x", seedFrom("\(identity)|\(part)"))
        }
        let chars = Array(hex)
        let nibble = UInt8(String(chars[16]), radix: 16) ?? 0
        let variant = String((nibble & 0x3) | 0x8, radix: 16)
        return [
            String(chars[0..<8]),
            String(chars[8..<12]),
            "4" + String(chars[13..<16]),
            variant + String(chars[17..<20]),
            String(chars[20..<32]),
        ].joined(separator: "-")
    }

    /// `buildTrainingMatch` : partie d'entraînement, ou `nil` sans exercice jouable.
    static func buildTrainingMatch(
        _ request: QueueRequest,
        now: Double,
        durationMinutes: Int
    ) -> ChalTrainingMatch? {
        let identity = "\(request.userId)|\(request.subject)|\(Int64(now))"
        let seed = seedFrom(identity)
        let limit = min(request.maxExercises ?? 1, maxChallengeExercises)
        let sequence = pickChallengeExerciseSequence(
            eligibleChallengeExerciseOptions(request),
            seed: seed,
            limit: limit
        )
        guard let exercise = sequence.first else { return nil }
        return ChalTrainingMatch(
            id: trainingMatchId(identity),
            seed: Int(seed),
            subject: request.subject,
            chapterKey: exercise.chapterKey,
            exerciseId: exercise.exerciseId,
            exerciseSequence: sequence,
            exercisePreviouslyStarted: request.startedExerciseIds.contains(exercise.exerciseId),
            opponentPreviouslyStarted: false,
            durationMinutes: durationMinutes,
            startedAt: now,
            opponent: ChalTrainingOpponent(
                displayName: trainingOpponentDisplayName,
                initial: trainingOpponentInitial,
                prepName: request.prepName,
                track: request.track,
                year: request.year,
                elo: max(0, Int((Double(request.elo) + Double(trainingEloBonus)).rounded())),
                training: true
            )
        )
    }
}
