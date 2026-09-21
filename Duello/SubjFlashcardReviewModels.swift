//
//  SubjFlashcardReviewModels.swift
//  Duello
//
//  Lot « Subj » (9-G) — session de révision des flashcards : types, libellés,
//  palette et mesures partagés par la fenêtre plein écran
//  `SubjFlashcardReviewModal`.
//
//  Fichier source Expo porté (libellés repris mot pour mot) :
//    - src/screens/SubjectsScreen.tsx (lignes 2336-2973)
//        `FlashcardReviewModal` — libellés des faces, aide au toucher, alertes
//        de sortie, barre de verdict et messages de correction IA.
//    - styles `flashcardReview*`, `flashcardFullCard`, `flashcardFace`,
//        `flashcardCardScrollContent`, `flashcardVerdict*`, `flashcardAi*`
//        (couleurs et mesures littérales reprises telles quelles).
//
//  Types réutilisés, **jamais redéclarés** :
//    - `CollFlashcard`, `CollFlashcardVerdict`, `CollFlashcardSessionCounts`
//      (`CollFlashcards.swift`, `CollFlashcardReview.swift`) ;
//    - `SubjFlashcardCorrectionMode` (`SubjFlashcardSelection.swift`, lot 9-E) ;
//    - `CollMathGrade`, `CollVerdict` (`CollCompletionModels.swift`) ;
//    - `ExGFormat` (formatage XP / durée) et `LatexToUnicode` (maths → Unicode).
//
//  Cible : iOS 16, aucune dépendance externe.
//
import SwiftUI

// MARK: - Bilan de fin de session

/// `successSummary` de la source : ce que la session de révision a rapporté.
struct SubjFlashcardReviewSummary: Equatable {
    var xp: Double
    var seconds: Double
    /// Part du cours maîtrisée, en pourcent (mesure cumulative des chapitres).
    var chapterMastery: Int
}

// MARK: - Barre de verdict

/// Une entrée de la barre de verdict d'auto-correction.
struct SubjFlashcardVerdictOption: Identifiable {
    let verdict: CollFlashcardVerdict
    let label: String

    var id: String { verdict.rawValue }
}

/// `[['wrong', 'Faux'], ['partial', 'Partiel'], ['correct', 'Réussi']]`.
enum SubjFlashcardVerdictOptions {
    static let all: [SubjFlashcardVerdictOption] = [
        SubjFlashcardVerdictOption(verdict: .wrong, label: "Faux"),
        SubjFlashcardVerdictOption(verdict: .partial, label: "Partiel"),
        SubjFlashcardVerdictOption(verdict: .correct, label: "Réussi"),
    ]
}

// MARK: - Libellés

/// Libellés de la fenêtre de révision, mot pour mot de la source.
enum SubjFlashcardReviewCopy {
    // Faces
    static let sideFront = "RECTO"
    static let sideBack = "VERSO"
    static let sideQuestion = "QUESTION"

    // Aide au toucher
    static let tapHintFlip = "Touche la carte pour la retourner"
    static let tapHintToBack = "Touche la carte pour voir le verso"
    static let tapHintToFront = "Touche la carte pour voir le recto"

    // Sortie
    static let exitAccessibility = "Quitter la révision"
    static let exitTitle = "Quitter la révision ?"
    static let exitKeep = "Continuer la révision"
    static let exitConfirm = "Quitter"

    // Correction IA
    static let answerLabel = "Ta réponse"
    static let answerPlaceholder = "Rédige ta réponse avant de la soumettre…"
    static let answerAccessibility = "Ma réponse à la flashcard"
    static let submitAccessibility = "Soumettre la réponse à la correction IA"
    static let submitIdle = "Soumettre à la correction"
    static let submitBusy = "Correction en cours…"
    static let emptyAnswerError = "Rédige une réponse avant de la soumettre."
    static let gradingUnavailable = "Correction IA indisponible. Réessaie dans un instant."
    static let continueLabel = "Continuer"

    // Bilan de fin de session
    static let claimXp = "Recevoir mes XP"
    static let claimedXp = "XP reçus"

    /// Alerte de sortie : le montant perdu dépend de la session en cours.
    static func exitMessage(sessionXp: Double) -> String {
        sessionXp > 0
            ? "Tu vas perdre les \(ExGFormat.xp(sessionXp)) XP gagnés pendant cette session."
            : "Les XP gagnés pendant cette session seront perdus."
    }

    /// `+{formatXp(xp)} XP` du gain flottant.
    static func xpGain(_ xp: Double) -> String {
        "+\(ExGFormat.xp(xp)) XP"
    }

    /// Étiquette du verdict IA, affichée hors réponse parfaite.
    static func aiVerdict(_ verdict: CollVerdict) -> String {
        switch verdict {
        case .perfect: return "Réponse parfaite"
        case .correct: return "Réponse correcte"
        case .partial: return "Réponse partielle"
        case .incorrect: return "Réponse incorrecte"
        }
    }

    /// Résumé lu par VoiceOver sur la rangée de compteurs.
    static func countsAccessibility(_ counts: CollFlashcardSessionCounts) -> String {
        "\(counts.correct) réussies, \(counts.partial) partielles, \(counts.wrong) fausses"
    }
}

// MARK: - Palette

/// Couleurs littérales des styles `flashcard*` de la source.
enum SubjFlashcardReviewPalette {
    // Cases de compteur et boutons de verdict.
    static let correctFill = Color(hex: 0xDDF5E7)
    static let partialFill = Color(hex: 0xFFF0C7)
    static let wrongFill = Color(hex: 0xFCE0E0)

    // Teintes du résultat IA (`flashcardAiPerfect|Correct|Partial|Incorrect`).
    static let aiPerfectBorder = Theme.gradingPerfect
    static let aiPerfectFill = Theme.gradingPerfectLight
    static let aiCorrectBorder = Color(hex: 0x82C9A1)
    static let aiCorrectFill = Color(hex: 0xF0FBF5)
    static let aiPartialBorder = Color(hex: 0xE6C66A)
    static let aiPartialFill = Color(hex: 0xFFF9E8)
    static let aiIncorrectBorder = Color(hex: 0xE4A4A4)
    static let aiIncorrectFill = Color(hex: 0xFFF3F3)

    /// Fond d'un bouton de verdict d'auto-correction.
    static func fill(for verdict: CollFlashcardVerdict) -> Color {
        switch verdict {
        case .correct: return correctFill
        case .partial: return partialFill
        case .wrong: return wrongFill
        }
    }
}

// MARK: - Mesures

/// Mesures de la source (px RN), reprises telles quelles.
enum SubjFlashcardReviewMetrics {
    static let horizontalPadding: CGFloat = 18
    static let cardRadius: CGFloat = 28
    static let cardMinHeight: CGFloat = 480
    static let selfCardMinHeight: CGFloat = 470
    static let aiResultMinHeight: CGFloat = 520
    static let aiQuestionMinHeight: CGFloat = 240
    static let cardContentHorizontal: CGFloat = 26
    static let cardContentVertical: CGFloat = 58
    static let aiResultContentBottom: CGFloat = 62
    static let sideLabelInset: CGFloat = 22
    static let tapHintInset: CGFloat = 22
    static let exitButtonSize: CGFloat = 46
    static let exitButtonTrailing: CGFloat = 6
    static let xpGainSlotMinHeight: CGFloat = 22
    static let countTileSize: CGFloat = 32
    static let mathKeyboardTop: CGFloat = 42
    /// Retournement recto/verso (`Animated.spring`, friction 8, tension 70).
    static let flipDuration: Double = 0.42
    /// Collecte des XP du bilan (`REVISION_XP_FLIGHT_DURATION_MS`).
    static let summaryFlightDuration: Double = 1.4
    /// Maintien avant la sortie (`REVISION_XP_RESULT_HOLD_MS`).
    static let summaryHold: Double = 0.9
    /// Montée du bloc XP pendant la collecte.
    static let summaryLift: CGFloat = 90
}
