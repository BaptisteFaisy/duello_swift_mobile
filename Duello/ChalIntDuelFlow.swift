//
//  ChalIntDuelFlow.swift
//  Duello
//
//  Lot 18 — intégration de l'onglet « Défis » : déroulé d'un défi apparié.
//
//  Fichier source Expo porté : `src/screens/ChallengesScreen.tsx`
//  (révélation de l'adversaire `MATCH_REVEAL_MS`, puis manches et bilan —
//  plages 1941-2697).
//
//  Enchaîne : chargement de l'énoncé servi par le serveur (même résolution de
//  banque que `ChallengePlayerView`), révélation différée (`ChalRunRevealGate`),
//  manches (`ChalRunRounds`) puis bilan (`ChalRunResultView` /
//  `ChalRunAbandonVictoryView`). Le déroulé s'appuie sur les composants du
//  lot 11-C, non sur le flux linéaire mono-exercice de `ChallengePlayerView`.
//
//  Limite assumée : la série de manches est ici d'un seul exercice
//  (`seriesCount == 1`), faute de tirage multi-exercices côté serveur ; la
//  structure `ChalRunRoundState` reste prête à en enchaîner plusieurs.
//
//  V2 (2026-09-29) — écarts de parité U07 :
//    - P1 « série multi-exercices + alerte Enchaîner » : la série est lue de
//      `match.exerciseSequence` (`matchmaking.ts:427-446`) ; chaque manche est
//      chargée dans sa propre banque ; `advanceChallengeExercise` (source
//      `ChallengesScreen.tsx:1270-1318`) range l'exercice validé et passe au
//      suivant ; `requestDuelSubmission` (`:1319-1344`) propose « Terminer le
//      défi » / « Enchaîner » tant qu'il reste un exercice et du temps. La copie
//      notée réunit les exercices validés (`ChalSeries.buildExercise`).
//    - P1 « avis exercice déjà commencé » : `startedPenalty` /
//      `opponentStartedBonus` sont projetés depuis
//      `match.exercisePreviouslyStarted` / `opponentPreviouslyStarted`
//      (`matchmaking.ts:485-486,527-528`) vers `ChalRunRounds`.
//    - P2 « Reprendre / Continuer l'exercice » : `onContinueTraining` est
//      transmis aux bilans (`ChallengesScreen.tsx:2426-2437,2703`) ; la
//      navigation vers l'onglet Entraînement est pilotée par la racine.
//
//  Écarts assumés (fichiers hors lot → « À raccorder ») :
//    - `MatchView` doit porter `exerciseSequence`, `exercisePreviouslyStarted`,
//      `opponentPreviouslyStarted` (`Models.swift`) ;
//    - `ChalRunRounds` doit arbitrer la remise (`onSubmitRequested`) et noter la
//      copie de série (`seriesEntries`) — hunks décrits au rapport.
//
//  Cible : iOS 16, aucune API iOS 17.
//
import SwiftUI
import Foundation

/// Déroulé d'un défi apparié : chargement, révélation, manches, bilan.
struct ChalIntDuelFlow: View {
    @EnvironmentObject private var session: SessionStore
    @EnvironmentObject private var progress: ProgressStore

    let match: MatchView
    var onFinish: () -> Void
    /// Reprise de l'exercice dans l'onglet Entraînement, pilotée par la racine
    /// (`onContinueTraining`, `ChallengesScreen.tsx:2426-2437,2703`). Absent ⇒
    /// les boutons « Reprendre / Continuer l'exercice » restent masqués.
    var onContinueTraining: ((ChalRunTrainingTarget) -> Void)? = nil

    private enum Phase {
        case loading
        case unavailable(String)
        case running
        case result(ChalRunResult)
    }

    @State private var phase: Phase = .loading
    @State private var round: ChalRunRoundState = ChalIntDuelFlow.emptyRound
    /// Titre de l'exercice servi, transmis au signalement de l'énoncé.
    @State private var exerciseTitle = ""
    /// Célébration de promotion de ligue refermée par le joueur.
    @State private var promotionDismissed = false
    /// Série tirée pour ce défi (`match.exerciseSequence`), dans l'ordre.
    @State private var series: [DuelExercise] = []
    /// Titres des exercices de la série, alignés sur `series`.
    @State private var seriesTitles: [String] = []
    /// Exercices déjà validés, dans l'ordre (`completedAnswers` de la source).
    @State private var completedSeries: [ChalCompletedExercise] = []
    /// Alerte « Enchaîner » d'une fin d'exercice non terminal.
    @State private var advancePromptVisible = false
    /// Remise réelle différée, déclenchée par « Terminer le défi ».
    @State private var pendingProceed: (() -> Void)?

    private static let emptyExercise = DuelExercise(
        id: "", subject: "", context: nil, questions: [], solution: nil
    )
    private static var emptyRound: ChalRunRoundState {
        ChalRunRoundState(
            seriesCount: 1,
            exerciseIndex: 0,
            exercise: emptyExercise,
            answers: [:],
            activeQuestionId: "",
            submittedAt: nil
        )
    }

    /// Manche `index` d'une série de `seriesCount` exercices, réponses vierges.
    static func round(index: Int, seriesCount: Int, exercise: DuelExercise) -> ChalRunRoundState {
        ChalRunRoundState(
            seriesCount: seriesCount,
            exerciseIndex: index,
            exercise: exercise,
            answers: Dictionary(uniqueKeysWithValues: exercise.questions.map { ($0.id, "") }),
            activeQuestionId: exercise.questions.first?.id ?? "",
            submittedAt: nil
        )
    }

    var body: some View {
        Group {
            switch phase {
            case .loading:
                loadingView
            case .unavailable(let message):
                unavailableView(message)
            case .running:
                ChalRunRevealGate(match: match) {
                    ChalRunRounds(
                        match: match,
                        userId: userId,
                        exerciseTitle: exerciseTitle,
                        state: $round,
                        startedPenalty: startedPenalty,
                        opponentStartedBonus: opponentStartedBonus,
                        completedSeries: completedSeries,
                        onSubmitRequested: { proceed in
                            requestDuelSubmission(proceed: proceed)
                        },
                        onVerdict: { handleVerdict($0) },
                        onAbandon: { abandon() }
                    )
                }
            case .result(let result):
                resultView(result)
            }
        }
        .task { await loadExercise() }
        // `requestDuelSubmission` : alerte à deux boutons de fin d'exercice non
        // terminal (`ChallengesScreen.tsx:1319-1344`).
        .alert("Exercice \(round.exerciseIndex + 1) terminé", isPresented: $advancePromptVisible) {
            Button("Terminer le défi") { pendingProceed?(); pendingProceed = nil }
            Button("Enchaîner") { advanceChallengeExercise() }
        } message: {
            Text("Tu peux enchaîner avec un autre exercice. Si tu continues, tu ne pourras plus revenir sur celui-ci.")
        }
    }

    // MARK: Vues

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Chargement de l'énoncé…")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.inkSoft)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func unavailableView(_ message: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(Theme.inkFaint)
            Text(message)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
            Button("Retour aux défis") { onFinish() }
                .buttonStyle(DuelloPrimaryButton())
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 24)
    }

    @ViewBuilder
    private func resultView(_ result: ChalRunResult) -> some View {
        ZStack {
            if result.opponentAbandoned {
                ChalRunAbandonVictoryView(
                    result: result,
                    onBack: onFinish,
                    onContinueTraining: onContinueTraining
                )
            } else {
                ChalRunResultView(
                    result: result,
                    myInitial: myInitial,
                    onBack: onFinish,
                    onContinueTraining: onContinueTraining
                )
            }
            // Célébration de promotion de ligue, superposée au bilan
            // (`result.leaguePromotion`, `renderScreen` de la source).
            if let promotion = result.leaguePromotion, !promotionDismissed {
                LeaguePromotionCelebration(promotion: promotion) {
                    promotionDismissed = true
                }
            }
        }
    }

    // MARK: Chargement de l'énoncé

    private func loadExercise() async {
        // Un seul chargement : ne pas réinitialiser la manche si la tâche
        // se rejoue alors que l'énoncé est déjà ouvert.
        guard case .loading = phase else { return }
        guard session.token != nil else {
            phase = .unavailable("Ta session a expiré, reconnecte-toi.")
            return
        }
        // Série tirée à l'appariement ; repli sur l'exercice seul si le serveur
        // n'a pas fourni de séquence (`match.exerciseSequence` vide).
        let refs = match.exerciseSequence.isEmpty
            ? [ChalExerciseRef(chapterKey: match.chapterKey, exerciseId: match.exerciseId)]
            : match.exerciseSequence
        do {
            let manifest = try await DuelloAPI.contentManifest()
            var loaded: [DuelExercise] = []
            var titles: [String] = []
            for ref in refs {
                guard let descriptor = descriptor(in: manifest, chapterKey: ref.chapterKey) else { continue }
                let exercises = try await DuelloAPI.chapterExercises(descriptor)
                guard let found = exercises.first(where: { $0.key == ref.exerciseId }) else { continue }
                let item = ChallengeExerciseEntry(
                    id: found.key,
                    title: found.title,
                    statement: found.statement,
                    solution: found.solution,
                    questions: nil
                )
                loaded.append(chapterItemAsDuelExercise(item, match.subject))
                titles.append(found.title)
            }
            guard let first = loaded.first else {
                phase = .unavailable("Cet énoncé n'est plus disponible dans la banque.")
                return
            }
            series = loaded
            seriesTitles = titles
            exerciseTitle = titles.first ?? ""
            round = ChalIntDuelFlow.round(index: 0, seriesCount: loaded.count, exercise: first)
            phase = .running
        } catch {
            phase = .unavailable("Impossible de charger l'énoncé : \(error.localizedDescription)")
        }
    }

    /// Banque servie du chapitre demandé, priorisée sur le parcours du joueur
    /// (même résolution que `ChallengePlayerView`).
    private func descriptor(
        in manifest: DuelloAPI.ContentManifest,
        chapterKey: String
    ) -> DuelloAPI.ContentChapterDescriptor? {
        let chapterId = chapterKey
            .split(separator: ":", omittingEmptySubsequences: false)
            .last.map(String.init) ?? chapterKey
        let candidates = (manifest.chapters ?? []).filter { $0.chapterId == chapterId }
        guard let expected = expectedBundleId() else { return candidates.first }
        return candidates.first(where: { $0.bundleId == expected }) ?? candidates.first
    }

    /// Banque servie attendue pour le parcours du joueur (`<scope>-statements`).
    private func expectedBundleId() -> String? {
        let parts = match.chapterKey.split(separator: ":")
        guard parts.count >= 3, let year = Int(parts[0]) else { return nil }
        let applied = session.profile.specialty
            .folding(options: .diacriticInsensitive, locale: Locale(identifier: "fr_FR"))
            .lowercased()
            .contains("appliqu")
        switch session.profile.track {
        case "MPSI":
            return year == 2 ? "mp-statements" : "mpsi-statements"
        case "ECG":
            return applied ? "ecg-applied-\(year)-statements" : "ecg-advanced-\(year)-statements"
        default:
            return nil
        }
    }

    // MARK: Série multi-exercices

    /// `canContinue` de `requestDuelSubmission` (`ChallengesScreen.tsx:1320-1324`) :
    /// il reste un exercice dans la série, sous le plafond de trois, et du temps.
    private var canContinue: Bool {
        round.exerciseIndex < series.count - 1
            && round.exerciseIndex + 1 < ChalTrainingMatchFactory.maxChallengeExercises
            && Date().timeIntervalSince1970 * 1000
                < match.startedAt + Double(match.durationMinutes * 60) * 1000
    }

    /// `requestDuelSubmission` (`ChallengesScreen.tsx:1319-1344`) : propose
    /// d'enchaîner un autre exercice, sinon remet directement la copie.
    private func requestDuelSubmission(proceed: @escaping () -> Void) {
        guard canContinue else {
            proceed()
            return
        }
        pendingProceed = proceed
        advancePromptVisible = true
    }

    /// `advanceChallengeExercise` (`ChallengesScreen.tsx:1270-1318`) : range
    /// l'exercice validé et ouvre le suivant de la série.
    private func advanceChallengeExercise() {
        let index = round.exerciseIndex
        guard index < series.count - 1 else { return }
        completedSeries.append(
            ChalCompletedExercise(exercise: round.exercise, answers: round.answers)
        )
        let nextIndex = index + 1
        exerciseTitle = seriesTitles.indices.contains(nextIndex) ? seriesTitles[nextIndex] : ""
        round = ChalIntDuelFlow.round(
            index: nextIndex,
            seriesCount: series.count,
            exercise: series[nextIndex]
        )
    }

    /// Pénalité de revue d'un exercice déjà commencé
    /// (`STARTED_EXERCISE_SCORE_PENALTY`, `matchmaking.ts:485`).
    private var startedPenalty: Int {
        match.exercisePreviouslyStarted ? ChalProgress.startedExerciseScorePenalty : 0
    }

    /// Bonus quand l'adversaire connaissait déjà l'exercice
    /// (`STARTED_OPPONENT_SCORE_BONUS`, `matchmaking.ts:486`).
    private var opponentStartedBonus: Int {
        match.opponentPreviouslyStarted ? ChalProgress.startedOpponentScoreBonus : 0
    }

    // MARK: Issues

    private func handleVerdict(_ verdict: DuelVerdict) {
        promotionDismissed = false
        // La copie notée réunit les exercices validés (`buildChallengeSeriesExercise`) ;
        // un défi mono-exercice reste l'exercice courant tel quel.
        let entries = completedSeries
            + [ChalCompletedExercise(exercise: round.exercise, answers: round.answers)]
        let graded = entries.count > 1
            ? ChalSeries.buildExercise(subject: match.subject, entries: entries)
            : round.exercise
        phase = .result(ChalIntDuelResult.build(
            verdict: verdict,
            match: match,
            exercise: graded,
            state: round,
            profile: session.profile,
            subjectElos: progress.subjectElos
        ))
    }

    private func abandon() {
        if let token = session.token {
            let matchId = match.id
            Task { await DuelloAPI.abandonDuel(matchId: matchId, userId: userId, token: token) }
        }
        onFinish()
    }

    // MARK: Dérivations

    private var userId: String {
        DuelloAPI.publicProfileId(email: session.profile.email)
    }

    private var myInitial: String {
        let name = session.profile.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return String(name.prefix(1)).uppercased()
    }
}
