import Foundation

// MARK: - Orchestration de la notation (port de utils/duelJudge.ts)

/// Rythme d'interrogation du résultat pendant l'attente de l'adversaire.
private let duelPollIntervalMs: UInt64 = 2_000
/// Au-delà, le serveur des défis est considéré comme perdu pour de bon.
private let maxPollFailures = 5

private func pause(_ ms: UInt64) async {
    try? await Task.sleep(nanoseconds: ms * 1_000_000)
}

/// Le quota serveur est un refus produit, jamais une panne à masquer
/// localement (`CorrectionQuotaError` côté Expo).
struct DuelQuotaError: Error {
    var message: String
    var nextFreeAt: Double?
}

/// Notation d'une copie : l'IA d'abord, barème local en second rideau
/// (`gradeCopy`). Une copie vide ou limitée à l'énoncé n'est pas envoyée :
/// elle vaut 0 sur le barème du relais comme sur celui de l'app.
private func gradeCopy(
    subject: String,
    exercise: DuelExercise,
    production: String,
    durationMinutes: Int,
    operationKey: String,
    token: String
) async throws -> (assessment: ProductionAssessment, source: DuelVerdict.Source) {
    if production.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        return (ProductionAssessment(score: 0, note: "Aucune réponse rendue."), .ai)
    }

    let prompt = duelExercisePrompt(exercise)
    if let deterministic = DuelCopyPolicy.deterministicStatementGrade(prompt, production) {
        return (deterministic, .ai)
    }

    do {
        let assessment = try await DuelloAPI.gradeCopyWithAi(
            subject: subject,
            prompt: prompt,
            solution: exercise.solution,
            copy: production,
            durationMinutes: durationMinutes,
            operationKey: operationKey,
            token: token
        )
        return (assessment, .ai)
    } catch let error as DuelloAPI.GradingError {
        // Un refus de quota remonte tel quel à l'écran : ce n'est pas une
        // panne, et le barème local ne doit pas le masquer.
        if case .quota(let message, let nextFreeAt) = error {
            throw DuelQuotaError(message: message, nextFreeAt: nextFreeAt)
        }
        return (LocalRubric.gradeLocally(production, prompt), .local)
    } catch {
        // Relais absent, hors ligne ou note illisible : le barème local prend
        // le relais, et l'écran dira que la notation ne vient pas de l'IA.
        return (LocalRubric.gradeLocally(production, prompt), .local)
    }
}

/// Attend la note de l'adversaire (`waitForOpponent`). S'arrête à la date
/// limite : passé ce délai, le serveur prononce le forfait de celui qui n'a
/// rien rendu. Rend `nil` lorsque le joueur a renoncé à attendre.
private func waitForOpponent(
    matchId: String,
    userId: String,
    deadline: Double,
    token: String
) async -> DuelResultState? {
    var failures = 0
    while !Task.isCancelled {
        await pause(duelPollIntervalMs)
        if Task.isCancelled { return nil }
        do {
            let state = try await DuelloAPI.pollDuelResult(
                matchId: matchId, userId: userId, token: token
            )
            switch state {
            case .waiting:
                failures = 0
            default:
                return state
            }
        } catch {
            // Un réseau qui hoquette ne doit pas conclure le défi ; un
            // serveur qui a disparu, si.
            failures += 1
            if failures >= maxPollFailures { return nil }
        }
    }
    return nil
}

/// Dépose sa note sur le serveur, attend celle d'en face, puis tranche
/// (`settleAgainstPlayer`).
private func settleAgainstPlayer(
    match: MatchView,
    userId: String,
    token: String,
    mine: (assessment: ProductionAssessment, source: DuelVerdict.Source),
    answers: [String: String],
    onWaitingForOpponent: ((Double) -> Void)?
) async -> DuelVerdict {
    var state: DuelResultState
    do {
        state = try await DuelloAPI.submitDuelGrade(
            matchId: match.id,
            userId: userId,
            grade: DuelSubmission(
                score: mine.assessment.score,
                note: mine.assessment.note,
                graded: mine.source == .ai,
                answers: answers
            ),
            token: token
        )
    } catch {
        return unsettledVerdict(mine.assessment, "le serveur des défis est injoignable", mine.source)
    }

    if case .waiting(let deadline) = state {
        onWaitingForOpponent?(deadline)
        guard let awaited = await waitForOpponent(
            matchId: match.id, userId: userId, deadline: deadline, token: token
        ) else {
            return unsettledVerdict(
                mine.assessment,
                "la copie de ton adversaire n’a pas été attendue jusqu’au bout",
                mine.source
            )
        }
        state = awaited
    }

    return verdict(for: state, mine: mine)
}

/// Traduit l'état rendu par le serveur en verdict, une fois l'attente finie.
private func verdict(
    for state: DuelResultState,
    mine: (assessment: ProductionAssessment, source: DuelVerdict.Source)
) -> DuelVerdict {
    switch state {
    case .waiting:
        return unsettledVerdict(
            mine.assessment,
            "la copie de ton adversaire n’a pas été attendue jusqu’au bout",
            mine.source
        )
    case .expired:
        return unsettledVerdict(mine.assessment, "le serveur ne connaît plus ce défi", mine.source)
    case .settled(let opponent, let reason, let elo):
        return settledVerdict(mine: mine, opponent: opponent, reason: reason, elo: elo)
    }
}

/// Verdict d'un défi arbitré : forfait adverse, barèmes incomparables, ou
/// comparaison des deux notes.
private func settledVerdict(
    mine: (assessment: ProductionAssessment, source: DuelVerdict.Source),
    opponent: DuelSubmission?,
    reason: String?,
    elo: EloResult?
) -> DuelVerdict {
    // Forfait : l'adversaire n'a rien rendu, mais le défi compte.
    guard let opponent else {
        var verdict = forfeitVerdict(mine.assessment, mine.source, reason)
        verdict.elo = elo
        return verdict
    }
    let theirs = ProductionAssessment(score: opponent.score, note: opponent.note)
    // Deux barèmes différents ne se comparent pas : plutôt aucun vainqueur
    // qu'un vainqueur tiré du hasard des échelles.
    guard mine.source == .ai && opponent.graded else {
        return unsettledVerdict(
            mine.assessment,
            "les deux copies n’ont pas été corrigées par la même IA",
            mine.source,
            opponent: theirs,
            opponentAnswers: opponent.answers
        )
    }
    var verdict = compareGrades(mine.assessment, theirs)
    verdict.opponentAnswers = opponent.answers
    verdict.elo = elo
    return verdict
}

/// Rend le verdict d'un défi contre un joueur réel (`judgeDuel`). Seule la
/// copie du joueur est notée ici, et c'est sa note qui va à la rencontre de
/// l'autre. Lève `DuelQuotaError` lorsque le quota de correction est épuisé.
/// Les ajustements liés à un exercice déjà commencé ne s'appliquent pas en
/// v1 : l'app n'envoie pas d'historique d'exercices.
func judgeDuel(
    match: MatchView,
    subject: String,
    exercise: DuelExercise,
    myProduction: String,
    answers: [String: String],
    userId: String,
    token: String,
    onWaitingForOpponent: ((Double) -> Void)? = nil
) async throws -> DuelVerdict {
    // Les deux copies d'un même défi partagent la même clé de quota.
    let mine = try await gradeCopy(
        subject: subject,
        exercise: exercise,
        production: myProduction,
        durationMinutes: match.durationMinutes,
        operationKey: "duel:\(match.id)",
        token: token
    )
    return await settleAgainstPlayer(
        match: match,
        userId: userId,
        token: token,
        mine: mine,
        answers: answers,
        onWaitingForOpponent: onWaitingForOpponent
    )
}
