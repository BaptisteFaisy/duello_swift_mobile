import Foundation

/// Aides de l'analyse des questions — port de `src/utils/statementQuestions.ts`.
extension StmtQuestionsParser {
    /// Énoncé utile : coupe avant « Corrigés détaillés » collé au sujet.
    static func effectiveStatement(_ statement: String) -> String {
        if let match = StmtRegex.firstMatch("\\n\\s*Corrig[ée]s\\s+d[ée]taill[ée]s\\b", in: statement, options: [.caseInsensitive]) {
            return StmtLayoutFlat.trailingTrim((statement as NSString).substring(to: match.range.location))
        }
        return statement
    }

    /// Vrai si la ligne se termine par « : » et introduit une sous-liste.
    static func isColonIntroducer(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if !StmtRegex.contains(":\\s*$", in: trimmed) { return false }
        if StmtRegex.contains(number, in: trimmed) { return true }
        let without = StmtRegex.replaceAll(":\\s*$", in: trimmed, template: "").trimmingCharacters(in: .whitespaces)
        let words = StmtRegex.split("\\s+", in: without).filter { !$0.isEmpty }
        return words.count <= 4 && trimmed.count <= 60
    }

    /// Vrai si le repère introduit du contenu (pas seulement de la ponctuation).
    static func hasQuestionContent(_ line: String, _ marker: String) -> Bool {
        let content = (line as NSString).substring(from: (marker as NSString).length)
            .trimmingCharacters(in: .whitespaces)
        return !content.isEmpty && !StmtRegex.contains("^[.,;:!?…]+$", in: content)
    }

    /// Pour chaque ligne, la première ligne non vide qui la suit.
    static func followingLines(_ lines: [String]) -> [String] {
        var result = [String](repeating: "", count: lines.count)
        var following = ""
        var index = lines.count - 1
        while index >= 0 {
            result[index] = following
            if !lines[index].isEmpty { following = lines[index] }
            index -= 1
        }
        return result
    }

    /// Ajoute une question détectée, dédoublonnée par portée.
    static func addLabel(_ state: inout State, _ rawLabel: String, _ prompt: String) -> String {
        let scopedId = "\(state.currentSectionId ?? ""):\(rawLabel)"
        if state.seen.contains(scopedId) { return rawLabel }
        state.seen.insert(scopedId)
        state.detected.append(Detected(label: rawLabel, sectionId: state.currentSectionId, sectionFallback: false, prompt: prompt))
        return rawLabel
    }

    /// Ajoute les sous-questions d'une ligne à repères alphabétiques alignés.
    static func addInlineLetters(
        _ state: inout State,
        _ line: String,
        _ markers: [StmtInlineLetterMarker],
        _ followingLine: String
    ) {
        let source = line as NSString
        for (index, marker) in markers.enumerated() {
            let end = index + 1 < markers.count ? markers[index + 1].start : source.length
            let inlinePrompt = source.substring(with: NSRange(location: marker.end, length: end - marker.end))
                .trimmingCharacters(in: .whitespaces)
            let prompt = !inlinePrompt.isEmpty ? inlinePrompt : (index == markers.count - 1 ? followingLine : "")
            if prompt.isEmpty || StmtRegex.contains("^[.,;:!?…]+$", in: prompt) { continue }
            let label: String
            if let currentNumber = state.currentNumber {
                label = "\(currentNumber).\(marker.letter)"
            } else if let scope = state.letterScopeParent {
                label = "\(scope).\(marker.letter)"
            } else {
                label = marker.letter
            }
            _ = addLabel(&state, label, prompt)
        }
    }

    /// Filtre, trie et finalise les questions détectées.
    static func finalize(_ state: State) -> [StmtQuestion] {
        var withSubQuestions = Set<String>()
        for detected in state.detected where detected.label.contains(".") {
            let head = String(detected.label.prefix(while: { $0 != "." }))
            withSubQuestions.insert("\(detected.sectionId ?? ""):\(head)")
        }
        var sectionsWithQuestions = Set<String>()
        for detected in state.detected {
            guard let sectionId = detected.sectionId, !detected.sectionFallback else { continue }
            sectionsWithQuestions.insert(sectionId)
            if let range = sectionId.range(of: "--") {
                sectionsWithQuestions.insert(String(sectionId[sectionId.startIndex..<range.lowerBound]))
            }
        }
        let kept = state.detected.filter { detected in
            (!detected.sectionFallback || !sectionsWithQuestions.contains(detected.sectionId ?? ""))
                && !withSubQuestions.contains("\(detected.sectionId ?? ""):\(detected.label)")
        }
        return sortAlphabeticalRuns(kept).map { detected in
            let legacyId = StmtQuestions.annaleQuestionId(detected.label)
            let id: String
            if detected.sectionFallback, let sectionId = detected.sectionId {
                id = sectionId
            } else if let sectionId = detected.sectionId {
                id = "\(sectionId)-\(legacyId)"
            } else {
                id = legacyId
            }
            var legacy: String?
            if let sectionId = detected.sectionId, !detected.sectionFallback {
                if let range = sectionId.range(of: "--") {
                    legacy = "\(String(sectionId[sectionId.startIndex..<range.lowerBound]))-\(legacyId)"
                } else {
                    legacy = legacyId
                }
            }
            return StmtQuestion(id: id, label: detected.label, legacyId: legacy, prompt: detected.prompt)
        }
    }

    /// Trie chaque suite alphabétique (PDF en colonnes : « a, d, b, e, c, f »).
    static func sortAlphabeticalRuns(_ questions: [Detected]) -> [Detected] {
        func labelRunKey(_ label: String) -> String? {
            if StmtRegex.contains("^[a-z]$", in: label) { return "standalone" }
            return StmtRegex.groups("^(\\d{1,2})\\.[a-z]$", in: label)?[1]
        }
        func runKey(_ question: Detected) -> String? {
            guard let labelKey = labelRunKey(question.label) else { return nil }
            return "\(question.sectionId ?? ""):\(labelKey)"
        }
        var result: [Detected] = []
        var index = 0
        while index < questions.count {
            guard let key = runKey(questions[index]) else {
                result.append(questions[index])
                index += 1
                continue
            }
            var end = index + 1
            while end < questions.count, runKey(questions[end]) == key { end += 1 }
            result.append(contentsOf: questions[index..<end].sorted { String($0.label.suffix(1)) < String($1.label.suffix(1)) })
            index = end
        }
        return result
    }
}
