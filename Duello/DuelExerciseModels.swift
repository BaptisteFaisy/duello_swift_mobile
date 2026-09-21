import Foundation

// MARK: - Énoncé de défi : modèles et mise en forme (port de utils/duel.ts)

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
                return questions.map { DuelExercise.Question(id: $0.id, prompt: nil, label: $0.label) }
            }
            return [DuelExercise.Question(id: "resolution", prompt: nil, label: nil)]
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
