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
//  sélection d'un champ de saisie ; les touches maths s'ajoutent donc **en fin**
//  de réponse et l'effacement retire le dernier caractère.
//
//  Écarts assumés (2026-09-29)
//  ---------------------------
//  Recul de curseur (`back` de `insertAtCaret`, `MathKeyboard.tsx:289-296`) :
//  la source place le curseur `back` caractères avant la fin après l'insertion
//  (`()`, `{}`, `√()`…). `insert(_:back:into:)` transporte `back` pour la parité
//  de signature, mais un champ sans curseur ne peut pas le matérialiser : la
//  chaîne produite est `réponse + texte`, identique à la source. L'application
//  effective du recul dépend d'un champ `UIViewRepresentable` (curseur UIKit) —
//  hors périmètre de ce fichier.
//
//  Cible : iOS 16, aucune dépendance externe.
//
import Foundation

// MARK: - Édition des touches maths

/// `insertStructuredTextAtSelection` / `deleteBeforeSelection`, réduits au
/// contrat disponible : insertion en fin de réponse, effacement du dernier
/// caractère. `back` (recul du curseur demandé par la touche) est transporté
/// pour la parité de signature — sans curseur, il ne modifie pas la chaîne
/// (voir « Écarts assumés »).
enum SubjFlashcardMathEditing {
    static func insert(_ text: String, back: Int = 0, into response: String) -> String {
        response + text
    }

    static func deleteLast(_ response: String) -> String {
        response.isEmpty ? response : String(response.dropLast())
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
