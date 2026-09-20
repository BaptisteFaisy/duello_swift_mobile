import Foundation

// MARK: - Exercice de défi

/// Énoncé résolu depuis la banque, pour le tirage d'un défi
/// (`ChallengeExerciseEntry` de `utils/duel.ts`).
struct ChallengeExerciseEntry {
    var id: String
    var title: String
    /// Énoncé retranscrit, seul jouable dans le temps d'un défi.
    var statement: String?
    /// Corrigé texte de référence, lorsqu'il est déjà relié à l'exercice.
    var solution: String?
    /// Sous-questions repérées dans l'énoncé, lorsqu'il les numérote lui-même.
    var questions: [(id: String, label: String?)]?
}

/// Énoncé de défi mis en forme pour l'écran et le correcteur
/// (`DuelExercise` de `data/duelExercises.ts`).
struct DuelExercise {
    struct Question {
        var id: String
        /// Texte de la question, lorsqu'il n'est pas déjà dans l'énoncé.
        var prompt: String?
        /// Repère affiché (« 1. », « a) ») quand l'énoncé numérote lui-même.
        var label: String?
    }

    var id: String
    /// Matière, telle qu'affichée dans les réglages du défi.
    var subject: String
    /// Mise en situation commune, posée avant les questions.
    var context: String?
    /// Questions de l'exo, dans l'ordre : chacune ouvre son champ de réponse.
    var questions: [Question]
    /// Corrigé de référence, dévoilé aux deux joueurs après le défi.
    var solution: String?
}

/// Repère affiché pour une question : celui de l'énoncé quand le sujet
/// numérote lui-même ses questions, sinon sa place dans l'exo.
func duelQuestionLabel(_ question: DuelExercise.Question?, _ index: Int) -> String {
    question?.label ?? String(index + 1)
}

/// Convertit un énoncé de la banque en énoncé de défi
/// (`chapterItemAsDuelExercise`). L'énoncé retranscrit devient la mise en
/// situation ; à défaut de sous-question repérée, un champ unique reçoit
/// toute la copie.
func chapterItemAsDuelExercise(_ item: ChallengeExerciseEntry, _ subject: String) -> DuelExercise {
    DuelExercise(
        id: item.id,
        subject: subject,
        context: (item.statement?.trimmingCharacters(in: .whitespacesAndNewlines)).map { $0.isEmpty ? item.title : $0 } ?? item.title,
        questions: {
            if let questions = item.questions, !questions.isEmpty {
                return questions.map { DuelExercise.Question(id: $0.id, label: $0.label, prompt: nil) }
            }
            return [DuelExercise.Question(id: "resolution", label: nil, prompt: nil)]
        }(),
        solution: (item.solution?.trimmingCharacters(in: .whitespacesAndNewlines)).map { $0.isEmpty ? nil : $0 } ?? nil
    )
}

/// Énoncé complet de l'exo : la mise en situation, puis les questions
/// numérotées (`duelExercisePrompt`). C'est ce texte que le correcteur reçoit.
/// Un exo d'une seule question n'est pas numéroté.
func duelExercisePrompt(_ exercise: DuelExercise) -> String {
    // Un sujet qui pose ses questions dans son énoncé même ne les répète pas.
    if exercise.questions.allSatisfy({ ($0.prompt ?? "").isEmpty }) {
        return exercise.context ?? ""
    }
    let body: String
    if exercise.questions.count <= 1 {
        body = exercise.questions.first?.prompt ?? ""
    } else {
        body = exercise.questions.enumerated()
            .map { (index, question) in "\(duelQuestionLabel(question, index)). \(question.prompt ?? "")" }
            .joined(separator: "\n")
    }
    if let context = exercise.context, !context.isEmpty {
        return "\(context)\n\(body)"
    }
    return body
}

/// Rassemble les champs d'une copie en un seul texte, celui que le correcteur
/// lit (`joinDuelAnswers`). Chaque réponse garde le numéro de sa question.
func joinDuelAnswers(_ exercise: DuelExercise, _ answers: [String: String]) -> String {
    let written = exercise.questions.enumerated().compactMap { (index, question) -> (label: String, answer: String)? in
        let answer = (answers[question.id] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !answer.isEmpty else { return nil }
        return (duelQuestionLabel(question, index), answer)
    }
    // Un exo d'une seule question n'a rien à numéroter : sa copie est la réponse.
    if exercise.questions.count <= 1 {
        return written.first?.answer ?? ""
    }
    return written.map { "\($0.label). \($0.answer)" }.joined(separator: "\n\n")
}

/// Ne conserve que les réponses effectivement rédigées (`attemptedDuelAnswers`).
func attemptedDuelAnswers(_ exercise: DuelExercise, _ answers: [String: String]) -> [String: String] {
    var result: [String: String] = [:]
    for question in exercise.questions {
        let answer = (answers[question.id] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !answer.isEmpty { result[question.id] = answer }
    }
    return result
}

// MARK: - Garde-fou « énoncé recopié » (port de duelCopyPolicy.ts)

/// Garde-fou commun à l'app et au relais : une recopie de l'énoncé vaut zéro,
/// quel que soit le correcteur. Sans contenu distinct de l'énoncé, il n'y a
/// rien à noter.
private enum DuelCopyPolicy {
    static let statementOnlyNote =
        "Énoncé recopié : aucun raisonnement personnel n’a été fourni."

    /// Ramène prose et formules à des jetons comparables, sans dépendre d'Intl.
    private static func canonicalTokens(_ text: String) -> [String] {
        // Décomposition de compatibilité (NFKD) d'abord : `²` doit rejoindre
        // les chiffres, comme dans la normalisation JS d'origine.
        let deaccented = text.decomposedStringWithCompatibilityMapping
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "fr_FR"))
            .replacingOccurrences(of: "≤", with: " <= ")
            .replacingOccurrences(of: "⩽", with: " <= ")
            .replacingOccurrences(of: "≥", with: " >= ")
            .replacingOccurrences(of: "⩾", with: " >= ")
            .replacingOccurrences(of: "≠", with: " != ")
        // `\p{L}` Unicode : lettres accentuées déjà neutralisées ci-dessus.
        let matches = matches(of: "[a-z0-9]+|<=|>=|!=|[=+\\-*/^<>]", in: deaccented)
        return matches
    }

    private static func matches(of pattern: String, in text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, range: range).compactMap { Range($0.range, in: text).map { String(text[$0]) } }
    }

    /// Cherche une réponse recopiée comme fragment continu de l'énoncé.
    private static func containsTokenSequence(_ statement: [String], _ answer: [String]) -> Bool {
        if answer.count > statement.count { return false }
        let statementKey = "\u{0}" + statement.joined(separator: "\u{0}") + "\u{0}"
        let answerKey = "\u{0}" + answer.joined(separator: "\u{0}") + "\u{0}"
        return statementKey.contains(answerKey)
    }

    /// Nombre de jetons de la réponse déjà disponibles dans l'énoncé.
    private static func statementTokenOverlap(_ statement: [String], _ answer: [String]) -> Int {
        var remaining: [String: Int] = [:]
        for token in statement { remaining[token, default: 0] += 1 }
        var overlap = 0
        for token in answer {
            if let count = remaining[token], count > 0 {
                overlap += 1
                remaining[token] = count - 1
            }
        }
        return overlap
    }

    /// Part des trigrammes de la réponse qui viennent tels quels de l'énoncé.
    private static func copiedTrigramRatio(_ statement: [String], _ answer: [String]) -> Double {
        if answer.count < 3 { return 0 }
        var statementTrigrams = Set<String>()
        if statement.count >= 3 {
            for index in 0...(statement.count - 3) {
                statementTrigrams.insert(statement[index..<index + 3].joined(separator: "\u{0}"))
            }
        }
        var copied = 0
        let total = answer.count - 2
        if total > 0 {
            for index in 0...total where answer.count >= index + 3 {
                if statementTrigrams.contains(answer[index..<index + 3].joined(separator: "\u{0}")) {
                    copied += 1
                }
            }
        }
        return Double(copied) / Double(total)
    }

    /// Détecte une copie qui ne fait que reprendre l'énoncé.
    static func isStatementOnlyAnswer(_ statement: String, _ answer: String) -> Bool {
        let statementTokens = canonicalTokens(statement)
        let answerTokens = canonicalTokens(answer)
        if statementTokens.isEmpty || answerTokens.isEmpty { return false }
        if statementTokens.joined(separator: " ") == answerTokens.joined(separator: " ") { return true }
        if answerTokens.count >= 2 && containsTokenSequence(statementTokens, answerTokens) { return true }
        if answerTokens.count < 5 { return false }
        let overlap = statementTokenOverlap(statementTokens, answerTokens)
        let novelTokens = answerTokens.count - overlap
        return novelTokens <= 4
            && Double(overlap) / Double(answerTokens.count) >= 0.8
            && copiedTrigramRatio(statementTokens, answerTokens) >= 0.65
    }

    /// Rend le zéro imposé par la politique, ou laisse la copie au correcteur.
    static func deterministicStatementGrade(_ statement: String, _ answer: String) -> ProductionAssessment? {
        isStatementOnlyAnswer(statement, answer)
            ? ProductionAssessment(score: 0, note: statementOnlyNote)
            : nil
    }
}

// MARK: - Barème local de secours (port de scoreProduction, duel.ts)

/// Note une réponse sur 100 à partir de ce qu'elle contient : travail engagé,
/// justifications, structure, avancement et rigueur technique. Ce barème de
/// secours ne vérifie pas la vérité mathématique : il mesure des indices.
private enum LocalRubric {
    private static let connectors = [
        "car", "donc", "puisque", "ainsi", "soit", "on a", "comme", "d'où",
        "par suite", "en effet", "because", "therefore", "however",
    ]
    private static let conclusionMarkers = [
        "donc", "conclusion", "finalement", "on conclut", "on trouve",
        "la limite", "réponse", "to conclude", "in conclusion",
    ]
    private static let technicalTokens = [
        "=", "≤", "≥", "∫", "√", "→", "%", "∈", "π", "ω", "ξ", "τ", "²", "def ",
    ]

    /// Longueur d'une copie qui a vraiment traité quelque chose.
    private static let workedLength = 200
    /// Au-delà, l'avancement est plein.
    private static let progressLength = 400

    private static func distinctMatches(_ haystack: String, _ needles: [String]) -> Int {
        needles.filter { haystack.contains($0) }.count
    }

    /// Nombre d'étapes distinctes : sauts de ligne et fins de phrase.
    private static func stepCount(_ text: String) -> Int {
        let breaks = text.components(separatedBy: "\n").count - 1
        let sentences = matches(of: "[.;:][^.;:]", in: text).count
        return breaks + sentences
    }

    private static func matches(of pattern: String, in text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, range: range).compactMap { Range($0.range, in: text).map { String(text[$0]) } }
    }

    static func scoreProduction(_ production: String) -> Int {
        let text = production.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty { return 0 }

        let lower = text.lowercased()
        let connectorCount = distinctMatches(lower, connectors)
        let steps = stepCount(text)
        let hasConclusion = conclusionMarkers.contains { lower.contains($0) }
        let technical = distinctMatches(text, technicalTokens)

        let workScore = Double(min(Double(text.count) / Double(workedLength), 1)) * 28
        let progressScore = Double(min(max(Double(text.count - workedLength), 0) / Double(progressLength), 1)) * 12
        let connectorScore = Double(min(Double(connectorCount) / 4, 1)) * 24
        let structureScore = Double(min(Double(steps) / 4, 1)) * 14
        let conclusionScore: Double = hasConclusion ? 8 : 0
        let technicalScore = Double(min(Double(technical) / 4, 1)) * 14

        return Int((workScore + progressScore + connectorScore + structureScore + conclusionScore + technicalScore).rounded())
    }

    /// Commentaire court : le point le plus saillant de la réponse.
    private static func assess(score: Int, length: Int, connectors: Int, hasConclusion: Bool) -> String {
        if length == 0 { return "Aucune réponse rendue." }
        if score >= 78 {
            return "Beaucoup de terrain couvert dans le temps imparti, avec des étapes justifiées."
        }
        if length < 80 {
            return "Copie à peine amorcée : les premières étapes du raisonnement manquent."
        }
        if connectors < 2 {
            return "Résultats présents mais peu justifiés : les étapes manquent de liens logiques."
        }
        if !hasConclusion {
            return "Raisonnement bien engagé ; noter le résultat partiel atteint aurait valorisé la copie."
        }
        return "Copie solide pour le temps imparti, encore perfectible sur la rigueur."
    }

    /// Note une copie sans réseau, sur des indices de rigueur.
    static func gradeLocally(_ production: String, _ statement: String?) -> ProductionAssessment {
        if let statement, let deterministic = DuelCopyPolicy.deterministicStatementGrade(statement, production) {
            return deterministic
        }
        let text = production.trimmingCharacters(in: .whitespacesAndNewlines)
        let score = scoreProduction(text)
        let connectorCount = distinctMatches(text.lowercased(), connectors)
        let hasConclusion = conclusionMarkers.contains { text.lowercased().contains($0) }
        return ProductionAssessment(
            score: score,
            note: assess(score: score, length: text.count, connectors: connectorCount, hasConclusion: hasConclusion)
        )
    }
}

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
private func forfeitVerdict(_ mine: ProductionAssessment, _ source: DuelVerdict.Source, _ reason: String?) -> DuelVerdict {
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
    let graded = mine.source == .ai
    var state: DuelResultState
    do {
        state = try await DuelloAPI.submitDuelGrade(
            matchId: match.id,
            userId: userId,
            grade: DuelSubmission(
                score: mine.assessment.score,
                note: mine.assessment.note,
                graded: graded,
                answers: answers
            ),
            token: token
        )
    } catch {
        return unsettledVerdict(mine.assessment, "le serveur des défis est injoignable", mine.source)
    }

    if case .waiting(let deadline) = state {
        onWaitingForOpponent?(deadline)
        if let awaited = await waitForOpponent(
            matchId: match.id, userId: userId, deadline: deadline, token: token
        ) {
            state = awaited
        } else {
            return unsettledVerdict(
                mine.assessment,
                "la copie de ton adversaire n’a pas été attendue jusqu’au bout",
                mine.source
            )
        }
    }

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
        // Forfait : l'adversaire n'a rien rendu, mais le défi compte.
        guard let opponent else {
            var verdict = forfeitVerdict(mine.assessment, mine.source, reason)
            verdict.elo = elo
            return verdict
        }
        let theirs = ProductionAssessment(score: opponent.score, note: opponent.note)
        // Deux barèmes différents ne se comparent pas : plutôt aucun vainqueur
        // qu'un vainqueur tiré du hasard des échelles.
        guard graded && opponent.graded else {
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

