import SwiftUI
import Foundation

// MARK: - Difficulté

/// Paliers de difficulté, alignés sur `DIFFICULTY_LABELS` (`itemDifficulty.ts`).
enum AnnDifficulty {
    static let order: [Int] = [1, 2, 3, 4, 5, 6]

    /// Libellé affiché d'un palier.
    static func label(for level: Int) -> String {
        switch level {
        case 1: return "Très facile"
        case 2: return "Facile"
        case 3: return "Moyen"
        case 4: return "Difficile"
        case 5: return "Très difficile"
        case 6: return "Extrême"
        default: return "Moyen"
        }
    }

    /// Ton de la pastille de difficulté : le vert reste réservé à la réussite.
    static func tone(for level: Int) -> DuelloPillTone {
        switch level {
        case 1, 2: return .neutral
        case 3, 4: return .ink
        case 5: return .warning
        default: return .danger
        }
    }
}

// MARK: - Verdicts

/// Verdict d'une question corrigée, aligné sur `AnnaleQuestionVerdict`.
enum AnnVerdict: String, Codable, CaseIterable, Identifiable {
    case perfect
    case correct
    case partial
    case incorrect

    var id: String { rawValue }

    /// Libellé affiché, mot pour mot de `questionVerdictLabel`.
    var label: String {
        switch self {
        case .perfect: return "Parfaite"
        case .correct: return "Juste"
        case .partial: return "Presque juste"
        case .incorrect: return "Incorrecte"
        }
    }

    /// Icône équivalente aux glyphes Ionicons de `questionVerdictIcon`.
    var icon: String {
        switch self {
        case .perfect: return "sparkles"
        case .correct: return "checkmark.circle.fill"
        case .partial: return "exclamationmark.circle.fill"
        case .incorrect: return "xmark.circle.fill"
        }
    }

    /// Couleur du verdict (`questionVerdictColor`).
    var color: Color {
        switch self {
        case .perfect: return Theme.gradingPerfect
        case .correct: return Theme.progress
        case .partial: return Theme.gradingPartial
        case .incorrect: return Theme.like
        }
    }

    /// Ton de pastille correspondant.
    var tone: DuelloPillTone {
        switch self {
        case .perfect, .correct: return .success
        case .partial: return .warning
        case .incorrect: return .danger
        }
    }

    /// Verdict qui valide la question (`isValidatedAnnaleVerdict`).
    var isValidated: Bool { self == .perfect || self == .correct }
}

// MARK: - Thèmes

/// Thème de tri d'une annale (`AnnaleTheme` de `annaleThemes.ts`).
enum AnnTheme: String, Codable, CaseIterable, Identifiable {
    case analyse
    case algebre
    case probabilites

    var id: String { rawValue }

    var label: String {
        switch self {
        case .analyse: return "Analyse"
        case .algebre: return "Algèbre"
        case .probabilites: return "Probabilités"
        }
    }
}

// MARK: - Statut de programme

/// Signalement d'un sujet conservé au-delà du programme courant
/// (`programStatus` de `ChapterItem`).
enum AnnProgramStatus: String, Codable {
    case onProgram = "au-programme"
    case toCheck = "a-verifier"
    case outsideProgram = "hors-programme"

    /// Libellé du signalement, vide quand le sujet est au programme.
    var label: String {
        switch self {
        case .onProgram: return ""
        case .toCheck: return "Programme 2026 à vérifier"
        case .outsideProgram: return "Hors programme 2026"
        }
    }

    var icon: String {
        switch self {
        case .onProgram: return "checkmark.circle"
        case .toCheck: return "questionmark.circle"
        case .outsideProgram: return "exclamationmark.triangle"
        }
    }
}

// MARK: - Questions

/// Question d'une annale, alignée sur `AnnaleQuestion` de `chapterItems.ts`.
struct AnnQuestion: Identifiable, Hashable {
    var id: String
    var label: String
    /// Variante d'un QCM (« A », « B »…), absente d'une question unique.
    var alternativeId: String? = nil
    /// Regroupe les variantes d'un même choix : elles comptent pour une question.
    var alternativeGroupId: String? = nil
    /// Barème indicatif de la question, en points.
    var points: Double? = nil

    /// Libellé du bouton de navigation (`questionDisplayLabel`) : la variante
    /// garde son numéro de question et perd son « Choix A ».
    var displayLabel: String {
        guard let alternativeId else { return label }
        let number = AnnQuestion.questionNumber(of: label)
        return "\(number) - \(alternativeId)"
    }

    /// Numéro de tête d'un libellé (« 3 - Choix A » → « 3 »).
    static func questionNumber(of label: String) -> String {
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let range = trimmed.range(of: " - ") else { return trimmed }
        return String(trimmed[trimmed.startIndex..<range.lowerBound])
    }
}

// MARK: - Entrée d'annale

/// Une annale de la banque : sujet, corrigé, barème, commentaires et questions.
///
/// Reprend la forme utile de `ChapterItem` (`chapterItems.ts`) pour une liste
/// d'annales. Les champs de rendu de PDF (`sourceUrl`, `sourceAsset`,
/// `sourcePage`, `sourceRegion`) ne sont pas portés : le lecteur SwiftUI affiche
/// les documents retranscrits en texte.
struct AnnEntry: Identifiable, Hashable {
    var id: String
    var title: String
    /// Provenance éditoriale (concours, école, session), affichée sous le titre.
    var source: String? = nil
    /// Badges éditoriaux bruts (`ChapterItem.badges`).
    var badges: [String] = []
    /// Types d'épreuve de l'annale (`ChapterItem.annaleTypes`).
    var annaleTypes: [String] = []
    var theme: AnnTheme? = nil
    var difficulty: Int = 3
    /// Énoncé retranscrit (LaTeX composé par `LatexToUnicode`).
    var statement: String? = nil
    var solution: String? = nil
    var markingScheme: String? = nil
    var comments: String? = nil
    var questions: [AnnQuestion] = []
    var programStatus: AnnProgramStatus? = nil
    /// Avancement des prérequis, tel que le filtre « Prérequis » le lit.
    var prerequisite: String = "Prêt"

    // MARK: Dérivés

    /// Année de session lue dans les métadonnées stables (`annaleYear`).
    var year: String? {
        let haystack = "\(title)\n\(source ?? "")\n\(id)"
        guard let range = haystack.range(of: #"\b(?:19|20)\d{2}\b"#, options: .regularExpression) else {
            return nil
        }
        return String(haystack[range])
    }

    /// Badges réellement affichés sur la fiche (`displayedAnnaleBadges`) :
    /// un DS garde sa durée, une épreuve écrite affiche son type avec l'année.
    var displayedBadges: [String] {
        let dsBadges = badges.filter { $0.hasPrefix("DS") }
        if !dsBadges.isEmpty { return dsBadges }
        let sessionBadges = badges.filter { badge in
            badge.range(of: #" · (?:19|20)\d{2}$"#, options: .regularExpression) != nil
        }
        if !sessionBadges.isEmpty { return sessionBadges }
        if !annaleTypes.isEmpty {
            guard let year else { return annaleTypes }
            return annaleTypes.map { "\($0) · \(year)" }
        }
        return badges
    }

    /// Durée d'épreuve déduite des badges (`dsDurationHours` du lecteur).
    var durationHours: Int {
        if badges.contains("DS 2h") { return 2 }
        if badges.contains("DS 4h") { return 4 }
        return 4
    }

    /// Durée annoncée dans le panneau de déverrouillage.
    var durationLabel: String { "\(durationHours) h" }

    /// Formats d'oral qui se traitent comme des exercices
    /// (`ORAL_EXERCISE_BADGES` de `annaleWorkspaceMode.ts`).
    static let oralExerciseBadges: [String] = [
        "Oral ESCP", "QSP ESCP", "Oral HEC", "ESP HEC",
    ]

    /// Une annale écrite se compose sur papier (`usesWrittenAnnaleWorkspace`).
    var isWrittenPaper: Bool {
        !badges.contains { AnnEntry.oralExerciseBadges.contains($0) }
    }

    /// Corrigé officiel disponible (`hasOfficialSolution`).
    var hasOfficialSolution: Bool { solution != nil }

    /// Valeurs de type proposées au filtre « Type » (`filterItemsByBadges`).
    var filterTypeValues: [String] {
        annaleTypes + badges.filter { AnnEntry.typeBadges.contains($0) }
    }

    /// Épreuves qui rejoignent les rôles dans le menu « Type ».
    static let typeBadges: [String] = [
        "DS 2h", "DS 4h", "Oral ESCP", "Oral HEC", "ESP HEC",
    ]

    /// Banque de démonstration : la banque réelle est un catalogue généré côté
    /// Expo (`src/data/*Annales.generated.ts`), non porté ici. Les sujets
    /// ci-dessous n'ont pas valeur de contenu éditorial ; ils donnent la forme
    /// d'échange attendue par la liste, le lecteur et la correction de copie.
    static let builtInBank: [AnnEntry] = [
        AnnEntry(
            id: "annale-edhec-2024-maths2",
            title: "EDHEC 2024 — Épreuve de mathématiques II",
            source: "Concours EDHEC, session 2024",
            badges: ["DS 4h"],
            annaleTypes: ["EDHEC"],
            theme: .analyse,
            difficulty: 4,
            statement: """
            On considère la suite $(u_n)$ définie par $u_0 = 1$ et, pour tout \
            entier naturel $n$, $u_{n+1} = \\dfrac{u_n + 2}{u_n + 1}$.
            """,
            solution: """
            $u$ converge vers $\\sqrt{2}$ ; la suite auxiliaire $v_n = \
            \\dfrac{u_n - \\sqrt{2}}{u_n + \\sqrt{2}}$ est géométrique de raison \
            $\\left(1 - \\sqrt{2}\\right)^2$.
            """,
            markingScheme: """
            Étude de la suite : 6 points. Convergence : 4 points. \
            Application économique : 10 points.
            """,
            comments: """
            Les correcteurs attendent la justification de la convergence avant \
            tout calcul de limite.
            """,
            questions: [
                AnnQuestion(id: "q1", label: "1 - Étude de la suite", points: 6),
                AnnQuestion(id: "q2", label: "2 - Convergence", points: 4),
                AnnQuestion(id: "q3", label: "3 - Application économique", points: 10),
            ],
            programStatus: .onProgram
        ),
        AnnEntry(
            id: "annale-ecricome-2023-maths1",
            title: "ECRICOME 2023 — Épreuve de mathématiques I",
            source: "Concours ECRICOME, session 2023",
            badges: ["DS 2h"],
            annaleTypes: ["ECRICOME"],
            theme: .algebre,
            difficulty: 3,
            statement: """
            Soit $A = \\begin{pmatrix} 2 & 1 \\\\ 1 & 2 \\end{pmatrix}$. \
            Diagonaliser $A$ et en déduire $A^n$ pour tout $n \\in \\mathbb{N}$.
            """,
            solution: """
            $A$ est diagonalisable dans $\\mathbb{R}$, de valeurs propres $1$ et \
            $3$ ; $A^n = P D^n P^{-1}$.
            """,
            markingScheme: "Diagonalisation : 8 points. Puissances : 6 points.",
            questions: [
                AnnQuestion(id: "q1", label: "1 - Diagonalisation", points: 8),
                AnnQuestion(id: "q2", label: "2 - Puissances de la matrice", points: 6),
            ],
            programStatus: .onProgram
        ),
        AnnEntry(
            id: "annale-emlyon-2022-probabilites",
            title: "EMLYON 2022 — Épreuve de mathématiques",
            source: "Concours EMLYON, session 2022",
            badges: ["DS 4h"],
            annaleTypes: ["EMLYON"],
            theme: .probabilites,
            difficulty: 4,
            statement: """
            Une urne contient $n$ boules blanches et $2n$ boules noires. On tire \
            successivement avec remise. Étudier le temps d'attente du premier \
            tirage blanc.
            """,
            solution: """
            Le temps d'attente suit une loi géométrique de paramètre $1/3$ ; son \
            espérance vaut $3$.
            """,
            questions: [
                AnnQuestion(id: "q1", label: "1 - Loi du temps d'attente", points: 5),
                AnnQuestion(id: "q2", label: "2 - Espérance et variance", points: 5),
                AnnQuestion(id: "q3", label: "3 - Simulation", points: 10),
            ],
            programStatus: .onProgram
        ),
        AnnEntry(
            id: "annale-maths1-2021",
            title: "Maths I — Session 2021",
            source: "Épreuve de mathématiques I, session 2021",
            annaleTypes: ["Maths I"],
            theme: .analyse,
            difficulty: 5,
            statement: """
            Étudier l'intégrale $\\displaystyle\\int_0^{+\\infty} \
            \\dfrac{\\ln t}{1 + t^2}\\,\\mathrm{d}t$.
            """,
            solution: "L'intégrale converge et vaut $0$ par le changement $t \\mapsto 1/t$.",
            questions: [
                AnnQuestion(id: "q1", label: "1 - Convergence", points: 6),
                AnnQuestion(id: "q2", label: "2 - Calcul de l'intégrale", points: 6),
            ],
            programStatus: .onProgram
        ),
        AnnEntry(
            id: "annale-maths2-2021",
            title: "Maths II — Session 2021",
            source: "Épreuve de mathématiques II, session 2021",
            annaleTypes: ["Maths II"],
            theme: .algebre,
            difficulty: 5,
            statement: """
            Soit $E$ un $\\mathbb{R}$-espace vectoriel de dimension finie et $f$ un \
            endomorphisme de $E$ vérifiant $f^2 - 3f + 2\\,\\mathrm{Id} = 0$. \
            Montrer que $E = \\ker(f - \\mathrm{Id}) \\oplus \\ker(f - 2\\,\\mathrm{Id})$.
            """,
            solution: "Lemme des noyaux appliqué au polynôme $(X-1)(X-2)$ scindé à racines simples.",
            questions: [
                AnnQuestion(id: "q1", label: "1 - Lemme des noyaux", points: 6),
                AnnQuestion(id: "q2", label: "2 - Somme directe", points: 6),
            ],
            programStatus: .toCheck
        ),
        AnnEntry(
            id: "annale-oral-escp-2023",
            title: "Oral ESCP — 2023",
            source: "Oral ESCP, session 2023",
            badges: ["Oral ESCP"],
            theme: .probabilites,
            difficulty: 4,
            statement: """
            Soit $X$ une variable aléatoire suivant une loi uniforme sur \
            $[0, 1]$. Déterminer la loi de $Y = -\\ln(X)$.
            """,
            solution: "$Y$ suit une loi exponentielle de paramètre $1$.",
            questions: [
                AnnQuestion(id: "q1", label: "1 - Fonction de répartition", points: 5),
                AnnQuestion(id: "q2", label: "2 - Loi de Y", points: 5),
            ],
            programStatus: .onProgram
        ),
    ]
}
