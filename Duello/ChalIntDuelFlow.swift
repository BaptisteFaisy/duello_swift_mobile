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
//  La série vient de `match.exerciseSequence`, plafonnée à
//  `maxExercisesPerChallenge`, repli mono-exercice sinon : le téléphone ne
//  refait aucun tirage local, comme `startSession` d'Expo.
//
//  Cible : iOS 16, aucune API iOS 17.
//
import SwiftUI
import Foundation

/// Déroulé d'un défi apparié : chargement, révélation, manches, bilan.
struct ChalIntDuelFlow: View {
    @EnvironmentObject private var session: SessionStore

    let match: MatchView
    var onFinish: () -> Void

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

    private static let emptyExercise = DuelExercise(
        id: "", subject: "", context: nil, questions: [], solution: nil
    )
    private static var emptyRound: ChalRunRoundState {
        ChalRunRoundState(
            seriesCount: 1,
            series: [],
            completedAnswers: [:],
            exerciseIndex: 0,
            exercise: emptyExercise,
            answers: [:],
            activeQuestionId: "",
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
                        onVerdict: { handleVerdict($0) },
                        onAbandon: { abandon() },
                        onStopWaiting: onFinish
                    )
                }
            case .result(let result):
                resultView(result)
            }
        }
        .task { await loadExercise() }
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
        if result.opponentAbandoned {
            ChalRunAbandonVictoryView(result: result, onBack: onFinish, onContinueTraining: nil)
        } else {
            ChalRunResultView(
                result: result,
                myInitial: myInitial,
                onBack: onFinish,
                onContinueTraining: nil
            )
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
        do {
            let manifest = try await DuelloAPI.contentManifest()
            let refs = ChalRunSeries.references(match: match, cap: ChalHome2Launch.maxExercisesPerChallenge)
            let expected = expectedBundleId()
            var banks: [String: [DuelloAPI.ChapterExercise]] = [:]
            var titles: [String] = []
            var series: [DuelExercise] = []
            for ref in refs {
                guard let built = try await ChalRunSeries.resolveExercise(
                    ref: ref,
                    subject: match.subject,
                    manifest: manifest,
                    expectedBundleId: expected,
                    banks: &banks
                ) else {
                    phase = .unavailable("L’exercice commun n’est pas disponible sur cette version de l’application.")
                    return
                }
                titles.append(built.title)
                series.append(built.exercise)
            }
            guard let first = series.first else {
                phase = .unavailable("L’exercice commun n’est pas disponible sur cette version de l’application.")
                return
            }
            exerciseTitle = titles[0]
            round = ChalRunRoundState(
                seriesCount: series.count,
                series: series,
                completedAnswers: [:],
                exerciseIndex: 0,
                exercise: first,
                answers: Dictionary(uniqueKeysWithValues: first.questions.map { ($0.id, "") }),
                activeQuestionId: first.questions.first?.id ?? "",
                submittedAt: nil
            )
            phase = .running
        } catch {
            phase = .unavailable("Impossible de charger l'énoncé : \(error.localizedDescription)")
        }
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

    // MARK: Issues

    private func handleVerdict(_ verdict: DuelVerdict) {
        let entries = ChalRunSeries.entries(state: round)
        let gradedExercise = ChalSeries.buildExercise(subject: match.subject, entries: entries)
        let gradedAnswers = ChalSeries.buildAnswers(entries: entries)
        phase = .result(ChalIntDuelResult.build(
            verdict: verdict,
            match: match,
            exercise: gradedExercise,
            seriesAnswers: gradedAnswers,
            state: round,
            profile: session.profile
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
