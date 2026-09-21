import Foundation

// MARK: - Verdict

/// Verdict d'un défi, rendu après notation des deux copies (`DuelVerdict`).
struct DuelVerdict {
    enum Outcome: String { case me, opponent, draw }
    /// D'où vient le verdict : la correction de l'IA, ou le barème local.
    enum Source: String { case ai, local }

    var outcome: Outcome
    /// Vrai seulement si l'utilisateur l'emporte, pour créditer le bonus d'XP.
    var won: Bool
    /// Phrase de synthèse.
    var summary: String
    var me: ProductionAssessment
    /// Note de la copie avant les ajustements liés à l'historique.
    var unadjustedMeScore: Int
    /// Note de l'adversaire, absente seulement si sa copie n'est jamais arrivée.
    var opponent: ProductionAssessment?
    /// Réponses adverses visibles après le défi, une fois les deux copies rendues.
    var opponentAnswers: [String: String]?
    var source: Source
    /// Le défi compte pour la cote : faux quand les copies n'ont pas été
    /// notées au même barème.
    var ranked: Bool
    /// Présent lorsque PostgreSQL a arbitré la cote.
    var elo: EloResult?
}

private func inlineJustification(_ justification: String) -> String {
    let trimmed = justification.trimmingCharacters(in: .whitespaces)
        .replacingOccurrences(of: #"\.+$"#, with: "", options: .regularExpression)
    var iterator = trimmed.makeIterator()
    let first = iterator.next()
    let second = iterator.next()
    // Le commentaire est une phrase à part entière : sa majuscule initiale
    // n'a plus lieu d'être une fois enchaînée après deux points. Deux
    // capitales de suite trahissent en revanche un sigle, qu'on laisse intact.
    guard let first else { return trimmed }
    if let second, second.isUppercase && second.isLetter {
        return trimmed
    }
    return first.lowercased() + trimmed.dropFirst()
}

private func buildSummary(_ outcome: DuelVerdict.Outcome, _ mine: Int, _ theirs: Int, _ justification: String) -> String {
    let scores = outcome == .opponent ? "\(theirs) contre \(mine)" : "\(mine) contre \(theirs)"
    let verdict: String
    switch outcome {
    case .draw: verdict = "Les deux réponses se valent (\(scores))"
    case .me: verdict = "Ta réponse l’emporte (\(scores))"
    case .opponent: verdict = "L’adversaire l’emporte (\(scores))"
    }
    return "\(verdict) : \(inlineJustification(justification))."
}

/// Écart de points, converti en issue du défi.
private func outcomeFromScores(_ mine: Int, _ theirs: Int, _ margin: Int) -> DuelVerdict.Outcome {
    let diff = mine - theirs
    if abs(diff) <= margin { return .draw }
    return diff > 0 ? .me : .opponent
}

/// Départage deux copies notées chacune de son côté : la plus haute note
/// gagne (`compareGrades`). Aucune tolérance : à barème égal, un point
/// d'écart est un point gagné.
func compareGrades(_ mine: ProductionAssessment, _ theirs: ProductionAssessment) -> DuelVerdict {
    let outcome = outcomeFromScores(mine.score, theirs.score, 0)
    // La raison affichée est le commentaire de la copie qui l'emporte — et
    // celui du joueur en cas d'égalité, puisque c'est la copie qui l'intéresse.
    let justification = outcome == .opponent ? theirs.note : mine.note
    return DuelVerdict(
        outcome: outcome,
        won: outcome == .me,
        summary: buildSummary(outcome, mine.score, theirs.score, justification),
        me: mine,
        unadjustedMeScore: mine.score,
        opponent: theirs,
        opponentAnswers: nil,
        source: .ai,
        ranked: true,
        elo: nil
    )
}

/// Défi resté sans comparaison possible : la copie d'en face n'est pas
/// arrivée, ou n'a pas été notée par le même correcteur (`unsettledVerdict`).
func unsettledVerdict(
    _ mine: ProductionAssessment,
    _ reason: String,
    _ source: DuelVerdict.Source,
    opponent: ProductionAssessment? = nil,
    opponentAnswers: [String: String]? = nil
) -> DuelVerdict {
    DuelVerdict(
        outcome: .draw,
        won: false,
        summary: "Défi non arbitré : \(reason.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: #"\.+$"#, with: "", options: .regularExpression)). Ta copie obtient \(mine.score)/100.",
        me: mine,
        unadjustedMeScore: mine.score,
        opponent: opponent,
        opponentAnswers: opponentAnswers,
        source: source,
        ranked: false,
        elo: nil
    )
}

/// Défi remporté par forfait : l'adversaire n'a pas rendu sa copie à temps.
func forfeitVerdict(_ mine: ProductionAssessment, _ source: DuelVerdict.Source, _ reason: String?) -> DuelVerdict {
    DuelVerdict(
        outcome: .me,
        won: true,
        summary: reason == "opponent_abandoned"
            ? "Ton adversaire a abandonné : tu remportes immédiatement le défi avec \(mine.score)/100."
            : "Ton adversaire n’a pas rendu sa copie : tu l’emportes avec \(mine.score)/100.",
        me: mine,
        unadjustedMeScore: mine.score,
        opponent: ProductionAssessment(score: 0, note: "Copie non rendue avant la fin du temps imparti."),
        opponentAnswers: nil,
        source: source,
        ranked: true,
        elo: nil
    )
}
