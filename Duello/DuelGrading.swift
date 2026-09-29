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

/// Applique ensemble les deux compensations liées à l'historique de l'exercice
/// (`applyDuelScoreAdjustments` de `duel.ts`). Les calculer en une fois évite un
/// effet de bord aux bornes : si les deux joueurs connaissaient déjà l'exercice,
/// bonus et pénalité s'annulent exactement, même pour une copie notée 0 ou 100.
private func adjustScore(
    _ assessment: ProductionAssessment,
    penalty: Int,
    bonus: Int
) -> ProductionAssessment {
    let penalty = max(0, penalty)
    let bonus = max(0, bonus)
    if penalty == 0 && bonus == 0 { return assessment }
    let trimmed = assessment.note
        .trimmingCharacters(in: .whitespaces)
        .replacingOccurrences(of: #"\.*$"#, with: "", options: .regularExpression)
    var notes = [trimmed]
    if penalty > 0 { notes.append("Exercice déjà commencé : pénalité de \(penalty) points") }
    if bonus > 0 { notes.append("Adversaire déjà familiarisé avec l’exercice : bonus de \(bonus) points") }
    return ProductionAssessment(
        score: min(100, max(0, assessment.score - penalty + bonus)),
        note: notes.filter { !$0.isEmpty }.joined(separator: ". ") + "."
    )
}

/// `evaluateDuel` : les deux copies sont notées au barème local (l'une des deux
/// au moins n'a pas été notée par l'IA), départagées avec la zone d'égalité de
/// quatre points (`DRAW_MARGIN`) — le barème local ne mesure que des indices de
/// rigueur, deux ou trois points d'écart n'y veulent rien dire.
private func localTrainingVerdict(
    rawMine: ProductionAssessment,
    mine: ProductionAssessment,
    theirs: ProductionAssessment
) -> DuelVerdict {
    let diff = mine.score - theirs.score
    let outcome: DuelVerdict.Outcome = abs(diff) <= 4 ? .draw : (diff > 0 ? .me : .opponent)
    let lead: String
    let justification: String
    switch outcome {
    case .draw:
        lead = "Les deux réponses se valent"
        justification = "les deux copies sont au même niveau"
    case .me:
        lead = "Ta réponse l’emporte"
        justification = "raisonnement jugé plus complet et mieux justifié"
    case .opponent:
        lead = "L’adversaire l’emporte"
        justification = "sa réponse a été jugée plus rigoureuse"
    }
    let scores = outcome == .opponent
        ? "\(theirs.score) contre \(mine.score)"
        : "\(mine.score) contre \(theirs.score)"
    return DuelVerdict(
        outcome: outcome,
        won: outcome == .me,
        summary: "\(lead) (\(scores)) : \(justification).",
        me: mine,
        unadjustedMeScore: rawMine.score,
        opponent: theirs,
        opponentAnswers: nil,
        source: .local,
        ranked: true,
        elo: nil
    )
}

/// Rend le verdict d'un défi contre l'adversaire d'entraînement
/// (`match.opponent.training`, `duelJudge.ts:385`) : les deux copies sont sur ce
/// téléphone et partent à la notation côte à côte, puis sont comparées — aucune
/// copie ne monte au serveur des défis. La copie d'en face vient de
/// `exercise.opponentProduction` côté RN ; le port la reçoit par paramètre (le
/// champ n'est pas encore sur `DuelExercise`, cf. « À raccorder »).
private func judgeTrainingDuel(
    match: MatchView,
    subject: String,
    exercise: DuelExercise,
    myProduction: String,
    opponentProduction: String,
    opponentAnswers: [String: String]?,
    penalty: Int,
    bonus: Int,
    token: String
) async throws -> DuelVerdict {
    let operationKey = "duel:\(match.id)"
    async let mineCopy = gradeCopy(
        subject: subject, exercise: exercise, production: myProduction,
        durationMinutes: match.durationMinutes, operationKey: operationKey, token: token
    )
    async let theirCopy = gradeCopy(
        subject: subject, exercise: exercise, production: opponentProduction,
        durationMinutes: match.durationMinutes, operationKey: operationKey, token: token
    )
    let (rawMine, theirs) = try await (mineCopy, theirCopy)
    let mine = adjustScore(rawMine.assessment, penalty: penalty, bonus: bonus)
    let trimmedOpponent = opponentProduction.trimmingCharacters(in: .whitespacesAndNewlines)
    var revealed = opponentAnswers
    if revealed == nil, exercise.questions.count == 1, !trimmedOpponent.isEmpty,
       let question = exercise.questions.first {
        revealed = [question.id: trimmedOpponent]
    }
    if rawMine.source == .ai && theirs.source == .ai {
        var verdict = compareGrades(mine, theirs.assessment)
        verdict.unadjustedMeScore = rawMine.assessment.score
        verdict.opponentAnswers = revealed
        return verdict
    }
    var verdict = localTrainingVerdict(
        rawMine: rawMine.assessment, mine: mine, theirs: theirs.assessment
    )
    verdict.opponentAnswers = revealed
    return verdict
}

/// Rend le verdict d'un défi (`judgeDuel`). Contre un joueur réel, seule la
/// copie du joueur est notée ici, et c'est sa note qui va à la rencontre de
/// l'autre ; contre l'adversaire d'entraînement, les deux copies partent à la
/// notation côte à côte (`judgeTrainingDuel`). Lève `DuelQuotaError` lorsque le
/// quota de correction est épuisé. `scorePenalty`/`scoreBonus` portent les
/// ajustements d'un exercice déjà commencé (`applyDuelScoreAdjustments`).
func judgeDuel(
    match: MatchView,
    subject: String,
    exercise: DuelExercise,
    myProduction: String,
    answers: [String: String],
    userId: String,
    token: String,
    scorePenalty: Int = 0,
    scoreBonus: Int = 0,
    opponentProduction: String? = nil,
    opponentAnswers: [String: String]? = nil,
    onWaitingForOpponent: ((Double) -> Void)? = nil
) async throws -> DuelVerdict {
    // Réserve la correction de ce défi **avant** toute notation
    // (`quota.reserve('duel:<matchId>')` → `POST /correction-quota`). Un quota
    // épuisé est un refus produit : la copie reste rédigée, l'offre Premium est
    // à proposer.
    if case .paywall = try await ChalAPI.reserveCorrectionQuota(
        userId: userId,
        operationKey: "duel:\(match.id)",
        token: token
    ) {
        throw DuelQuotaError(
            message: "Ton quota de défis est épuisé. Ouvre l’onglet Défis pour voir la prochaine recharge ou l’offre Premium.",
            nextFreeAt: nil
        )
    }
    // Adversaire d'entraînement : les deux copies partent côte à côte. Le port
    // n'active la branche que si la copie d'en face est fournie (le champ n'est
    // pas encore porté) ; sinon il retombe sur le chemin serveur, sans régression.
    if match.opponent.training == true, let opponentProduction {
        return try await judgeTrainingDuel(
            match: match, subject: subject, exercise: exercise,
            myProduction: myProduction, opponentProduction: opponentProduction,
            opponentAnswers: opponentAnswers,
            penalty: scorePenalty, bonus: scoreBonus, token: token
        )
    }
    // Les deux copies d'un même défi partagent la même clé de quota.
    let rawMine = try await gradeCopy(
        subject: subject, exercise: exercise, production: myProduction,
        durationMinutes: match.durationMinutes, operationKey: "duel:\(match.id)",
        token: token
    )
    let mine = (
        assessment: adjustScore(rawMine.assessment, penalty: scorePenalty, bonus: scoreBonus),
        source: rawMine.source
    )
    var verdict = await settleAgainstPlayer(
        match: match, userId: userId, token: token, mine: mine,
        answers: answers, onWaitingForOpponent: onWaitingForOpponent
    )
    verdict.unadjustedMeScore = rawMine.assessment.score
    return verdict
}
