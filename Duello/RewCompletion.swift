//
//  RewCompletion.swift
//  Duello
//
//  Bonus de fin d'exercice : seuil 16/20, idempotence par soumission et
//  persistance sérialisée de l'activité.
//
//  Fichier source Expo porté (libellés et message repris mot pour mot) :
//    - src/utils/exerciseCompletionReward.ts
//        `ExerciseCompletion`, `readActivityForReward`, `practiceState`,
//        `withPracticeDay`, `recordExercisePracticeDay`,
//        `applyExerciseCompletionReward`, `recordExerciseCompletionReward`.
//    - src/utils/activity.ts   (clé `ACTIVITY_STORAGE_KEYS.activity`, `dayKey`)
//
//  Limite documentée : `activity.ts` (modèle complet `XpActivity`,
//  `loadActivity`/`saveActivity`) n'est pas dans ce lot. Ce module lit et
//  réécrit la **projection** d'activité consommée par le bonus (`Activity` :
//  jours actifs, état des bonus, historique, sessions et compteurs d'XP du
//  total). L'intégration devra fusionner cette projection avec le modèle
//  complet. La reconstruction des jours de pratique depuis les tentatives
//  d'annales (`loadAnnaleAttempts`) est hors périmètre : seules les sessions
//  d'exercice sont relues.
//
//  Cible : iOS 16, aucune dépendance externe.
//
import Foundation

/// Stockage clé/valeur de compte (`AccountStorage` réduit au nécessaire).
protocol RewActivityStorage {
    /// `accountId` : cloisonne la file d'écriture par compte.
    var accountId: String { get }
    func getItem(_ key: String) async -> String?
    func setItem(_ key: String, _ value: String) async
}

/// Lecture impossible : « Une panne de lecture ne doit jamais réinitialiser les
/// XP d'un compte. » La mutation échoue donc sans rien écrire.
enum RewCompletionError: Error, Equatable {
    case unreadableActivity
}

/// `exerciseCompletionReward.ts` : bonus d'un exercice terminé.
enum RewCompletion {
    /// `ExerciseCompletion` : soumission terminée d'un exercice.
    struct Input: Equatable {
        var submissionId: String
        var subject: String
        var program: String
        var chapterId: String
        var difficulty: Int
        var score: Double?
        var complete: Bool

        /// `JSON.stringify([subject, program, chapterId, difficulty])` : clé
        /// matière / programme / chapitre / difficulté du bonus de chapitre.
        var chapterDifficultyKey: String {
            let head = [subject, program, chapterId]
            let encoded = (try? JSONEncoder().encode(head))
                .flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
            return String(encoded.dropLast()) + ",\(difficulty)]"
        }
    }

    /// Nature d'un gain (`XpEntry.kind`, `ActivitySession.kind`).
    enum Kind: String, Codable {
        case challenge
        case exercise
    }

    /// Gain d'XP (`XpEntry`).
    struct Entry: Codable, Equatable {
        var id: String
        var kind: Kind
        var subject: String?
        var label: String
        var detail: String
        var xp: Double
        var at: Double
    }

    /// Session complète (`ActivitySession`) : seules la nature et la date
    /// servent ici, les autres champs sont conservés pour la réécriture.
    struct Session: Codable, Equatable {
        var kind: Kind
        var subject: String
        var exercises: Int
        var minutes: Int
        var won: Bool?
        var at: Double
    }

    /// Projection d'activité consommée par le bonus (sous-ensemble de
    /// `XpActivity`).
    struct Activity: Codable, Equatable {
        var activeDays: [String] = []
        var exerciseRewards: RewRewardState?
        var history: [Entry] = []
        var sessions: [Session] = []
        var challengeXp: Double = 0
        var questionXp: Double = 0
        var replayedQuestionXp: Double = 0
        var successfulFlashcards: Int = 0

        /// `activityXp` : total d'XP de l'activité (les flashcards valent
        /// `XP_RULES.flashcardCorrect`, soit 3).
        var totalXp: Double {
            RewRewardState.bonusTotal(exerciseRewards) + challengeXp + questionXp
                + replayedQuestionXp + Double(successfulFlashcards) * 3
        }

        enum CodingKeys: String, CodingKey {
            case activeDays, exerciseRewards, history, sessions
            case challengeXp, questionXp, replayedQuestionXp, successfulFlashcards
        }

        init() {}

        /// Décodage tolérant : un stockage partiel ou corrompu est complété
        /// champ par champ, jamais rejeté en bloc.
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            activeDays = (try? container.decode([String].self, forKey: .activeDays)) ?? []
            exerciseRewards = try? container.decode(RewRewardState.self, forKey: .exerciseRewards)
            history = (try? container.decode([Entry].self, forKey: .history)) ?? []
            sessions = (try? container.decode([Session].self, forKey: .sessions)) ?? []
            challengeXp = (try? container.decode(Double.self, forKey: .challengeXp)) ?? 0
            questionXp = (try? container.decode(Double.self, forKey: .questionXp)) ?? 0
            replayedQuestionXp = (try? container.decode(Double.self, forKey: .replayedQuestionXp)) ?? 0
            successfulFlashcards = (try? container.decode(Int.self, forKey: .successfulFlashcards)) ?? 0
        }
    }

    /// `{ activity, receipt, gained }`.
    struct Outcome: Equatable {
        var activity: Activity
        var receipt: ExGBonusReceipt?
        var gained: Double
    }

    /// `ACTIVITY_STORAGE_KEYS.activity`.
    static let activityStorageKey = "prepapp-xp-activity"

    /// File d'écriture par compte (`activityMutationQueues`).
    private static let queue = RewMutationQueue()

    // MARK: Bonus

    /// `applyExerciseCompletionReward` : fonction pure. Seule une note définitive
    /// strictement supérieure à 16 est primée.
    static func apply(_ activity: Activity, input: Input, at: Double) -> Outcome {
        let state = RewRewardState.normalize(activity.exerciseRewards)
        if let existing = state.receipts.first(where: { $0.submissionId == input.submissionId }) {
            return Outcome(activity: activity, receipt: existing, gained: 0)
        }
        let day = dayKey(at)
        let practiced = withPracticeDay(activity, state: state, day: day)
        guard input.complete, let score = input.score, score.isFinite,
              score > ExGBonusRules.successScoreExclusive,
              score <= ExGBonusRules.maximumScore
        else { return Outcome(activity: practiced, receipt: nil, gained: 0) }

        let key = input.chapterDifficultyKey
        let firstOfDay = state.receipts.contains { $0.day == day }
            ? 0 : ExGBonusRules.firstSuccessOfDay
        let firstChapterDifficulty = state.receipts.contains { $0.chapterDifficultyKey == key }
            ? 0 : ExGBonusRules.firstChapterDifficultySuccess
        let practiceDays = (practiced.exerciseRewards?.practiceDays ?? []).filter { $0 <= day }.count
        let practice = Double(practiceDays) * ExGBonusRules.perPracticeDay
        let gained = firstOfDay + firstChapterDifficulty + practice
        let totalBefore = activity.totalXp
        let receipt = ExGBonusReceipt(
            submissionId: input.submissionId, chapterDifficultyKey: key, day: day,
            firstOfDay: firstOfDay, firstChapterDifficulty: firstChapterDifficulty,
            practiceDays: practiceDays, practice: practice, gained: gained,
            totalBefore: totalBefore, totalAfter: totalBefore + gained
        )

        var next = practiced
        next.exerciseRewards = RewRewardState(
            practiceDays: practiced.exerciseRewards?.practiceDays ?? [],
            receipts: state.receipts + [receipt]
        )
        next.history = [Entry(
            id: "xp-exercise-bonus-\(input.submissionId)", kind: .exercise,
            subject: input.subject, label: "Bonus d’exercice réussi · \(input.subject)",
            detail: input.chapterId, xp: gained, at: at
        )] + activity.history
        return Outcome(activity: next, receipt: receipt, gained: gained)
    }

    /// `recordExerciseCompletionReward` : reçu et gains sont persistés ensemble
    /// avant d'annoncer les XP à l'élève.
    static func record(
        storage: RewActivityStorage,
        input: Input,
        at: Double = Date().timeIntervalSince1970 * 1000
    ) async throws -> Outcome {
        try await queue.enqueue(accountId: storage.accountId) {
            let current = try await readActivity(storage)
            var seeded = current
            seeded.exerciseRewards = practiceState(current)
            let outcome = apply(seeded, input: input, at: at)
            try await writeActivity(storage, outcome.activity)
            return outcome
        }
    }

    /// `recordExercisePracticeDay` : une soumission compte comme pratique, même
    /// si sa note finale est insuffisante.
    static func recordPracticeDay(
        storage: RewActivityStorage,
        at: Double = Date().timeIntervalSince1970 * 1000
    ) async throws {
        try await queue.enqueue(accountId: storage.accountId) {
            let current = try await readActivity(storage)
            let state = practiceState(current)
            let day = dayKey(at)
            if current.exerciseRewards != nil, state.practiceDays.contains(day),
               current.activeDays.contains(day) { return }
            try await writeActivity(storage, withPracticeDay(current, state: state, day: day))
        }
    }

    // MARK: Outils internes

    /// `practiceState` : état des bonus, ou reconstruction depuis les sessions
    /// d'exercice quand il manque (comptes anciens).
    private static func practiceState(_ activity: Activity) -> RewRewardState {
        if let rewards = activity.exerciseRewards { return rewards }
        let days = activity.sessions
            .filter { $0.kind == .exercise && $0.at.isFinite }
            .map { dayKey($0.at) }
        return RewRewardState(practiceDays: RewRewardState.normalizePracticeDays(days), receipts: [])
    }

    /// `withPracticeDay` : ajoute le jour à la série d'activité et aux jours de
    /// pratique, au plus une fois.
    private static func withPracticeDay(
        _ activity: Activity,
        state: RewRewardState,
        day: String
    ) -> Activity {
        var next = activity
        next.activeDays = RewRewardState.normalizePracticeDays(activity.activeDays + [day])
        var rewards = state
        rewards.practiceDays = RewRewardState.normalizePracticeDays(state.practiceDays + [day])
        next.exerciseRewards = rewards
        return next
    }

    /// `readActivityForReward` : lit la projection d'activité ; un stockage
    /// illisible lève plutôt que de faire repartir les XP à zéro.
    private static func readActivity(_ storage: RewActivityStorage) async throws -> Activity {
        guard let raw = await storage.getItem(activityStorageKey) else { return Activity() }
        guard let data = raw.data(using: .utf8),
              let activity = try? JSONDecoder().decode(Activity.self, from: data)
        else { throw RewCompletionError.unreadableActivity }
        return activity
    }

    /// Écrit la projection d'activité sous la clé de l'activité.
    private static func writeActivity(
        _ storage: RewActivityStorage,
        _ activity: Activity
    ) async throws {
        let data = try JSONEncoder().encode(activity)
        guard let raw = String(data: data, encoding: .utf8) else {
            throw RewCompletionError.unreadableActivity
        }
        await storage.setItem(activityStorageKey, raw)
    }

    /// `dayKey` : jour local AAAA-MM-JJ (repris de `ProgressStore`).
    private static func dayKey(_ at: Double) -> String {
        ProgressStore.dayKey(at: Date(timeIntervalSince1970: at / 1000))
    }
}
