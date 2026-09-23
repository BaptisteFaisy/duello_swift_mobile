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
            guard let descriptor = descriptor(in: manifest) else {
                phase = .unavailable("Cet énoncé n'est pas encore servi pour ce parcours.")
                return
            }
            let exercises = try await DuelloAPI.chapterExercises(descriptor)
            guard let found = exercises.first(where: { $0.key == match.exerciseId }) else {
                phase = .unavailable("Cet énoncé n'est plus disponible dans la banque.")
                return
            }
            let item = ChallengeExerciseEntry(
                id: found.key,
                title: found.title,
                statement: found.statement,
                solution: found.solution,
                questions: nil
            )
            let built = chapterItemAsDuelExercise(item, match.subject)
            exerciseTitle = found.title
            round = ChalRunRoundState(
                seriesCount: 1,
                exerciseIndex: 0,
                exercise: built,
                answers: Dictionary(uniqueKeysWithValues: built.questions.map { ($0.id, "") }),
                activeQuestionId: built.questions.first?.id ?? "",
                submittedAt: nil
            )
            phase = .running
        } catch {
            phase = .unavailable("Impossible de charger l'énoncé : \(error.localizedDescription)")
        }
    }

    /// Banque servie du chapitre du match, priorisée sur le parcours du joueur
    /// (même résolution que `ChallengePlayerView`).
    private func descriptor(in manifest: DuelloAPI.ContentManifest) -> DuelloAPI.ContentChapterDescriptor? {
        let chapterId = match.chapterKey
            .split(separator: ":", omittingEmptySubsequences: false)
            .last.map(String.init) ?? match.chapterKey
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

    // MARK: Issues

    private func handleVerdict(_ verdict: DuelVerdict) {
        phase = .result(ChalIntDuelResult.build(
            verdict: verdict,
            match: match,
            exercise: round.exercise,
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
