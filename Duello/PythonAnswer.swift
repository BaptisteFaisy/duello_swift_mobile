//
//  PythonAnswer.swift
//  Duello
//
//  Port de `src/utils/pythonAnswer.ts` (RN) — programme Python porté par une
//  réponse mixte.
//
//  Une réponse d'annale mêle du français et des blocs ```python``` : la console
//  n'exécute que ces blocs, jamais la prose. `sourceFromAnswer` les extrait ;
//  `insertBlockAtSelection` referme la sélection dans un bloc. `fencedCodeBlocks`
//  et `containsCodeBlock` vivent déjà dans `StmtAnswerSupport.swift`.
//
//  Cible : iOS 16. Aucune dépendance externe.
//

import Foundation

/// Sélection remplacée et curseur résultant (`TextEditResult` de
/// `textEditing.ts`). Les bornes sont en unités UTF-16 de la chaîne, comme
/// `StmtTextSelection`.
struct PythonAnswerEdit: Equatable {
    var value: String
    var selection: StmtTextSelection
}

/// Programmes Python portés par une réponse (`pythonAnswer.ts`).
enum PythonAnswer {

    /// `pythonSourceFromAnswer` : programme exécutable porté par une réponse.
    ///
    /// Une réponse mixte n'envoie à la console que ses blocs Python. Dans un
    /// chapitre Python, l'ancien usage reste valable : sans clôture explicite,
    /// tout le champ est encore considéré comme un programme.
    static func sourceFromAnswer(
        _ answer: String,
        wholeAnswerIsPython: Bool = false
    ) -> String? {
        let python = StmtAnswerSupport.fencedCodeBlocks(answer).filter {
            $0.language == "python" || $0.language == "py"
        }
        if !python.isEmpty {
            let joined = python.map { $0.code }
                .joined(separator: "\n\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return joined.isEmpty ? nil : joined
        }
        let trimmed = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        return (wholeAnswerIsPython && !trimmed.isEmpty) ? answer : nil
    }

    /// `insertPythonBlockAtSelection` : transforme la sélection en bloc Python ou
    /// crée un bloc vide au curseur. Le curseur reste à l'intérieur, juste avant
    /// la clôture.
    static func insertBlockAtSelection(
        _ value: String,
        _ selection: StmtTextSelection
    ) -> PythonAnswerEdit {
        let source = value as NSString
        let clamped = clamp(value, selection)
        let before = source.substring(to: clamped.start)
        let selected = source.substring(
            with: NSRange(location: clamped.start, length: clamped.end - clamped.start))
        let after = source.substring(from: clamped.end)
        let prefix = (!before.isEmpty && !before.hasSuffix("\n")) ? "\n" : ""
        let suffix = (!after.isEmpty && !after.hasPrefix("\n")) ? "\n" : ""
        let opening = "```python\n"
        let block = "\(prefix)\(opening)\(selected)\n```\(suffix)"
        let cursor = clamped.start
            + (prefix as NSString).length
            + (opening as NSString).length
            + (selected as NSString).length
        return PythonAnswerEdit(
            value: "\(before)\(block)\(after)",
            selection: StmtTextSelection(start: cursor, end: cursor)
        )
    }

    /// `clampTextSelection` : ramène une sélection périmée dans les bornes.
    static func clamp(_ value: String, _ selection: StmtTextSelection) -> StmtTextSelection {
        let length = (value as NSString).length
        let start = max(0, min(selection.start, length))
        let end = max(start, min(selection.end, length))
        return StmtTextSelection(start: start, end: end)
    }
}
