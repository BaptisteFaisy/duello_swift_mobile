//
//  ChalIntDuelResult.swift
//  Duello
//
//  Lot 18 — intégration de l'onglet « Défis » : construction du bilan.
//
//  Fichier source Expo porté : `src/screens/ChallengesScreen.tsx`
//  (branche de résultat, plage 2370-2697 : dérivations `opponentName`,
//  `opponentInitial`, `opponentAbandoned`, `eloAfter`, `prompt`, `solution`,
//  `reviewedQuestions`, `needsContinuation`, `trainingTarget`).
//
//  Réutilise sans les recréer : `DuelVerdict`, `DuelExercise`, `ChalRunResult`,
//  `ChalRunTrainingTarget`, `ChalProgress`, `attemptedDuelAnswers`,
//  `duelExercisePrompt`.
//
//  Cible : iOS 16, aucune API iOS 17.
//
import Foundation

/// Fabrique le bilan (`ChalRunResult`) affiché après un défi à partir du verdict
/// rendu par `judgeDuel`, de l'énoncé joué et de la manche courante.
enum ChalIntDuelResult {
    /// Matière unique des défis (`getChallengeTrackSubjects` filtre sur maths).
    private static let subjectId = "maths"
    /// Nature de l'activité reprise dans Entraînement.
    private static let activity = "exercice"

    /// Vrai quand la victoire vient d'un abandon adverse.
    ///
    /// Le serveur le signale par le motif `opponent_abandoned`, que
    /// `forfeitVerdict` rend par la phrase « Ton adversaire a abandonné … » :
    /// c'est la seule formulation de verdict qui emploie ce mot, d'où ce test.
    static func opponentAbandoned(_ verdict: DuelVerdict) -> Bool {
        verdict.summary.contains("abandonné")
    }

    /// Assemble le bilan lu par `ChalRunResultView` / `ChalRunAbandonVictoryView`.
    static func build(
        verdict: DuelVerdict,
        match: MatchView,
        exercise: DuelExercise,
        state: ChalRunRoundState,
        profile: UserProfile
    ) -> ChalRunResult {
        let answers = attemptedDuelAnswers(exercise, state.answers)
        return ChalRunResult(
            verdict: verdict,
            opponentName: match.opponent.displayName,
            opponentInitial: String(match.opponent.displayName.prefix(1)).uppercased(),
            opponentAbandoned: opponentAbandoned(verdict),
            eloAfter: verdict.elo?.after,
            prompt: duelExercisePrompt(exercise),
            solution: exercise.solution,
            questions: exercise.questions,
            answers: answers,
            opponentAnswers: verdict.opponentAnswers ?? [:],
            scorePenalty: 0,
            scoreBonus: 0,
            needsContinuation: ChalProgress.needsContinuation(
                questionIds: exercise.questions.map { $0.id },
                answers: answers,
                score: verdict.me.score
            ),
            exerciseCount: max(1, state.seriesCount),
            minutes: match.durationMinutes,
            subject: match.subject,
            trainingTarget: ChalRunTrainingTarget(
                itemId: match.exerciseId,
                itemTitle: match.exerciseId,
                subjectId: subjectId,
                chapterId: match.chapterKey,
                year: profile.year,
                activity: activity
            )
        )
    }
}
