//
//  ChalRunSeries.swift
//  Duello
//
//  Série d'un défi : références servies, enchaînement des manches et copie
//  assemblée pour la notation.
//
//  Fichier source Expo porté : `src/screens/ChallengesScreen.tsx`
//    - `startSession` : la série vient de `match.exerciseSequence`, plafonnée
//      à `MAX_CHALLENGE_EXERCISES`, repli mono-exercice sinon — le téléphone
//      ne refait aucun tirage local ;
//    - `advanceChallengeExercise` : la copie courante est figée dans
//      `completedAnswers`, impossible à rouvrir, puis l'exercice suivant s'ouvre ;
//    - `submitDuel` : les exercices joués partent à la notation en une seule
//      copie (`buildChallengeSeriesExercise` / `buildChallengeSeriesAnswers`).
//
//  La résolution de chaque référence suit le modèle servi du portage
//  (`DuelloAPI.contentManifest`, une banque par chapitre, mémoïsée) plutôt que
//  la banque locale d'Expo. Les brouillons d'Entraînement que la source
//  enregistre à l'avancée n'ont pas d'équivalent ici : les copies figées ne
//  vivent que dans l'état de la manche.
//
//  Cible : iOS 16, aucune API iOS 17.
//
import Foundation

/// Série commune d'un défi (`session.series`, `advanceChallengeExercise`).
enum ChalRunSeries {
    /// Références servies par le serveur, plafonnées au maximum du défi ;
    /// repli mono-exercice quand le match n'apporte pas de séquence.
    static func references(match: MatchView, cap: Int) -> [ChallengeExerciseRef] {
        if let sequence = match.exerciseSequence, !sequence.isEmpty {
            return Array(sequence.prefix(cap))
        }
        return [ChallengeExerciseRef(chapterKey: match.chapterKey, exerciseId: match.exerciseId)]
    }

    /// Résout une référence depuis la banque servie de son chapitre
    /// (`challengeExercisesFor` + `chapterItemAsDuelExercise`), `nil` quand
    /// l'énoncé n'est pas servi. `banks` mémoïse une banque par descripteur.
    static func resolveExercise(
        ref: ChallengeExerciseRef,
        subject: String,
        manifest: DuelloAPI.ContentManifest,
        expectedBundleId: String?,
        banks: inout [String: [DuelloAPI.ChapterExercise]]
    ) async throws -> (title: String, exercise: DuelExercise)? {
        let chapterId = ref.chapterKey
            .split(separator: ":", omittingEmptySubsequences: false)
            .last.map(String.init) ?? ref.chapterKey
        let candidates = (manifest.chapters ?? []).filter { $0.chapterId == chapterId }
        let descriptor: DuelloAPI.ContentChapterDescriptor?
        if let expected = expectedBundleId {
            descriptor = candidates.first(where: { $0.bundleId == expected }) ?? candidates.first
        } else {
            descriptor = candidates.first
        }
        guard let descriptor else { return nil }
        let bank: [DuelloAPI.ChapterExercise]
        if let cached = banks[descriptor.file] {
            bank = cached
        } else {
            let fetched = try await DuelloAPI.chapterExercises(descriptor)
            banks[descriptor.file] = fetched
            bank = fetched
        }
        guard let found = bank.first(where: { $0.key == ref.exerciseId }) else { return nil }
        let item = ChallengeExerciseEntry(
            id: found.key,
            title: found.title,
            statement: found.statement,
            solution: found.solution,
            questions: nil
        )
        return (found.title, chapterItemAsDuelExercise(item, subject))
    }

    /// Entrées à noter : copies figées des exercices précédents, copie
    /// courante rassemblée, exercices suivants encore vides.
    static func entries(state: ChalRunRoundState) -> [ChalCompletedExercise] {
        state.series.enumerated().map { index, exercise in
            let answers: [String: String]
            if index < state.exerciseIndex {
                answers = state.completedAnswers[index] ?? [:]
            } else if index == state.exerciseIndex {
                answers = attemptedDuelAnswers(state.exercise, state.answers)
            } else {
                answers = [:]
            }
            return ChalCompletedExercise(exercise: exercise, answers: answers)
        }
    }

    /// Fige la copie courante et ouvre l'exercice suivant, `nil` quand la
    /// série est épuisée (`advanceChallengeExercise`).
    static func advance(state: ChalRunRoundState) -> ChalRunRoundState? {
        let nextIndex = state.exerciseIndex + 1
        guard nextIndex < state.series.count else { return nil }
        var next = state
        next.completedAnswers[state.exerciseIndex] = attemptedDuelAnswers(state.exercise, state.answers)
        next.exerciseIndex = nextIndex
        next.exercise = state.series[nextIndex]
        next.answers = Dictionary(uniqueKeysWithValues: next.exercise.questions.map { ($0.id, "") })
        next.activeQuestionId = next.exercise.questions.first?.id ?? ""
        return next
    }
}
