//
//  ChalProgress.swift
//  Duello
//
//  Lot « Extras de défi » — progression d'exercice de défi : exercices déjà
//  commencés, fusion d'une copie de défi dans le brouillon, reprise de copie.
//
//  Fichier source Expo porté (constantes et règles repris mot pour mot) :
//    - src/utils/challengeExerciseProgress.ts
//      (`STARTED_EXERCISE_SCORE_PENALTY`, `STARTED_OPPONENT_SCORE_BONUS`,
//       `startedChallengeExerciseIds`, `mergeChallengeAttempt`,
//       `challengeNeedsContinuation`, `challengeScoreBeforePenalty`,
//       `loadAllowStartedChallengeExercises`,
//       `saveAllowStartedChallengeExercises`)
//
//  Adaptations assumées (pas d'`AccountStorage` ni d'`AnnaleAttempt` en Swift) :
//  - `startedChallengeExerciseIds` recevait une table d'essais d'annales ; elle
//    reçoit ici la liste des identifiants d'essais, seules les clés comptant.
//  - `mergeChallengeAttempt` renvoyait un `AnnaleAttempt` complet ; elle renvoie
//    un `ChalAttemptDraft` réduit aux champs qu'elle manipule réellement
//    (réponses, questions déjà corrigées, date).
//  - `load/saveAllowStartedChallengeExercises` persistaient dans le stockage du
//    compte ; elles persistent dans `UserDefaults`, isolées par `accountId`
//    comme la source isole par compte.
//
//  Cible : iOS 16, aucune API iOS 17.
//
import Foundation

/// Brouillon de copie de défi, réduit aux champs manipulés par la fusion.
struct ChalAttemptDraft: Equatable {
    var itemId: String
    var answers: [String: String]
    /// Questions déjà corrigées : leur réponse est immuable, le défi ne l'écrase
    /// ni ne la remplace.
    var reviewedQuestionIds: Set<String>
    var updatedAt: Date
}

/// Progression d'exercice de défi (`challengeExerciseProgress.ts`).
enum ChalProgress {
    /// Avantage retiré lorsqu'un joueur accepte de revoir un exercice déjà ouvert.
    static let startedExerciseScorePenalty = 5
    /// Compensation accordée au joueur dont l'adversaire connaissait déjà l'exercice.
    static let startedOpponentScoreBonus = 5

    /// Clé de persistance (`ACCOUNT_STORAGE_KEYS.challengeAllowStartedExercises`).
    private static let allowStartedStorageKey =
        "prepapp-challenge-allow-started-exercises:v1"

    /// Une ouverture suffit à classer l'exercice comme commencé. Les résultats
    /// historiques restent pris en compte pour les anciennes versions qui
    /// n'enregistraient l'essai qu'au moment de sa correction complète.
    static func startedExerciseIds(
        progress: [String: ItemProgress],
        attemptIds: [String]
    ) -> [String] {
        var ids = Set(attemptIds)
        for (itemId, itemProgress) in progress
        where itemProgress.attempts > 0 || itemProgress.bestOutcome != nil {
            ids.insert(itemId)
        }
        return ids.sorted()
    }

    /// Verse les réponses d'un défi dans le brouillon d'entraînement
    /// (`mergeChallengeAttempt`). Une réponse déjà corrigée est immuable : le
    /// défi ne doit ni effacer son verdict ni remplacer son texte ; les autres
    /// champs reçoivent la rédaction la plus récente du défi.
    static func mergeAttempt(
        current: ChalAttemptDraft?,
        itemId: String,
        answers: [String: String],
        updatedAt: Date = Date()
    ) -> ChalAttemptDraft {
        let base = current ?? ChalAttemptDraft(
            itemId: itemId,
            answers: [:],
            reviewedQuestionIds: [],
            updatedAt: updatedAt
        )
        var mergedAnswers = base.answers
        for (questionId, answer) in answers {
            let trimmed = answer.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty && !base.reviewedQuestionIds.contains(questionId) {
                mergedAnswers[questionId] = answer
            }
        }
        return ChalAttemptDraft(
            itemId: itemId,
            answers: mergedAnswers,
            reviewedQuestionIds: base.reviewedQuestionIds,
            updatedAt: updatedAt
        )
    }

    /// Vrai si la copie doit être proposée à la reprise dans Entraînements.
    static func needsContinuation(
        questionIds: [String],
        answers: [String: String],
        score: Int
    ) -> Bool {
        if score < 100 { return true }
        return questionIds.contains { questionId in
            (answers[questionId] ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .isEmpty
        }
    }

    /// Reconstitue la note de correction avant le retrait affiché dans le défi.
    static func scoreBeforePenalty(adjustedScore: Int, penalty: Int) -> Int {
        min(100, max(0, adjustedScore) + max(0, penalty))
    }

    /// Lit la préférence d'autorisation du compte (`loadAllowStarted…`).
    static func loadAllowStarted(accountId: String) -> Bool {
        UserDefaults.standard.string(forKey: allowStartedKey(for: accountId)) == "true"
    }

    /// Écrit la préférence d'autorisation du compte (`saveAllowStarted…`).
    static func saveAllowStarted(_ allow: Bool, accountId: String) {
        UserDefaults.standard.set(
            allow ? "true" : "false",
            forKey: allowStartedKey(for: accountId)
        )
    }

    /// Clé isolée par compte, comme le stockage de compte d'Expo.
    private static func allowStartedKey(for accountId: String) -> String {
        let trimmed = accountId.trimmingCharacters(in: .whitespacesAndNewlines)
        return "\(allowStartedStorageKey):\(trimmed.isEmpty ? "local" : trimmed)"
    }
}
