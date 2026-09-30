//
//  SubjFlashcardAnswerComposer.swift
//  Duello
//
//  Lot « Subj » (9-G) — briques de la branche « correction IA » qui ne sont pas
//  déjà fournies par le lot 9-F : édition des touches maths et notation de la
//  réponse par le correcteur.
//
//  Le champ de réponse et l'aperçu composé ne sont **pas** redéfinis ici : le
//  lot 9-F les porte déjà avec le contrat exact de la source
//  (`SubjFlashcardAnswerField`, `SubjAnswerComposition` — fichier
//  `SubjFlashcardAnswerField.swift`) et ils sont réutilisés tels quels par
//  `SubjFlashcardAiWorkflow`.
//
//  Fichiers source Expo portés :
//    - src/screens/SubjectsScreen.tsx (lignes 2403-2425)
//        `insertMathText` / `deleteMathText` (`insertStructuredTextAtSelection`,
//        `deleteBeforeSelection`) ;
//    - src/screens/SubjectsScreen.tsx (lignes 2552-2581)
//        `submitAiCorrection` — `gradeMathAnswer` avec
//        `exercise: "Flashcard — {chapterName}"` et messages d'erreur.
//
//  Limite documentée (même que le lot 9-F) : SwiftUI iOS 16 n'expose pas la
//  sélection d'un champ de saisie. Le port fidèle de `utils/textEditing.ts` est
//  fourni (`SubjTextRange`/`SubjTextEdit` + `…AtSelection`) ; l'hôte qui suit un
//  curseur (session de révision) l'emploie et applique ainsi le recul `back`. Le
//  repli `insert`/`deleteLast` (hôte annale) insère en fin de champ.
//
//  Écarts assumés (2026-09-29)
//  ---------------------------
//  Recul de curseur (`back` de `insertAtCaret`, `MathKeyboard.tsx:289-296`) :
//  la source place le curseur `back` caractères avant la fin après l'insertion
//  (`()`, `{}`, `√()`…). Le port suit ce curseur logiquement
//  (`insertStructuredTextAtSelection`) ; le **curseur visible** d'un `TextField`
//  SwiftUI reste, lui, hors de portée sans champ `UIViewRepresentable` — l'hôte
//  resynchronise le curseur logique en fin de texte à chaque frappe manuelle.
//
//  Cible : iOS 16, aucune dépendance externe.
//
import Foundation

// MARK: - Sélection et édition

/// Sélection dans un champ (curseur = plage vide) — `TextSelection` de
/// `src/utils/textEditing.ts`.
struct SubjTextRange: Equatable {
    var start: Int
    var end: Int
    static let zero = SubjTextRange(start: 0, end: 0)
}

/// Résultat d'une édition — `TextEditResult`.
struct SubjTextEdit: Equatable {
    var value: String
    var selection: SubjTextRange
}

// MARK: - Édition des touches maths

/// Port de `src/utils/textEditing.ts` (`insertTextAtSelection`,
/// `insertStructuredTextAtSelection`, `insertBlockAtSelection`,
/// `deleteBeforeSelection`), plus l'API historique d'insertion en fin de champ
/// (`insert`/`deleteLast`).
///
/// `insert`/`deleteLast` restent le repli « curseur réputé en fin de champ »
/// (hôte annale, sans suivi de sélection). Les fonctions `…AtSelection` suivent
/// un curseur fourni par l'hôte, ce qui applique réellement le recul `back`
/// demandé par les touches (`()`, `{}`, `√()`…) : la chaîne produite diffère
/// alors de l'insertion en fin (`(`, `)`, `2` donnent `(2)` et non `()2`).
enum SubjFlashcardMathEditing {
    /// API historique : insertion en fin de réponse (hôte sans suivi de curseur).
    static func insert(_ text: String, back: Int = 0, into response: String) -> String {
        response + text
    }

    static func deleteLast(_ response: String) -> String {
        response.isEmpty ? response : String(response.dropLast())
    }

    /// `clampTextSelection` : ramène une sélection dans les bornes du texte.
    static func clamp(_ value: String, _ selection: SubjTextRange) -> SubjTextRange {
        let length = value.utf16.count
        let start = max(0, min(selection.start, length))
        let end = max(start, min(selection.end, length))
        return SubjTextRange(start: start, end: end)
    }

    /// `insertTextAtSelection` : remplace la sélection puis place le curseur
    /// `cursorBack` unités avant la fin du texte inséré.
    static func insertTextAtSelection(
        _ value: String, selection: SubjTextRange, inserted: String, cursorBack: Int = 0
    ) -> SubjTextEdit {
        let range = clamp(value, selection)
        let units = Array(value.utf16)
        let before = String(decoding: units[0..<range.start], as: UTF16.self)
        let after = String(decoding: units[range.end..<units.count], as: UTF16.self)
        let newValue = before + inserted + after
        let cursor = max(0, min(range.start + inserted.utf16.count - cursorBack, newValue.utf16.count))
        return SubjTextEdit(value: newValue, selection: SubjTextRange(start: cursor, end: cursor))
    }

    /// `insertStructuredTextAtSelection` : un bloc multiligne (matrice) est isolé
    /// du texte qui le précède et le suit.
    static func insertStructuredTextAtSelection(
        _ value: String, selection: SubjTextRange, inserted: String, cursorBack: Int = 0
    ) -> SubjTextEdit {
        guard inserted.contains("\n") else {
            return insertTextAtSelection(value, selection: selection, inserted: inserted, cursorBack: cursorBack)
        }
        let edit = insertBlockAtSelection(value, selection: selection, block: inserted)
        let cursor = max(0, edit.selection.start - cursorBack)
        return SubjTextEdit(value: edit.value, selection: SubjTextRange(start: cursor, end: cursor))
    }

    /// `insertBlockAtSelection` : insère un bloc sur sa propre ligne, sans créer
    /// de ligne vide en début ou en fin de réponse.
    static func insertBlockAtSelection(
        _ value: String, selection: SubjTextRange, block: String
    ) -> SubjTextEdit {
        let range = clamp(value, selection)
        let units = Array(value.utf16)
        let before = String(decoding: units[0..<range.start], as: UTF16.self)
        let after = String(decoding: units[range.end..<units.count], as: UTF16.self)
        let prefix = (!before.isEmpty && !before.hasSuffix("\n")) ? "\n" : ""
        let suffix = (!after.isEmpty && !after.hasPrefix("\n")) ? "\n" : ""
        let inserted = prefix + block + suffix
        let cursor = range.start + inserted.utf16.count - suffix.utf16.count
        return SubjTextEdit(value: before + inserted + after, selection: SubjTextRange(start: cursor, end: cursor))
    }

    /// `deleteBeforeSelection` : supprime la sélection ou, sans sélection, l'unité
    /// UTF-16 précédente.
    static func deleteBeforeSelection(_ value: String, selection: SubjTextRange) -> SubjTextEdit {
        let range = clamp(value, selection)
        let from = range.start == range.end ? max(0, range.start - 1) : range.start
        if from == range.end { return SubjTextEdit(value: value, selection: range) }
        let units = Array(value.utf16)
        let before = String(decoding: units[0..<from], as: UTF16.self)
        let after = String(decoding: units[range.end..<units.count], as: UTF16.self)
        return SubjTextEdit(value: before + after, selection: SubjTextRange(start: from, end: from))
    }
}

// MARK: - Notation IA

/// `gradeMathAnswer` pour une flashcard : mêmes clés de corps et mêmes verdicts
/// que la source (`CollGradingService`), seul l'intitulé d'exercice change.
enum SubjFlashcardAiGrader {
    static func grade(
        card: CollFlashcard,
        chapterName: String,
        program: String,
        answer: String,
        token: String?
    ) async throws -> CollMathGrade {
        let body = try CollGradingService.requestBody(
            exercise: "Flashcard — \(chapterName)",
            question: card.question,
            answer: answer,
            program: program
        )
        let data = try await CollGradingService.post(body: body, token: token)
        return try CollGradingService.readResponse(data)
    }
}
