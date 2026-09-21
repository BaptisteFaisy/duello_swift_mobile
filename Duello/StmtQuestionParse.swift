import Foundation

/// Découpage d'un énoncé retranscrit en questions numérotées — port de
/// `src/utils/statementQuestions.ts`.
///
/// Les sujets de colles et les feuilles d'exercices numérotent leurs questions
/// en tête de ligne (« 1. », « 2) », « a) », « (b) », les lettres pouvant
/// dépendre du numéro qui les précède). Chaque question détectée reçoit son
/// propre champ de réponse dans le lecteur. Le découpage reste prudent : un
/// énoncé d'un seul bloc renvoie une liste vide.
enum StmtQuestionsParser {
    static let number = "^\\*{0,2}(\\d{1,2})\\s*(?:°\\s*[.)]?|[.)])\\*{0,2}(?=\\s|$)\\s*"
    static let bulletMarker = "^[•▪◦]\\s*"
    static let setcounter = "^\\\\setcounter\\{enumi\\}\\{(\\d{1,2})\\}\\s*$"
    static let problemeHeading = "^probl[eèê]me(?:\\s*[.:—–]|$)"
    static let exerciseHeading = "^exercice\\s+([0-9]{1,2}|[a-z])(?:\\s|[.:—–-]|$)"
    static let partieHeading = "^\\*{0,2}partie\\s+([ivxlcdm]+|[a-z]|\\d+)\\*{0,2}(?=[\\s—–:;,.!)»]|$)"
    static let questionHeading = "^question\\s+(\\d{1,2})(?![.\\s]*[a-z][).:])\\s*\\.?\\s*(.*)$"
    static let questionTitleSuffix = "^question\\s+(?!\\d)([a-zàâäéêëîïôöùûüç\\s]{2,40})$"
    static let french = Locale(identifier: "fr-FR")

    /// Question détectée pendant l'analyse, avant dédoublonnage final.
    struct Detected {
        var label: String
        var sectionId: String?
        var sectionFallback: Bool
        var prompt: String
    }

    /// État courant de l'analyse d'un énoncé.
    struct State {
        var detected: [Detected] = []
        var seen: Set<String> = []
        var currentNumber: String?
        var currentSectionId: String?
        var expectedContinuationLetter: String?
        var numericSubParent: String?
        var nextNumericSub = 1
        var letterScopeParent: String?
        var bulletsCarryNumbers = false
        var hasCompleteAlphabeticalList = false
        var followingLines: [String] = []
    }

    /// Analyse complète d'un énoncé (`parseStatementQuestionsWithPrompts`).
    static func parse(_ rawStatement: String) -> [StmtQuestion] {
        var state = State()
        let statement = StmtQuestionsParser.effectiveStatement(rawStatement)
        state.bulletsCarryNumbers = statement.contains("\\setcounter{enumi}")
        let statementLines = statement.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
        state.followingLines = StmtQuestionsParser.followingLines(statementLines)
        let unambiguous = statementLines.flatMap { line in
            StmtQuestionLetters.inlineLetterMarkers(line).filter { !StmtQuestionLetters.isFunctionArgumentMarker(line, $0) }
        }
        state.hasCompleteAlphabeticalList = StmtQuestionLetters.isCompleteAlphabeticalSet(unambiguous)
        for (lineIndex, rawLine) in statementLines.enumerated() where !rawLine.isEmpty {
            processLine(&state, rawLine, lineIndex)
        }
        return StmtQuestionsParser.finalize(state)
    }

    /// Traite une ligne : puces, en-têtes de portée, puis questions.
    static func processLine(_ state: inout State, _ rawLine: String, _ lineIndex: Int) {
        var line = rawLine
        if state.bulletsCarryNumbers {
            if let setcounter = StmtRegex.groups(setcounter, in: line) {
                state.currentNumber = setcounter[1]
                state.expectedContinuationLetter = nil
                return
            }
            if let bullet = StmtRegex.firstMatch(bulletMarker, in: line) {
                let next = state.currentNumber.flatMap { Int($0) }.map { $0 + 1 } ?? 1
                line = "\(next)) " + (line as NSString).substring(from: bullet.range.length)
            }
        }
        if state.bulletsCarryNumbers, StmtRegex.contains(problemeHeading, in: line, options: [.caseInsensitive]) {
            state.currentSectionId = "probleme"
            state.currentNumber = nil
            state.expectedContinuationLetter = nil
            state.numericSubParent = nil
            state.nextNumericSub = 1
            return
        }
        if let exercise = StmtRegex.groups(exerciseHeading, in: line, options: [.caseInsensitive]) {
            let id = "exercice-\(exercise[1].lowercased(with: french))"
            state.currentSectionId = id
            state.currentNumber = nil
            state.expectedContinuationLetter = nil
            state.numericSubParent = nil
            state.nextNumericSub = 1
            state.detected.append(Detected(label: "Ex. \(exercise[1])", sectionId: id, sectionFallback: true, prompt: line))
            return
        }
        if let partie = StmtRegex.groups(partieHeading, in: line, options: [.caseInsensitive]) {
            let partieId = "partie-\(partie[1].lowercased(with: french))"
            if let current = state.currentSectionId, current.hasPrefix("exercice-") {
                state.currentSectionId = (current.components(separatedBy: "--").first ?? current) + "--" + partieId
            } else {
                state.currentSectionId = partieId
            }
            state.currentNumber = nil
            state.expectedContinuationLetter = nil
            state.numericSubParent = nil
            state.nextNumericSub = 1
        }
        processQuestion(&state, line, lineIndex)
    }

    /// Traite les repères de question d'une ligne déjà nettoyée.
    static func processQuestion(_ state: inout State, _ line: String, _ lineIndex: Int) {
        let numbered = StmtRegex.groups(number, in: line)
        let heading = StmtRegex.groups(questionHeading, in: line, options: [.caseInsensitive])

        if heading == nil, numbered == nil, state.letterScopeParent != nil {
            if let suffix = StmtRegex.groups(questionTitleSuffix, in: line, options: [.caseInsensitive]), !state.detected.isEmpty {
                let lastIndex = state.detected.count - 1
                if state.detected[lastIndex].label == state.letterScopeParent {
                    let parent = state.letterScopeParent ?? ""
                    state.detected[lastIndex].label = "\(parent) (\(suffix[1].trimmingCharacters(in: .whitespaces)))"
                }
                return
            }
        }

        if let heading, numbered == nil {
            let rest = heading[2].trimmingCharacters(in: .whitespaces)
            let headingLabel = rest.isEmpty
                ? heading[1]
                : "\(heading[1]) (\(StmtRegex.replaceAll("[.\\s]+$", in: heading[2], options: [.caseInsensitive], template: "")))"
            state.expectedContinuationLetter = nil
            state.currentNumber = nil
            state.numericSubParent = nil
            state.nextNumericSub = 1
            let following = lineIndex < state.followingLines.count ? state.followingLines[lineIndex] : ""
            let headingPrompt = rest.isEmpty ? following : rest
            state.letterScopeParent = StmtQuestionsParser.addLabel(
                &state,
                headingLabel,
                StmtRegex.replaceAll("\\.+\\s*$", in: headingPrompt, options: [.caseInsensitive], template: "")
            )
            return
        }

        if let numbered, state.numericSubParent != nil, handleNumericSubQuestion(&state, line, lineIndex, numbered) {
            return
        }

        if let numbered {
            if state.currentNumber != numbered[1] { state.expectedContinuationLetter = nil }
            state.currentNumber = numbered[1]
            state.letterScopeParent = nil
        }

        if StmtQuestionsParser.isColonIntroducer(line), state.currentNumber != nil {
            state.numericSubParent = state.currentNumber
            state.nextNumericSub = 1
        }

        if handleInlineLetters(&state, line, lineIndex, numbered) { return }

        if let numbered {
            let inlinePrompt = (line as NSString).substring(from: (numbered[0] as NSString).length)
                .trimmingCharacters(in: .whitespaces)
            if StmtQuestionsParser.hasQuestionContent(line, numbered[0]) {
                _ = StmtQuestionsParser.addLabel(&state, numbered[1], inlinePrompt)
            } else if inlinePrompt.isEmpty, lineIndex < state.followingLines.count, !state.followingLines[lineIndex].isEmpty {
                _ = StmtQuestionsParser.addLabel(&state, numbered[1], state.followingLines[lineIndex])
            }
        }
    }

    /// Sous-liste numérique « 1., 2. » rattachée à un parent introduit par « : ».
    static func handleNumericSubQuestion(_ state: inout State, _ line: String, _ lineIndex: Int, _ numbered: [String]) -> Bool {
        guard let parent = state.numericSubParent, let parentVal = Int(parent), let subNumVal = Int(numbered[1]) else {
            return false
        }
        if subNumVal == state.nextNumericSub, subNumVal != parentVal + 1 {
            let inlinePrompt = (line as NSString).substring(from: (numbered[0] as NSString).length)
                .trimmingCharacters(in: .whitespaces)
            let following = lineIndex < state.followingLines.count ? state.followingLines[lineIndex] : ""
            let prompt = !inlinePrompt.isEmpty ? inlinePrompt : following
            if !prompt.isEmpty, !StmtRegex.contains("^[.,;:!?…]+$", in: prompt) {
                _ = StmtQuestionsParser.addLabel(&state, "\(parent).\(numbered[1])", prompt)
            } else if StmtQuestionsParser.hasQuestionContent(line, numbered[0]) {
                _ = StmtQuestionsParser.addLabel(&state, "\(parent).\(numbered[1])", inlinePrompt)
            }
            state.nextNumericSub += 1
            return true
        }
        state.numericSubParent = nil
        state.nextNumericSub = 1
        return false
    }

    /// Repères alphabétiques alignés sur une ligne (sous-questions).
    static func handleInlineLetters(_ state: inout State, _ line: String, _ lineIndex: Int, _ numbered: [String]?) -> Bool {
        let markers = StmtQuestionLetters.inlineLetterMarkers(line)
        let unambiguous = markers.filter { !StmtQuestionLetters.isFunctionArgumentMarker(line, $0) }
        guard let first = unambiguous.first else { return false }

        let legacyRange = first.letter <= "h"
        let startsLine = first.start == 0
            && (legacyRange || state.hasCompleteAlphabeticalList || first.letter == state.expectedContinuationLetter)
        let numberedLength = numbered.map { ($0[0] as NSString).length } ?? 0
        let between = numbered != nil
            ? (line as NSString).substring(with: NSRange(location: numberedLength, length: first.start - numberedLength))
            : ""
        let startsNumberBody = numbered != nil && between.trimmingCharacters(in: .whitespaces).isEmpty
            && (legacyRange || state.hasCompleteAlphabeticalList || first.letter == state.expectedContinuationLetter)
        let followsPunctuation = numbered != nil && StmtRegex.contains("[:;,.!?…—–-]\\s*$", in: between)
        let continuesSequence = state.expectedContinuationLetter != nil && first.letter == state.expectedContinuationLetter
        let localSequence = StmtQuestionLetters.areConsecutiveLetterMarkers(unambiguous)
        let strongSignal = startsLine || startsNumberBody || continuesSequence || state.hasCompleteAlphabeticalList
            || (numbered != nil && localSequence && (!first.parenthesized || followsPunctuation))

        if !strongSignal { return false }
        let startsWithUnambiguous = markers.first?.start == first.start
        let selected: [StmtInlineLetterMarker]
        if startsWithUnambiguous, StmtQuestionLetters.areConsecutiveLetterMarkers(markers) {
            selected = markers
        } else if state.hasCompleteAlphabeticalList || localSequence {
            selected = unambiguous
        } else {
            selected = [first]
        }
        StmtQuestionsParser.addInlineLetters(
            &state,
            line,
            selected,
            lineIndex < state.followingLines.count ? state.followingLines[lineIndex] : ""
        )
        state.expectedContinuationLetter = selected.last.flatMap { StmtQuestionLetters.nextScalar($0.letter) }
        return true
    }
}
