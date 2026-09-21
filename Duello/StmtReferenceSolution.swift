import Foundation

/// Corrigé de référence d'une question — port de
/// `src/utils/questionReferenceSolution.ts`.
enum StmtReferenceSolution {
    /// Marqueur de début d'une section de corrigé.
    struct SolutionMarker {
        var label: String
        var section: String
        var start: Int
    }

    static let partieHeading = "^partie\\s+([ivxlcdm]+|[a-z]|\\d+)(?=[\\s—–:;,.!)»]|$)"
    static let exerciseHeading = "^exercice\\s+([0-9]+|[a-z])\\b"
    static let numberHeading =
        "^(?:question\\s+)?(\\d{1,2})(?:\\s*[.)°:]\\s*(?:\\(?([a-z])\\)|([a-z])[.)])(?=\\s|$)\\s*|\\s*[.)°:](?=\\s|$)\\s*|\\s*$)"
    static let letterHeading = "^(?:\\(([a-z])\\)|([a-z])[.)])(?=\\s|$)"
    static let french = StmtQuestionsParser.french

    /// Clé de comparaison d'un libellé (minuscules, alphanumérique).
    static func questionKey(_ label: String) -> String {
        StmtRegex.replaceAll("[^a-z0-9]", in: label.lowercased(with: french), template: "")
    }

    /// Ligne débarrassée de son titre Markdown et de son gras.
    static func solutionLine(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        let withoutHeading = StmtRegex.replaceAll("^#{1,6}\\s*", in: trimmed, template: "")
        return StmtRegex.replaceAll("\\*\\*", in: withoutHeading, template: "")
    }

    /// Libellé décalé par la reprise de série d'une partie (`shiftLabel`).
    static func shiftLabel(_ label: String, _ hasShift: Bool, _ shift: Int) -> String {
        guard hasShift, StmtRegex.contains("^\\d{1,2}$", in: label), let value = Int(label) else { return label }
        let shifted = value + shift
        return shifted <= 99 ? "\(shifted)" : label
    }

    /// Marqueurs de section d'un corrigé (`solutionMarkers`).
    static func solutionMarkers(_ text: String) -> [SolutionMarker] {
        var markers: [SolutionMarker] = []
        var parent = ""
        var section = ""
        var offset = 0
        var mathBlock = false
        var codeBlock = false
        var questionShift = 0
        var hasQuestionShift = false
        var pendingShiftAfterPartie = false

        for raw in text.components(separatedBy: "\n") {
            let start = offset
            offset += (raw as NSString).length + 1
            let line = solutionLine(raw)
            if line.hasPrefix("```") { codeBlock.toggle(); continue }
            if codeBlock { continue }
            if line.hasPrefix("$$") || line == "\\[" || line == "\\]" {
                if line == "$$" || line == "\\[" || line == "\\]" { mathBlock.toggle() }
                continue
            }
            if mathBlock { continue }

            if StmtRegex.contains(partieHeading, in: line, options: [.caseInsensitive]) {
                let last = markers.last
                let lastNumber = (last != nil && StmtRegex.contains("^\\d+$", in: last!.label)) ? Int(last!.label) : nil
                questionShift = lastNumber ?? 0
                hasQuestionShift = lastNumber != nil && lastNumber! > 0
                pendingShiftAfterPartie = true
                parent = ""
                markers.append(SolutionMarker(label: "", section: section, start: start))
            }
            if let exercise = StmtRegex.groups(exerciseHeading, in: line, options: [.caseInsensitive]) {
                section = "exercice-\(exercise[1].lowercased(with: french))"
                parent = ""
                hasQuestionShift = false
                pendingShiftAfterPartie = false
                markers.append(SolutionMarker(label: "", section: section, start: start))
                continue
            }

            let numberMatch = StmtRegex.groups(numberHeading, in: line, options: [.caseInsensitive])
            let letterMatch = StmtRegex.groups(letterHeading, in: line, options: [.caseInsensitive])
            if let numberMatch {
                parent = numberMatch[1]
                if pendingShiftAfterPartie {
                    if numberMatch[1] == "1", hasQuestionShift {
                        pendingShiftAfterPartie = false
                    } else if numberMatch[1] != "1" {
                        pendingShiftAfterPartie = false
                        hasQuestionShift = false
                    }
                }
                let suffix = !numberMatch[2].isEmpty ? numberMatch[2] : numberMatch[3]
                let label = shiftLabel(parent, hasQuestionShift, questionShift) + suffix.lowercased(with: french)
                markers.append(SolutionMarker(label: label, section: section, start: start))
            } else if let letterMatch {
                let letter = !letterMatch[1].isEmpty ? letterMatch[1] : letterMatch[2]
                let label = shiftLabel(parent, hasQuestionShift, questionShift) + letter.lowercased(with: french)
                markers.append(SolutionMarker(label: label, section: section, start: start))
            }
        }
        return markers
    }

    /// Extrait la section de corrigé d'une question (`selectQuestionSection`).
    static func selectQuestionSection(_ text: String, _ question: StmtQuestion) -> String? {
        let markers = solutionMarkers(text)
        let label = questionKey(question.label)
        let section = StmtRegex.groups("^(exercice-[a-z0-9]+)-", in: question.id)?[1]
        let hasSections = markers.contains { !$0.section.isEmpty }
        let matches = markers.enumerated().filter { _, marker in
            marker.label == label && (section == nil || !hasSections || marker.section == section)
        }
        if matches.count != 1 { return nil }
        let selected = matches[0]
        let next = markers[(selected.offset + 1)...].first { marker in
            marker.section != selected.element.section
                || !StmtRegex.contains("^\\d+$", in: label)
                || !marker.label.hasPrefix(label)
                || !StmtRegex.contains("^[a-z]$", in: String(marker.label.dropFirst(label.count)))
        }
        let source = text as NSString
        let end = next?.start ?? source.length
        let slice = source
            .substring(with: NSRange(location: selected.element.start, length: end - selected.element.start))
            .trimmingCharacters(in: .whitespaces)
        return slice.isEmpty ? nil : slice
    }

    /// Corrigé de référence d'une question (`questionReferenceSolution`).
    static func questionReferenceSolution(
        _ solution: String?,
        _ question: StmtQuestion,
        _ questions: [StmtQuestion]
    ) -> String? {
        guard let solution, !solution.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        if let alternativeId = question.alternativeId {
            return StmtQuestions.extractAlternativeChoiceText(solution, alternativeId)
        }
        if questions.count == 1 { return solution.trimmingCharacters(in: .whitespaces) }
        return selectQuestionSection(solution, question)
    }
}
