import SwiftUI
import PhotosUI
import UIKit

// MARK: - En-tête
//
// Annales — liste, lecteur et correction de copie.
//
// Portage SwiftUI des composants Expo suivants :
//
//   * `src/components/AnnaleViewer.tsx` (5 718 lignes) — lecteur d'annale :
//     onglets Énoncé / Barème / Commentaires / Corrigé, navigation entre les
//     questions, déverrouillage du corrigé officiel d'un DS écrit, panneau de
//     correction de copie.
//   * `src/components/AnnaleCopyCorrectionModal.tsx` — fenêtre « Correction de
//     copie » : dépôt des pages par partie, suivi de l'avancement, compte rendu
//     noté sur 20.
//   * `src/components/AnnaleCorrectionMonitor.tsx` — moniteur de fond qui
//     rafraîchit les corrections actives toutes les 15 s, même quand l'élève a
//     quitté l'annale.
//
// Règles reprises telles quelles du code Expo :
//
//   * `utils/annaleCopyCorrection.ts` — statuts de job, libellés
//     (`annaleCopyStatusLabel`), `isAnnaleCopyJobActive` (statuts terminaux
//     `ready` / `failed`), conservation des 40 derniers jobs.
//   * `utils/correctionPerformance.ts` — `MAX_CONCURRENT_COPY_UPLOADS = 2`,
//     `VISIBLE_COPY_REFRESH_MS = 1 500`.
//   * `utils/annaleWorkspaceMode.ts` — `usesWrittenAnnaleWorkspace` : une annale
//     écrite se compose sur papier, les oraux ESCP/HEC rangés dans Annales
//     gardent les champs de réponse.
//   * `utils/annaleTypes.ts` — `annaleTypeOptions` par filière.
//   * `utils/annaleBadges.ts` — `displayedAnnaleBadges`, `annaleYear`.
//   * `utils/annaleThemes.ts` — thèmes de tri « Analyse / Algèbre /
//     Probabilités ».
//   * `utils/itemDifficulty.ts` — `DIFFICULTY_LABELS`.
//   * `utils/exerciseBadgeFilter.ts` — menus « Type », « Domaine »,
//     « Difficulté », « Prérequis » (`PREREQUISITE_FILTER_OPTIONS`).
//
// Hors périmètre, volontairement : l'atelier de réponse interactif (dictée,
// tableau blanc, clavier mathématique, console Python, correction IA question
// par question) relève des lots B et C ; la banque d'annales réelle est un
// catalogue généré (plusieurs centaines de sujets) qui n'est pas porté ici, la
// banque embarquée ci-dessous sert de démonstration et de forme d'échange.

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
        case .perfect: return Theme.gradingPerfectHex.color
        case .correct: return Theme.progress
        case .partial: return Theme.gradingPartialHex.color
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

// MARK: - Types d'épreuve par filière

/// Listes de types d'épreuve proposées au filtre, par filière
/// (`ECG_ANNALE_TYPES` et consorts de `annaleTypes.ts`).
enum AnnAnnaleTypes {
    static let ecg: [String] = ["Maths I", "Maths I-III", "Maths II", "EDHEC", "EMLYON", "ECRICOME"]
    static let mp: [String] = ["X-ENS A", "X-ENS B", "X-ENS C", "CCMP 1", "CCMP 2", "CCS 1", "CCS 2", "CCINP 1", "CCINP 2"]
    static let mpi: [String] = ["X-ENS M", "X-ENS M-I", "CCMP 1", "CCMP 2", "CCS 1", "CCS 2", "CCINP 1", "CCINP 2"]
    static let pc: [String] = ["X-ENS", "CCMP 1", "CCMP 2", "CCS 1", "CCS 2", "CCINP 1", "CCINP 2"]

    /// Liste propre à la filière affichée (`annaleTypeOptions`).
    static func options(track: String, specialty: String = "") -> [String] {
        switch track {
        case "ECG":
            return specialty.hasPrefix("Maths appliquées") ? ecg : ecg.filter { $0 != "Maths I-III" }
        case "MP", "MP*", "MP/MP*":
            return mp
        case "MPI":
            return mpi
        case "PC", "PT", "PSI":
            return pc
        default:
            return []
        }
    }
}

// MARK: - Correction de copie : statuts et modèles

/// Statut d'une correction de copie (`AnnaleCopyCorrectionStatus`).
enum AnnCopyStatus: String, Codable, CaseIterable, Identifiable {
    case uploading
    case queued
    case reading
    case grading
    case ready
    case failed

    var id: String { rawValue }

    /// Libellé affiché (`annaleCopyStatusLabel`), mot pour mot.
    var label: String {
        switch self {
        case .uploading: return "Envoi des pages"
        case .queued: return "Dans la file de correction"
        case .reading: return "Lecture de la copie"
        case .grading: return "Vérification des raisonnements"
        case .ready: return "Correction prête"
        case .failed: return "Correction interrompue"
        }
    }

    /// Un job est actif tant qu'il n'a pas atteint un statut terminal
    /// (`isAnnaleCopyJobActive`) : `ready` et `failed` sont terminaux.
    var isActive: Bool { self != .ready && self != .failed }
}

/// Retour du correcteur sur un exercice précis de la copie.
struct AnnCopyExerciseFeedback: Codable, Equatable, Identifiable {
    var label: String
    var score: Double
    var maxScore: Double
    var feedback: String

    var id: String { label }

    /// Note de l'exercice, formatée comme l'app Expo : `score/maxScore`.
    var scoreLabel: String {
        "\(AnnCopyFormat.trimmed(score))/\(AnnCopyFormat.trimmed(maxScore))"
    }
}

/// Compte rendu d'une partie corrigée (`AnnaleCopyCorrectionResult`).
struct AnnCopyResult: Codable, Equatable {
    var score: Double
    var summary: String
    var strengths: [String]
    var improvements: [String]
    var exerciseFeedback: [AnnCopyExerciseFeedback]

    /// Note ramenée sur 20, une décimale, comme `score.toFixed(1)`.
    var scoreLabel: String { AnnCopyFormat.oneDecimal(score) }
}

/// Page photographiée d'une copie (`AnnaleCopyPage`), conservée en base64.
struct AnnCopyPage: Identifiable, Equatable {
    let id = UUID()
    var imageBase64: String
    var mimeType: String

    /// Image décodée, pour l'aperçu de la grille de pages.
    var image: UIImage? {
        guard let data = Data(base64Encoded: imageBase64) else { return nil }
        return UIImage(data: data)
    }

    /// Qualité d'enregistrement reprise de l'app Expo (`quality: 0.78`).
    static let jpegQuality: CGFloat = 0.78
}

/// Une correction de copie suivie par l'application
/// (`AnnaleCopyCorrectionJob`).
struct AnnCopyJob: Codable, Equatable, Identifiable {
    var jobId: String
    var attemptKey: String
    var itemId: String
    var title: String
    /// Partie de l'épreuve couverte par les pages envoyées.
    var partLabel: String
    var status: AnnCopyStatus
    /// Avancement en pourcentage, calculé localement pendant l'envoi.
    var progress: Double
    var estimatedSeconds: Double
    var pageCount: Int
    var createdAt: Double
    var updatedAt: Double
    var notifyOnReady: Bool
    var result: AnnCopyResult? = nil
    var error: String? = nil

    var id: String { jobId }

    var isActive: Bool { status.isActive }

    /// Libellé du statut.
    var statusLabel: String { status.label }

    /// Fraction affichée par la barre : plancher visuel de 3 %, comme Expo.
    var progressFraction: Double {
        max(3, min(100, progress)) / 100
    }

    /// Estimation du temps restant, mot pour mot de la fenêtre Expo.
    var estimateLabel: String {
        guard estimatedSeconds > 0 else { return "" }
        if estimatedSeconds < 60 { return "moins d’une minute" }
        let minutes = Int((estimatedSeconds / 60).rounded(.up))
        return "environ \(minutes) min"
    }
}

/// Mises en forme numériques partagées par la correction de copie.
enum AnnCopyFormat {
    /// Nombre à une décimale, comme `Number.toFixed(1)`.
    static func oneDecimal(_ value: Double) -> String {
        String(format: "%.1f", value)
    }

    /// Nombre débarrassé de sa décimale inutile (barème entier).
    static func trimmed(_ value: Double) -> String {
        if value == value.rounded() { return String(Int(value)) }
        return oneDecimal(value)
    }
}

// MARK: - Persistance locale des corrections

/// Stockage local des corrections de copie, aligné sur la clé Expo
/// `ACCOUNT_STORAGE_KEYS.annaleCopyCorrections`.
enum AnnCopyStore {
    static let storageKey = "prepapp-annale-copy-corrections:v1"
    /// `saveAnnaleCopyCorrectionJobs` conserve les 40 entrées les plus récentes.
    static let maxJobs = 40

    static func load() -> [AnnCopyJob] {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return [] }
        let jobs = (try? JSONDecoder().decode([AnnCopyJob].self, from: data)) ?? []
        return jobs.map { job in
            var normalized = job
            let trimmed = job.partLabel.trimmingCharacters(in: .whitespacesAndNewlines)
            // Compatibilité avec les corrections créées avant les dépôts par
            // partie : elles portent alors le libellé « Copie complète ».
            normalized.partLabel = trimmed.isEmpty ? "Copie complète" : trimmed
            return normalized
        }
    }

    static func save(_ jobs: [AnnCopyJob]) {
        let sorted = jobs.sorted { $0.updatedAt > $1.updatedAt }
        let bounded = Array(sorted.prefix(maxJobs))
        guard let data = try? JSONEncoder().encode(bounded) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}

// MARK: - Relais (endpoint local)

/// Appels au relais Duello pour la correction de copie.
///
/// L'application Expo passe par `resolveRelayEndpoint` (`utils/mathOcr.ts`) et
/// `utils/annaleCopyCorrection.ts`. Le chemin par défaut est `/relay` sur
/// l'origine de l'API, ce que `DuelloAPI.request("relay", …)` reproduit ; le
/// jeton de session Duello authentifie l'appel et sert le quota. Aucune clé de
/// fournisseur n'est utilisée côté client.
enum AnnRelay {
    /// Réponse du relais à toute action (`RelayJobPayload`).
    struct JobPayload: Decodable {
        var jobId: String
        var status: AnnCopyStatus
        var progress: Double
        var estimatedSeconds: Double
        var pageCount: Int
        var createdAt: Double
        var updatedAt: Double
        var result: AnnCopyResult?
        var error: String?
    }

    /// Actions du relais, mot pour mot des valeurs envoyées par Expo.
    enum Action {
        static let create = "create-annale-copy-job"
        static let uploadPage = "upload-annale-copy-page"
        static let start = "start-annale-copy-job"
        static let refresh = "get-annale-copy-job"
        static let retry = "retry-annale-copy-job"
    }

    /// Envoie une action au relais et décode la fiche de correction.
    static func call(
        _ action: String,
        payload: [String: Any] = [:],
        token: String?
    ) async throws -> JobPayload {
        var body = payload
        body["action"] = action
        let data: Data
        do {
            data = try JSONSerialization.data(withJSONObject: body, options: [])
        } catch {
            throw DirectoryError(message: "La copie n’a pas pu être envoyée.")
        }
        return try await DuelloAPI.request(JobPayload.self, "relay", method: "POST", token: token, body: data)
    }

    /// Ajoute une entrée au corps seulement lorsqu'elle porte une valeur :
    /// `JSONSerialization` refuse les valeurs absentes.
    static func put(_ payload: inout [String: Any], _ key: String, _ value: Any?) {
        guard let value else { return }
        payload[key] = value
    }

    /// Envoie une action dont la réponse n'est pas lue.
    ///
    /// Le dépôt d'une page ne renseigne rien : l'app Expo ignore le corps de la
    /// réponse et suit l'avancement en local. Seul le code HTTP compte donc ici,
    /// ce qui évite de faire échouer un envoi réussi sur une forme de réponse
    /// inattendue.
    static func callIgnoringResponse(
        _ action: String,
        payload: [String: Any] = [:],
        token: String?
    ) async throws {
        var body = payload
        body["action"] = action
        let data: Data
        do {
            data = try JSONSerialization.data(withJSONObject: body, options: [])
        } catch {
            throw DirectoryError(message: "La copie n’a pas pu être envoyée.")
        }
        _ = try await DuelloAPI.request("relay", method: "POST", token: token, body: data)
    }
}

// MARK: - Service de correction de copie

/// Envoi et suivi d'une copie, aligné sur `annaleCopyCorrection.ts` et
/// `uploadAnnaleCopyPages.ts`.
enum AnnCopyService {
    /// `MAX_CONCURRENT_COPY_UPLOADS` de `correctionPerformance.ts`.
    static let maxConcurrentUploads = 2
    /// `VISIBLE_COPY_REFRESH_MS` : cadence de rafraîchissement de la fenêtre.
    static let visibleRefreshInterval: TimeInterval = 1.5

    /// Crée le job, envoie les pages puis démarre la correction
    /// (`submitAnnaleCopy`). `onProgress` reçoit l'avancement de l'envoi, en %.
    static func submit(
        attemptKey: String,
        itemId: String,
        title: String,
        partLabel: String,
        subject: String,
        statement: String,
        solution: String?,
        durationMinutes: Int?,
        pages: [AnnCopyPage],
        token: String?,
        onProgress: @escaping (Int) -> Void
    ) async throws -> AnnCopyJob {
        var payload: [String: Any] = [:]
        AnnRelay.put(&payload, "attemptKey", attemptKey)
        AnnRelay.put(&payload, "title", title)
        AnnRelay.put(&payload, "partLabel", partLabel)
        AnnRelay.put(&payload, "subject", subject)
        AnnRelay.put(&payload, "statement", statement)
        AnnRelay.put(&payload, "solution", solution)
        AnnRelay.put(&payload, "durationMinutes", durationMinutes)
        AnnRelay.put(&payload, "pageCount", pages.count)

        let remote = try await AnnRelay.call(AnnRelay.Action.create, payload: payload, token: token)
        var job = merge(
            local: AnnCopyJob(
                jobId: remote.jobId,
                attemptKey: attemptKey,
                itemId: itemId,
                title: title,
                partLabel: partLabel.trimmingCharacters(in: .whitespacesAndNewlines),
                status: remote.status,
                progress: remote.progress,
                estimatedSeconds: remote.estimatedSeconds,
                pageCount: remote.pageCount,
                createdAt: remote.createdAt,
                updatedAt: remote.updatedAt,
                notifyOnReady: false,
                result: remote.result,
                error: remote.error
            ),
            remote: remote
        )
        upsert(job)

        if remote.status == .uploading {
            try await uploadPages(pages, jobId: job.jobId, token: token, onProgress: onProgress)
            var startPayload: [String: Any] = [:]
            AnnRelay.put(&startPayload, "jobId", job.jobId)
            let started = try await AnnRelay.call(AnnRelay.Action.start, payload: startPayload, token: token)
            job = merge(local: job, remote: started)
        }
        upsert(job)
        return job
    }

    /// Relit l'état d'un job côté serveur (`refreshAnnaleCopyJob`).
    static func refresh(job: AnnCopyJob, token: String?) async throws -> AnnCopyJob {
        var payload: [String: Any] = [:]
        AnnRelay.put(&payload, "jobId", job.jobId)
        let remote = try await AnnRelay.call(AnnRelay.Action.refresh, payload: payload, token: token)
        return merge(local: job, remote: remote)
    }

    /// Relance une correction interrompue (`retryAnnaleCopyJob`).
    static func retry(job: AnnCopyJob, token: String?) async throws -> AnnCopyJob {
        var payload: [String: Any] = [:]
        AnnRelay.put(&payload, "jobId", job.jobId)
        let remote = try await AnnRelay.call(AnnRelay.Action.retry, payload: payload, token: token)
        return merge(local: job, remote: remote)
    }

    /// Envoie les pages par groupes de deux (`uploadAnnaleCopyPages`).
    ///
    /// Les pages partent par vagues bornées à `maxConcurrentUploads` : l'Expo
    /// maintient deux envois simultanés pour borner la mémoire et l'occupation
    /// du réseau mobile. Une vague terminée, l'avancement est publié, puis la
    /// vague suivante démarre — un échec interrompt les vagues restantes.
    static func uploadPages(
        _ pages: [AnnCopyPage],
        jobId: String,
        token: String?,
        onProgress: @escaping (Int) -> Void
    ) async throws {
        guard !pages.isEmpty else { return }
        var index = 0
        var completed = 0
        while index < pages.count {
            let end = min(index + maxConcurrentUploads, pages.count)
            let wave = Array(index..<end)
            try await withThrowingTaskGroup(of: Void.self) { group in
                for position in wave {
                    let page = pages[position]
                    group.addTask {
                        var payload: [String: Any] = [:]
                        AnnRelay.put(&payload, "jobId", jobId)
                        AnnRelay.put(&payload, "pageIndex", position)
                        AnnRelay.put(&payload, "image", page.imageBase64)
                        AnnRelay.put(&payload, "mimeType", page.mimeType)
                        try await AnnRelay.callIgnoringResponse(AnnRelay.Action.uploadPage, payload: payload, token: token)
                    }
                }
                for try await _ in group {}
            }
            completed += wave.count
            onProgress(Int((Double(completed) / Double(pages.count) * 100).rounded()))
            index = end
        }
    }

    /// `mergeRelayJob` : la fiche locale garde ce que le relais ne renvoie pas.
    static func merge(local: AnnCopyJob, remote: AnnRelay.JobPayload) -> AnnCopyJob {
        var job = local
        job.status = remote.status
        job.progress = remote.progress
        job.estimatedSeconds = remote.estimatedSeconds
        job.pageCount = remote.pageCount
        job.createdAt = remote.createdAt
        job.updatedAt = remote.updatedAt
        job.result = remote.result
        job.error = remote.error
        return job
    }

    /// Enregistre ou remplace un job dans le stockage local.
    static func upsert(_ job: AnnCopyJob) {
        var jobs = AnnCopyStore.load()
        jobs.removeAll { $0.jobId == job.jobId }
        jobs.insert(job, at: 0)
        AnnCopyStore.save(jobs)
    }
}

// MARK: - Moniteur de correction

/// Maintient les corrections actives à jour même lorsque l'élève quitte
/// l'annale (`AnnaleCorrectionMonitor.tsx`).
///
/// Le moniteur relit toutes les 15 s les corrections encore actives et publie
/// les nouvelles fiches prêtes. Côté Expo, la fin d'une correction déclenche en
/// plus une notification téléphone et une ligne d'historique de note ; ici les
/// fiches prêtes sont exposées dans `readyNotices`, que la liste affiche en
/// bandeau — la notification native est laissée à l'hôte de l'écran.
final class AnnCorrectionMonitor: ObservableObject {
    /// Cadence de re-synchronisation de fond (`AnnaleCorrectionMonitor.tsx`).
    static let backgroundInterval: TimeInterval = 15

    @Published private(set) var jobs: [AnnCopyJob] = []
    /// Corrections terminées depuis le dernier accusé de réception.
    @Published private(set) var readyNotices: [AnnCopyJob] = []

    private var token: String?
    private var pollingTask: Task<Void, Never>?

    /// Jeton de session utilisé par le relais.
    func configure(token: String?) {
        self.token = token
    }

    /// Recharge les fiches conservées localement.
    func load() {
        jobs = AnnCopyStore.load()
    }

    /// Corrections d'une annale donnée, la plus récente d'abord.
    func jobs(for itemId: String) -> [AnnCopyJob] {
        jobs.filter { $0.itemId == itemId }.sorted { $0.updatedAt > $1.updatedAt }
    }

    /// Enregistre une fiche et signale celles qui viennent d'aboutir.
    func upsert(_ job: AnnCopyJob) {
        let previous = jobs.first { $0.jobId == job.jobId }
        jobs.removeAll { $0.jobId == job.jobId }
        jobs.insert(job, at: 0)
        AnnCopyStore.save(jobs)
        if job.status == .ready, previous?.status != .ready {
            readyNotices.insert(job, at: 0)
        }
    }

    /// Accuse réception d'un bandeau de correction prête.
    func dismissNotice(_ job: AnnCopyJob) {
        readyNotices.removeAll { $0.jobId == job.jobId }
    }

    /// Démarre la boucle de fond : une lecture à la fois, jamais deux.
    func start() {
        guard pollingTask == nil else { return }
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.synchronize()
                try? await Task.sleep(nanoseconds: UInt64(AnnCorrectionMonitor.backgroundInterval * 1_000_000_000))
            }
        }
    }

    /// Arrête la boucle de fond.
    func stop() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    /// Relit une fois chaque correction encore active. Un échec réseau ne
    /// change rien : le travail du serveur continue (`refreshAnnaleCopyJob`).
    func synchronize() async {
        let active = jobs.filter { $0.isActive }
        guard !active.isEmpty else { return }
        var updated: [AnnCopyJob] = []
        for job in active {
            if let refreshed = try? await AnnCopyService.refresh(job: job, token: token) {
                updated.append(refreshed)
            } else {
                updated.append(job)
            }
        }
        for job in updated {
            upsert(job)
        }
    }
}

// MARK: - Filtres de la liste

/// Un choix proposé par un menu de filtre.
struct AnnFilterOption: Identifiable, Hashable {
    var id: String
    var label: String
    /// Palier de difficulté, renseigné pour le menu « Difficulté ».
    var difficulty: Int? = nil
}

/// Un menu de filtre, aligné sur `ExerciseBadgeGroup` (`exerciseBadgeFilter.ts`).
struct AnnFilterGroup: Identifiable, Hashable {
    enum Kind: String, Hashable {
        case type
        case domain
        case difficulty
        case prerequisite
    }

    var kind: Kind
    var label: String
    var options: [AnnFilterOption]

    var id: String { kind.rawValue }
}

// MARK: - Écran des annales

/// Écran « Annales » d'une matière : liste filtrable, lecteur d'annale et
/// correction de copie.
///
/// Contrat d'intégration : `AnnalesView()` s'affiche seul, avec la banque de
/// démonstration ; l'hôte peut fournir la banque réelle et le parcours de
/// l'élève par `init(subject:subjectId:track:specialty:entries:)`.
struct AnnalesView: View {
    /// Matière affichée (« Mathématiques »).
    var subject: String
    /// Identifiant de la matière dans le parcours.
    var subjectId: String
    /// Filière de l'élève, qui fixe la liste des types d'épreuve.
    var track: String
    /// Spécialité de l'élève (ECG : « Maths appliquées » ou « Maths
    /// approfondies »).
    var specialty: String
    /// Banque d'annales affichée.
    var entries: [AnnEntry]

    @EnvironmentObject private var session: SessionStore
    @Environment(\.scenePhase) private var scenePhase

    @StateObject private var monitor = AnnCorrectionMonitor()

    @State private var openedEntry: AnnEntry?
    @State private var selection: [AnnFilterGroup.Kind: Set<String>] = [:]

    init(
        subject: String = "Mathématiques",
        subjectId: String = "maths",
        track: String = "ECG",
        specialty: String = "Maths approfondies",
        entries: [AnnEntry] = AnnEntry.builtInBank
    ) {
        self.subject = subject
        self.subjectId = subjectId
        self.track = track
        self.specialty = specialty
        self.entries = entries
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                notices
                if !monitor.jobs.isEmpty {
                    correctionsSection
                }
                filterBar
                list
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .background(Theme.background)
        .onAppear {
            monitor.configure(token: session.token)
            monitor.load()
            monitor.start()
        }
        .onDisappear {
            monitor.stop()
        }
        .onChange(of: scenePhase) { phase in
            // Un retour au premier plan relit tout de suite les corrections en
            // cours ; en arrière-plan, la boucle de fond s'arrête.
            if phase == .active {
                monitor.configure(token: session.token)
                monitor.start()
            } else {
                monitor.stop()
            }
        }
        .onChange(of: session.token) { token in
            monitor.configure(token: token)
        }
        .fullScreenCover(item: $openedEntry) { entry in
            AnnReaderView(
                entry: entry,
                subject: subject,
                track: track,
                specialty: specialty,
                monitor: monitor,
                siblings: orderedEntries,
                onClose: { openedEntry = nil }
            )
            .environmentObject(session)
        }
    }

    // MARK: En-tête

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("ANNALES")
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(Theme.inkSoft)
            Text(subject)
                .font(.system(size: 24, weight: .black))
                .foregroundStyle(Theme.ink)
            Text("Sujets de concours et devoirs surveillés, corrigés par l’IA.")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.inkFaint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Bandeaux de correction prête

    @ViewBuilder
    private var notices: some View {
        ForEach(monitor.readyNotices) { job in
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.progress)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(job.title) — \(job.partLabel)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.ink)
                    Text("Correction prête")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.inkSoft)
                }
                Spacer(minLength: 8)
                Button {
                    monitor.dismissNotice(job)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Theme.inkFaint)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Masquer cette correction")
            }
            .duelloCard()
        }
    }

    // MARK: Corrections en cours

    private var correctionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            DuelloSectionHeader(title: "Mes corrections", subtitle: "Suivi des copies déposées")
            ForEach(monitor.jobs) { job in
                AnnCorrectionRow(job: job) {
                    openEntry(withId: job.itemId)
                }
            }
        }
    }

    // MARK: Filtres

    private var filterBar: some View {
        VStack(alignment: .leading, spacing: 12) {
            DuelloSectionHeader(title: "Filtrer")
            ForEach(filterGroups) { group in
                VStack(alignment: .leading, spacing: 6) {
                    Text(group.label)
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundStyle(Theme.inkFaint)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            DuelloChip(title: "Tout", selected: chosen(group.kind).isEmpty) {
                                selection[group.kind] = []
                            }
                            ForEach(group.options) { option in
                                DuelloChip(
                                    title: option.label,
                                    selected: chosen(group.kind).contains(option.id)
                                ) {
                                    toggle(group.kind, option.id)
                                }
                            }
                        }
                        .padding(.vertical, 1)
                    }
                }
            }
        }
    }

    /// Menus utiles : une famille sans aucun badge est omise, comme
    /// `exerciseBadgeGroups`. Le rôle « Annale » ne distingue rien dans une
    /// liste qui ne contient que des annales.
    private var filterGroups: [AnnFilterGroup] {
        let presentTypes = Set(entries.flatMap { $0.filterTypeValues })
        let orderedTypes = AnnAnnaleTypes.options(track: track, specialty: specialty)
        var typeOptions: [String] = []
        for value in orderedTypes where presentTypes.contains(value) {
            typeOptions.append(value)
        }
        for value in AnnEntry.typeBadges where presentTypes.contains(value) && !typeOptions.contains(value) {
            typeOptions.append(value)
        }
        for value in presentTypes.sorted() where !typeOptions.contains(value) {
            typeOptions.append(value)
        }

        let presentThemes = AnnTheme.allCases.filter { theme in
            entries.contains { $0.theme == theme }
        }
        let presentDifficulties = Set(entries.map { $0.difficulty })

        var groups: [AnnFilterGroup] = []
        if !typeOptions.isEmpty {
            groups.append(AnnFilterGroup(
                kind: .type,
                label: "Type",
                options: typeOptions.map { AnnFilterOption(id: $0, label: $0) }
            ))
        }
        if !presentThemes.isEmpty {
            groups.append(AnnFilterGroup(
                kind: .domain,
                label: "Domaine",
                options: presentThemes.map { AnnFilterOption(id: $0.label, label: $0.label) }
            ))
        }
        if !presentDifficulties.isEmpty {
            groups.append(AnnFilterGroup(
                kind: .difficulty,
                label: "Difficulté",
                options: AnnDifficulty.order
                    .filter { presentDifficulties.contains($0) }
                    .map { AnnFilterOption(id: "d\($0)", label: AnnDifficulty.label(for: $0), difficulty: $0) }
            ))
        }
        groups.append(AnnFilterGroup(
            kind: .prerequisite,
            label: "Prérequis",
            options: AnnFilterGroup.prerequisiteOptions.map { AnnFilterOption(id: $0, label: $0) }
        ))
        return groups
    }

    // MARK: Liste

    private var list: some View {
        VStack(alignment: .leading, spacing: 10) {
            DuelloSectionHeader(
                title: "Annales",
                subtitle: "\(filteredEntries.count) sujet\(filteredEntries.count > 1 ? "s" : "")"
            )
            if filteredEntries.isEmpty {
                DuelloEmptyState(
                    icon: "books.vertical",
                    title: "Aucune annale ne correspond à ces filtres",
                    message: "Change de type, de domaine ou de difficulté."
                )
            } else {
                ForEach(filteredEntries) { entry in
                    AnnEntryCard(entry: entry, job: monitor.jobs(for: entry.id).first) {
                        openedEntry = entry
                    }
                }
            }
        }
    }

    /// Sujets affichés, filtrés puis rangés par thème dans l'ordre fixe
    /// Analyse → Algèbre → Probabilités (`groupItemsByTheme`).
    private var orderedEntries: [AnnEntry] {
        let filtered = filteredEntries
        var ordered: [AnnEntry] = []
        for theme in AnnTheme.allCases {
            ordered.append(contentsOf: filtered.filter { $0.theme == theme })
        }
        ordered.append(contentsOf: filtered.filter { $0.theme == nil })
        return ordered
    }

    private var filteredEntries: [AnnEntry] {
        entries.filter { entry in
            for group in filterGroups {
                let chosen = chosen(group.kind)
                guard !chosen.isEmpty else { continue }
                switch group.kind {
                case .type:
                    if !entry.filterTypeValues.contains(where: { chosen.contains($0) }) { return false }
                case .domain:
                    guard let theme = entry.theme, chosen.contains(theme.label) else { return false }
                case .difficulty:
                    if !chosen.contains("d\(entry.difficulty)") { return false }
                case .prerequisite:
                    if !chosen.contains(entry.prerequisite) { return false }
                }
            }
            return true
        }
    }

    // MARK: Aides de sélection

    private func chosen(_ kind: AnnFilterGroup.Kind) -> Set<String> {
        selection[kind] ?? []
    }

    private func toggle(_ kind: AnnFilterGroup.Kind, _ id: String) {
        var current = chosen(kind)
        if current.contains(id) {
            current.remove(id)
        } else {
            current.insert(id)
        }
        selection[kind] = current
    }

    private func openEntry(withId itemId: String) {
        guard let entry = entries.first(where: { $0.id == itemId }) else { return }
        openedEntry = entry
    }
}

extension AnnFilterGroup {
    /// `PREREQUISITE_FILTER_OPTIONS` de `exerciseBadgeFilter.ts`.
    static let prerequisiteOptions: [String] = ["Prêt", "En partie", "Plus tard"]
}

// MARK: - Fiche d'annale

/// Fiche d'une annale dans la liste : titre, difficulté, badges, thème et
/// avancement de la correction de copie.
struct AnnEntryCard: View {
    let entry: AnnEntry
    var job: AnnCopyJob? = nil
    var onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 8) {
                    Text(entry.title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Theme.ink)
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 8)
                    DuelloPill(
                        text: AnnDifficulty.label(for: entry.difficulty),
                        tone: AnnDifficulty.tone(for: entry.difficulty)
                    )
                }

                if let source = entry.source {
                    Text(source)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.inkFaint)
                        .lineLimit(2)
                }

                badgesRow

                HStack(spacing: 8) {
                    if !entry.questions.isEmpty {
                        Text("\(entry.questions.count) question\(entry.questions.count > 1 ? "s" : "")")
                            .font(.system(size: 11, weight: .heavy))
                            .foregroundStyle(Theme.inkFaint)
                    }
                    if entry.isWrittenPaper {
                        Text("Épreuve écrite · \(entry.durationLabel)")
                            .font(.system(size: 11, weight: .heavy))
                            .foregroundStyle(Theme.inkFaint)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Theme.inkFaint)
                }

                if let job {
                    HStack(spacing: 8) {
                        DuelloPill(
                            text: job.statusLabel,
                            tone: job.status == .ready ? .success : job.status == .failed ? .danger : .ink
                        )
                        if job.status == .ready, let result = job.result {
                            Text("\(result.scoreLabel)/20")
                                .font(.system(size: 13, weight: .heavy))
                                .foregroundStyle(Theme.progress)
                        }
                        Spacer(minLength: 0)
                    }
                }
            }
            .duelloCard()
        }
        .buttonStyle(.plain)
        .accessibilityLabel(entry.title)
    }

    private var badgesRow: some View {
        HStack(spacing: 6) {
            ForEach(entry.displayedBadges, id: \.self) { badge in
                DuelloPill(text: badge, tone: .neutral, icon: "school")
            }
            if let theme = entry.theme {
                DuelloPill(text: theme.label, tone: .neutral, icon: "tag")
            }
            if let status = entry.programStatus, !status.label.isEmpty {
                DuelloPill(text: status.label, tone: .warning, icon: status.icon)
            }
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Ligne de correction

/// Ligne du suivi des corrections : partie déposée, statut et avancement.
struct AnnCorrectionRow: View {
    let job: AnnCopyJob
    var onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(job.title)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Theme.ink)
                            .multilineTextAlignment(.leading)
                        Text(job.partLabel)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Theme.inkFaint)
                    }
                    Spacer(minLength: 8)
                    if job.status == .ready, let result = job.result {
                        Text("\(result.scoreLabel)/20")
                            .font(.system(size: 15, weight: .black))
                            .foregroundStyle(Theme.progress)
                    }
                }

                Text(job.statusLabel)
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(job.status == .failed ? Theme.like : Theme.inkSoft)

                if job.isActive {
                    DuelloProgressTrack(fraction: job.progressFraction)
                }
            }
            .duelloCard()
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(job.title), \(job.partLabel), \(job.statusLabel)")
    }
}

// MARK: - Lecteur d'annale

/// Lecteur d'annale : onglets de document, navigation entre les questions et
/// panneau de correction de copie des épreuves écrites.
///
/// Portage de la partie lecture d'`AnnaleViewer.tsx` : les onglets Énoncé /
/// Barème / Commentaires / Corrigé, les messages de verrouillage du corrigé, le
/// panneau « Annale en cours » et l'ouverture de la fenêtre de correction de
/// copie. L'atelier de réponse (champ de réponse, dictée, tableau blanc,
/// clavier mathématique, console Python) n'est pas porté ici.
struct AnnReaderView: View {
    /// Annale affichée. L'état est modifiable pour passer d'un sujet à l'autre
    /// depuis la même fenêtre de lecture.
    @State private var entry: AnnEntry
    let subject: String
    let track: String
    let specialty: String
    @ObservedObject var monitor: AnnCorrectionMonitor
    /// Sujets de la même matière, pour passer d'une annale à la suivante.
    var siblings: [AnnEntry] = []
    var onClose: () -> Void

    /// Vrai lorsque toutes les réponses de l'annale ont été envoyées : le
    /// barème et les commentaires ne s'ouvrent qu'à ce moment-là
    /// (`attemptComplete` du lecteur Expo). L'hôte qui câble un parcours de
    /// réponse passe `true` ici.
    var attemptComplete: Bool = false
    /// Verdicts déjà connus, indexés par identifiant de question.
    var verdicts: [String: AnnVerdict] = [:]
    /// Questions classiques, marquées d'une étoile (`classicQuestionIds`).
    var classicQuestionIds: Set<String> = []
    /// Questions conseillées pour plus tard : consultables, pastillées rouge.
    var unavailableQuestionIds: Set<String> = []

    @EnvironmentObject private var session: SessionStore

    @State private var mode: AnnDocumentMode = .statement
    @State private var activeQuestionId: String?
    @State private var copySheetOpen = false
    @State private var copyJob: AnnCopyJob?
    @State private var dsUnlocked = false

    init(
        entry: AnnEntry,
        subject: String,
        track: String,
        specialty: String,
        monitor: AnnCorrectionMonitor,
        siblings: [AnnEntry] = [],
        onClose: @escaping () -> Void,
        attemptComplete: Bool = false,
        verdicts: [String: AnnVerdict] = [:],
        classicQuestionIds: Set<String> = [],
        unavailableQuestionIds: Set<String> = []
    ) {
        _entry = State(initialValue: entry)
        self.subject = subject
        self.track = track
        self.specialty = specialty
        _monitor = ObservedObject(wrappedValue: monitor)
        self.siblings = siblings
        self.onClose = onClose
        self.attemptComplete = attemptComplete
        self.verdicts = verdicts
        self.classicQuestionIds = classicQuestionIds
        self.unavailableQuestionIds = unavailableQuestionIds
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            tabs
            Divider().overlay(Theme.border)
            content
            footer
        }
        .background(Theme.background)
        .onAppear {
            activeQuestionId = entry.questions.first?.id
            reloadCopyJob()
        }
        .onChange(of: entry.id) { _ in
            mode = .statement
            activeQuestionId = entry.questions.first?.id
            dsUnlocked = false
            copySheetOpen = false
            reloadCopyJob()
        }
        .fullScreenCover(isPresented: $copySheetOpen) {
            AnnCopyCorrectionSheet(
                itemId: entry.id,
                title: entry.title,
                subject: subject,
                statement: entry.statement ?? entry.title,
                solution: entry.solution,
                durationMinutes: entry.durationHours * 60,
                monitor: monitor,
                initialJob: copyJob,
                onClose: { copySheetOpen = false },
                onNewAttempt: {
                    copyJob = nil
                    reloadCopyJob()
                },
                onJobChange: { job in
                    copyJob = job
                    monitor.upsert(job)
                }
            )
            .environmentObject(session)
        }
    }

    // MARK: En-tête

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Button(action: onClose) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Theme.ink)
                        .frame(width: 34, height: 34)
                        .background(Theme.surfaceMuted)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Fermer le sujet")

                VStack(alignment: .leading, spacing: 2) {
                    Text(subject)
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundStyle(Theme.inkFaint)
                    Text(entry.title)
                        .font(.system(size: 18, weight: .black))
                        .foregroundStyle(Theme.ink)
                }
                Spacer(minLength: 0)
            }
            HStack(spacing: 6) {
                ForEach(entry.displayedBadges, id: \.self) { badge in
                    DuelloPill(text: badge, tone: .neutral, icon: "school")
                }
                if let theme = entry.theme {
                    DuelloPill(text: theme.label, tone: .neutral, icon: "tag")
                }
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 10)
    }

    // MARK: Onglets de document

    private var tabs: some View {
        VStack(alignment: .leading, spacing: 6) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(visibleModes) { candidate in
                        DuelloChip(
                            title: candidate.label,
                            selected: mode == candidate
                        ) {
                            if isEnabled(candidate) { mode = candidate }
                        }
                        .opacity(isEnabled(candidate) ? 1 : 0.45)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 1)
            }
            if !canShowSolution {
                Text(solutionLockMessage)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.inkFaint)
                    .padding(.horizontal, 16)
            }
        }
        .padding(.bottom, 8)
    }

    /// Onglets affichés : un document absent n'apparaît pas.
    private var visibleModes: [AnnDocumentMode] {
        AnnDocumentMode.allCases.filter { candidate in
            switch candidate {
            case .statement: return true
            case .markingScheme: return entry.markingScheme != nil
            case .comments: return entry.comments != nil
            case .solution: return entry.hasOfficialSolution
            }
        }
    }

    private func isEnabled(_ candidate: AnnDocumentMode) -> Bool {
        switch candidate {
        case .statement:
            return true
        case .markingScheme, .comments:
            // Le barème et les commentaires ne s'ouvrent qu'une fois les
            // réponses envoyées.
            return attemptComplete
        case .solution:
            return canShowSolution
        }
    }

    /// Le corrigé d'une épreuve écrite s'ouvre après les heures d'épreuve
    /// écoulées ; celui d'un sujet interactif, après une réponse validée.
    private var canShowSolution: Bool {
        if entry.isWrittenPaper {
            return entry.hasOfficialSolution && dsUnlocked
        }
        return unlockedCorrectionCount > 0
    }

    /// Questions dont le corrigé est déverrouillé (`unlockedCorrectionCount`) :
    /// au-delà de la difficulté 5, seul un verdict validé ouvre le corrigé.
    private var unlockedCorrectionCount: Int {
        entry.questions.filter { question in
            guard let verdict = verdicts[question.id] else { return false }
            return entry.difficulty < 5 || verdict.isValidated
        }.count
    }

    /// Message de verrouillage du corrigé, mot pour mot du lecteur Expo.
    private var solutionLockMessage: String {
        if canShowSolution { return "" }
        if entry.isWrittenPaper {
            return "Corrigé disponible après avoir indiqué que les \(entry.durationHours) heures sont écoulées"
        }
        return "Corrigé disponible après l’envoi d’une réponse"
    }

    // MARK: Contenu

    @ViewBuilder
    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                questionNavigation
                documentBody
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
    }

    @ViewBuilder
    private var questionNavigation: some View {
        if entry.questions.count > 1 {
            VStack(alignment: .leading, spacing: 6) {
                Text("Questions")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(Theme.inkFaint)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(entry.questions) { question in
                            questionChip(question)
                        }
                    }
                    .padding(.vertical, 1)
                }
            }
        }
    }

    private func questionChip(_ question: AnnQuestion) -> some View {
        let selected = question.id == (activeQuestionId ?? entry.questions.first?.id)
        let verdict = verdicts[question.id]
        let isClassic = classicQuestionIds.contains(question.id)
        let isForLater = unavailableQuestionIds.contains(question.id)
        return Button {
            activeQuestionId = question.id
        } label: {
            HStack(spacing: 5) {
                if let verdict {
                    Image(systemName: verdict.icon)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(verdict.color)
                }
                Text(question.displayLabel)
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(selected ? Theme.surface : Theme.inkSoft)
                if isClassic {
                    Image(systemName: "star.fill")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Theme.ink)
                }
                if isForLater {
                    Circle()
                        .fill(Theme.like)
                        .frame(width: 6, height: 6)
                }
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .background(selected ? Theme.ink : Theme.surfaceMuted)
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(selected ? Color.clear : Theme.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel(for: question, verdict: verdict, classic: isClassic, later: isForLater))
    }

    /// Libellé d'accessibilité du bouton de question, mot pour mot du lecteur.
    private func accessibilityLabel(
        for question: AnnQuestion,
        verdict: AnnVerdict?,
        classic: Bool,
        later: Bool
    ) -> String {
        var text = "Question \(question.displayLabel)"
        if let verdict {
            text += ", \(verdict.label.lowercased())"
        }
        if classic { text += ", classique" }
        if later { text += ", conseillée pour plus tard" }
        return text
    }

    @ViewBuilder
    private var documentBody: some View {
        switch mode {
        case .statement:
            documentCard(
                title: nil,
                text: entry.statement,
                empty: "Document indisponible"
            )
        case .markingScheme:
            documentCard(
                title: "Barème",
                text: entry.markingScheme,
                empty: "Document indisponible"
            )
        case .comments:
            documentCard(
                title: "Commentaires",
                text: entry.comments,
                empty: "Document indisponible"
            )
        case .solution:
            solutionBody
        }
    }

    @ViewBuilder
    private var solutionBody: some View {
        if entry.isWrittenPaper {
            documentCard(
                title: "Corrigé",
                text: entry.solution,
                empty: "Corrigé indisponible"
            )
        } else if !canShowSolution {
            lockedSolutionCard
        } else {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(entry.questions) { question in
                    questionCorrectionCard(question)
                }
            }
        }
    }

    /// Corrigé par question, verrouillé tant que la réponse n'est pas validée.
    private func questionCorrectionCard(_ question: AnnQuestion) -> some View {
        let verdict = verdicts[question.id]
        let unlocked = verdict != nil && (entry.difficulty < 5 || (verdict?.isValidated ?? false))
        let isClassic = classicQuestionIds.contains(question.id)
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text("Question \(question.displayLabel)")
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                if isClassic {
                    Image(systemName: "star.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Theme.ink)
                }
                Spacer(minLength: 0)
                Image(systemName: unlocked ? "lock.open" : "lock")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(unlocked ? Theme.ink : Theme.inkFaint)
            }
            Text(questionCorrectionText(question, unlocked: unlocked))
                .font(Theme.readingFont)
                .foregroundStyle(unlocked ? Theme.ink : Theme.inkFaint)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .duelloCard()
    }

    /// Texte du corrigé d'une question, ou l'explication de son verrouillage,
    /// mot pour mot du lecteur Expo.
    private func questionCorrectionText(_ question: AnnQuestion, unlocked: Bool) -> String {
        if unlocked {
            if entry.solution != nil {
                return LatexToUnicode.toUnicodeMath(entry.solution ?? "")
            }
            return "Consulte le compte rendu de cette question pour voir le corrigé de référence disponible."
        }
        if entry.difficulty >= 5, verdicts[question.id] != nil {
            let level = entry.difficulty == 6 ? "Extrême" : "Très difficile"
            return "\(level) · cette réponse doit être entièrement juste pour déverrouiller son corrigé."
        }
        return "Soumets cette réponse pour rendre son corrigé accessible."
    }

    private var lockedSolutionCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "lock")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Theme.inkFaint)
            Text(solutionLockMessage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.inkSoft)
            if entry.isWrittenPaper {
                Text("Soumets l’exercice pour rendre son corrigé accessible.")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.inkFaint)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .duelloCard()
    }

    /// Carte de document : texte composé par `LatexToUnicode`, ou l'état
    /// d'indisponibilité du document.
    ///
    /// Le lecteur Expo charge le PDF puis le compose en HTML ; ici les
    /// documents arrivent retranscrits en texte avec la banque d'annales, et
    /// l'absence de texte veut dire « document indisponible ».
    @ViewBuilder
    private func documentCard(
        title: String?,
        text: String?,
        empty: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title {
                Text(title)
                    .font(.system(size: 13, weight: .heavy))
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.inkSoft)
            }
            if let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(LatexToUnicode.toUnicodeMath(text))
                    .font(Theme.readingFont)
                    .foregroundStyle(Theme.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Image(systemName: "cloud")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(Theme.inkFaint)
                    Text(empty)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Theme.inkSoft)
                    Text("Vérifie ta connexion, puis réessaie.")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.inkFaint)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .duelloCard()
    }

    // MARK: Pied de lecteur

    private var footer: some View {
        VStack(alignment: .leading, spacing: 12) {
            if entry.isWrittenPaper {
                dsUnlockPanel
            }
            siblingNavigation
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 18)
        .background(Theme.surface)
        .overlay(
            Rectangle().fill(Theme.border).frame(height: 1),
            alignment: .top
        )
    }

    /// Panneau « Annale en cours » des épreuves écrites : déverrouillage du
    /// corrigé officiel et dépôt d'une partie de copie.
    private var dsUnlockPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: dsUnlocked ? "lock.open" : "clock")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                VStack(alignment: .leading, spacing: 3) {
                    Text(dsUnlocked
                         ? "Corrigé officiel déverrouillé"
                         : "Annale en cours · \(entry.durationLabel) au total")
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundStyle(Theme.ink)
                    Text(dsUnlocked
                         ? "Tu peux consulter le corrigé et retrouver les corrections de chaque partie."
                         : "Travaille à ton rythme : tu pourras soumettre chaque partie séparément.")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.inkSoft)
                }
                Spacer(minLength: 0)
            }

            VStack(spacing: 8) {
                if dsUnlocked {
                    if entry.hasOfficialSolution {
                        AnnOutlineButton(title: "Voir le corrigé officiel", icon: "doc.text") {
                            mode = .solution
                        }
                    } else {
                        Text("Le corrigé officiel n’est pas encore disponible.")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Theme.inkFaint)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else {
                    AnnOutlineButton(
                        title: "Les \(entry.durationHours) h sont écoulées",
                        icon: "checkmark.circle"
                    ) {
                        dsUnlocked = true
                        if entry.hasOfficialSolution { mode = .solution }
                    }
                }

                AnnSolidButton(title: copyButtonTitle, icon: copyButtonIcon) {
                    reloadCopyJob()
                    copySheetOpen = true
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .duelloCard()
    }

    private var copyButtonTitle: String {
        if copyJob?.status == .ready { return "Ouvrir mes corrections" }
        if copyJob != nil { return "Suivre mes corrections" }
        return "Soumettre une partie"
    }

    private var copyButtonIcon: String {
        copyJob?.status == .ready ? "checkmark.circle" : "camera"
    }

    /// Passage d'une annale à la précédente ou à la suivante.
    @ViewBuilder
    private var siblingNavigation: some View {
        if siblings.count > 1, let index = siblings.firstIndex(where: { $0.id == entry.id }) {
            HStack(spacing: 10) {
                AnnOutlineButton(title: "Annale précédente", icon: "chevron.left") {
                    openSibling(at: index - 1)
                }
                .disabled(index == 0)
                .opacity(index == 0 ? 0.45 : 1)

                AnnOutlineButton(title: "Annale suivante", icon: "chevron.right") {
                    openSibling(at: index + 1)
                }
                .disabled(index == siblings.count - 1)
                .opacity(index == siblings.count - 1 ? 0.45 : 1)
            }
        }
    }

    // MARK: Aides

    /// Recharge la fiche de correction la plus récente de cette annale
    /// (`AnnaleViewer` : dernier job trié par `updatedAt`).
    private func reloadCopyJob() {
        let latest = monitor.jobs(for: entry.id).first
        copyJob = latest
    }

    /// Change d'annale depuis la même fenêtre de lecture. Le changement d'état
    /// déclenche la remise à zéro de l'onglet, de la question et du
    /// déverrouillage, comme à l'ouverture d'un nouveau sujet.
    private func openSibling(at index: Int) {
        guard siblings.indices.contains(index) else { return }
        entry = siblings[index]
    }
}

// MARK: - Modes de document

/// Document affiché par le lecteur (`DocumentMode` du lecteur Expo).
enum AnnDocumentMode: String, CaseIterable, Identifiable {
    case statement
    case markingScheme
    case comments
    case solution

    var id: String { rawValue }

    /// Libellé d'onglet, mot pour mot du lecteur Expo.
    var label: String {
        switch self {
        case .statement: return "Énoncé"
        case .markingScheme: return "Barème"
        case .comments: return "Commentaires"
        case .solution: return "Corrigé"
        }
    }
}

// MARK: - Boutons locaux

/// Bouton principal plein, aligné sur le bouton d'action des écrans Expo.
struct AnnSolidButton: View {
    let title: String
    var icon: String? = nil
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .bold))
                }
                Text(title)
                    .font(.system(size: 14, weight: .heavy))
            }
            .foregroundStyle(Theme.surface)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Theme.ink)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
        }
        .buttonStyle(.plain)
    }
}

/// Bouton secondaire à bord fin, aligné sur les actions d'outil des écrans Expo.
struct AnnOutlineButton: View {
    let title: String
    var icon: String? = nil
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .bold))
                }
                Text(title)
                    .font(.system(size: 14, weight: .heavy))
            }
            .foregroundStyle(Theme.ink)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusMedium)
                    .stroke(Theme.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Sélecteur d'image demandé

/// Sélecteur d'image ouvert par la fenêtre de correction de copie.
enum AnnPickerSheet: String, Identifiable {
    case camera
    case library

    var id: String { rawValue }
}

// MARK: - Fenêtre de correction de copie

/// Fenêtre « Correction de copie » (`AnnaleCopyCorrectionModal.tsx`) : dépôt des
/// pages d'une partie, suivi de la correction en cours, compte rendu noté sur 20.
struct AnnCopyCorrectionSheet: View {
    let itemId: String
    let title: String
    let subject: String
    let statement: String
    let solution: String?
    let durationMinutes: Int?
    @ObservedObject var monitor: AnnCorrectionMonitor
    var initialJob: AnnCopyJob? = nil
    var onClose: () -> Void
    var onNewAttempt: () -> Void
    var onJobChange: (AnnCopyJob) -> Void

    @EnvironmentObject private var session: SessionStore
    @Environment(\.scenePhase) private var scenePhase

    @State private var partLabel = ""
    @State private var pages: [AnnCopyPage] = []
    @State private var submitting = false
    @State private var uploadProgress = 0
    @State private var errorMessage = ""
    @State private var activePicker: AnnPickerSheet?
    @State private var refreshTick = 0
    @State private var job: AnnCopyJob?

    /// Nombre de pages acceptées pour une partie (`slice(0, 24)` côté Expo).
    private static let maxPages = 24

    /// Clé d'une tentative : compte, annale et instant de l'ouverture.
    private let attemptKey: String

    init(
        itemId: String,
        title: String,
        subject: String,
        statement: String,
        solution: String?,
        durationMinutes: Int?,
        monitor: AnnCorrectionMonitor,
        initialJob: AnnCopyJob? = nil,
        onClose: @escaping () -> Void,
        onNewAttempt: @escaping () -> Void,
        onJobChange: @escaping (AnnCopyJob) -> Void
    ) {
        self.itemId = itemId
        self.title = title
        self.subject = subject
        self.statement = statement
        self.solution = solution
        self.durationMinutes = durationMinutes
        self.monitor = monitor
        self.initialJob = initialJob
        self.onClose = onClose
        self.onNewAttempt = onNewAttempt
        self.onJobChange = onJobChange
        self.attemptKey = "\(itemId):\(Int(Date().timeIntervalSince1970 * 1000))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().overlay(Theme.border)
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    bodyContent
                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.like)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                .padding(20)
                .padding(.bottom, 30)
            }
        }
        .background(Theme.background)
        .onAppear {
            job = initialJob ?? monitor.jobs(for: itemId).first
        }
        .onChange(of: scenePhase) { phase in
            // Le retour au premier plan relit tout de suite la correction en
            // cours, sans attendre la fin de l'intervalle de rafraîchissement.
            if phase == .active { refreshTick += 1 }
        }
        .task(id: "\(pollingKey)-\(refreshTick)") {
            await pollActiveJob()
        }
        .sheet(item: $activePicker) { picker in
            switch picker {
            case .camera:
                AnnCameraPicker { page in
                    activePicker = nil
                    append(pages: [page])
                }
                .ignoresSafeArea()
            case .library:
                AnnPhotoLibraryPicker(selectionLimit: max(1, Self.maxPages - pages.count)) { picked in
                    activePicker = nil
                    append(pages: picked)
                }
                .ignoresSafeArea()
            }
        }
    }

    // MARK: En-tête

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("CORRECTION DE COPIE")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                Text(title)
                    .font(.system(size: 20, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .padding(8)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Fermer")
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 14)
    }

    // MARK: Corps

    @ViewBuilder
    private var bodyContent: some View {
        if let job {
            if job.status == .ready, let result = job.result {
                readyContent(job: job, result: result)
            } else {
                progressContent(job: job)
            }
        } else {
            depositContent
        }
    }

    // MARK: Dépôt d'une partie

    private var depositContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !history.isEmpty {
                VStack(alignment: .leading, spacing: 9) {
                    Text("Parties déjà soumises")
                        .font(.system(size: 16, weight: .heavy))
                        .foregroundStyle(Theme.ink)
                    ForEach(history) { entry in
                        Button {
                            job = entry
                            onJobChange(entry)
                        } label: {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(entry.partLabel)
                                        .font(.system(size: 14, weight: .heavy))
                                        .foregroundStyle(Theme.ink)
                                    Text(entry.statusLabel)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(Theme.inkSoft)
                                }
                                Spacer(minLength: 8)
                                if entry.status == .ready, let result = entry.result {
                                    Text("\(result.scoreLabel)/20")
                                        .font(.system(size: 14, weight: .black))
                                        .foregroundStyle(Theme.ink)
                                } else {
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundStyle(Theme.inkSoft)
                                }
                            }
                            .padding(13)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Theme.surface)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.radiusMedium)
                                    .stroke(Theme.border, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Ouvrir la correction \(entry.partLabel)")
                    }
                }
            }

            VStack(alignment: .leading, spacing: 7) {
                Text("Partie à faire corriger")
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                TextField("Ex. Exercice 1, partie II", text: $partLabel)
                    .textFieldStyle(.plain)
                    .font(.system(size: 16))
                    .foregroundStyle(Theme.ink)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .background(Theme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.radiusMedium)
                            .stroke(Theme.border, lineWidth: 1)
                    )
                    .accessibilityLabel("Partie à faire corriger")
                Text("Tu pourras revenir un autre jour et soumettre une autre partie séparément.")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.inkSoft)
            }

            Text("Ajoute uniquement les pages de cette partie, dans l’ordre. Vérifie qu’elles sont nettes, cadrées et sans reflet.")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.inkSoft)

            VStack(spacing: 10) {
                AnnOutlineButton(title: "Photographier une page", icon: "camera") {
                    requestCamera()
                }
                AnnOutlineButton(title: "Importer plusieurs photos", icon: "photo.on.rectangle") {
                    errorMessage = ""
                    activePicker = .library
                }
            }

            pageGrid

            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "bell")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Text("Tu seras prévenu dans Duello, ou sur ton téléphone si l’application est fermée.")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.inkSoft)
                Spacer(minLength: 0)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusMedium)
                    .stroke(Theme.border, lineWidth: 1)
            )

            submitButton
        }
    }

    private var pageGrid: some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
            spacing: 10
        ) {
            ForEach(Array(pages.enumerated()), id: \.element.id) { index, page in
                ZStack(alignment: .topTrailing) {
                    VStack(alignment: .leading, spacing: 0) {
                        Group {
                            if let image = page.image {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                            } else {
                                ZStack {
                                    Theme.surfaceMuted
                                    Image(systemName: "doc.text")
                                        .font(.system(size: 22, weight: .semibold))
                                        .foregroundStyle(Theme.inkFaint)
                                }
                            }
                        }
                        .frame(height: 145)
                        .frame(maxWidth: .infinity)
                        .clipped()
                        Text("Page \(index + 1)")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Theme.ink)
                            .padding(9)
                    }
                    .background(Theme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.radiusMedium)
                            .stroke(Theme.border, lineWidth: 1)
                    )

                    Button {
                        removePage(at: index)
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Theme.like)
                            .padding(7)
                            .background(Theme.surface)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .padding(7)
                    .accessibilityLabel("Supprimer la page \(index + 1)")
                }
            }
        }
    }

    private var submitButton: some View {
        let disabled = pages.isEmpty || partLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || submitting
        return Button {
            Task { await submit() }
        } label: {
            HStack(spacing: 9) {
                if submitting {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(Theme.surface)
                } else {
                    Image(systemName: "sparkles")
                        .font(.system(size: 15, weight: .bold))
                }
                Text(submitLabel)
                    .font(.system(size: 14, weight: .heavy))
            }
            .foregroundStyle(Theme.surface)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(Theme.ink)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
            .opacity(disabled ? 0.45 : 1)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }

    private var submitLabel: String {
        if submitting { return "Envoi \(uploadProgress)%…" }
        let count = pages.count
        return "Lancer la correction (\(count) page\(count > 1 ? "s" : ""))"
    }

    // MARK: Correction en cours

    private func progressContent(job: AnnCopyJob) -> some View {
        VStack(spacing: 13) {
            if job.status == .failed {
                Image(systemName: "exclamationmark.circle")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(Theme.like)
            } else {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(Theme.ink)
            }
            Text(job.statusLabel)
                .font(.system(size: 20, weight: .heavy))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
            Text(job.partLabel)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
            if !job.estimateLabel.isEmpty {
                Text("Temps restant estimé : \(job.estimateLabel)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.ink)
            }
            DuelloProgressTrack(fraction: job.progressFraction, tint: Theme.ink, height: 8)
            Text(job.error ?? "Tu peux quitter cette page : la correction continue sur le serveur.")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)

            if job.status == .failed {
                AnnSolidButton(title: "Relancer la correction", icon: "arrow.clockwise") {
                    Task { await retry(job: job) }
                }
            }
            AnnOutlineButton(title: "Voir ou soumettre une autre partie", icon: "square.stack") {
                onNewAttempt()
            }
        }
        .frame(maxWidth: .infinity)
        .padding(22)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLarge))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusLarge)
                .stroke(Theme.border, lineWidth: 1)
        )
    }

    // MARK: Compte rendu

    private func readyContent(job: AnnCopyJob, result: AnnCopyResult) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(job.partLabel)
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(Theme.ink)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Theme.surface)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Theme.border, lineWidth: 1))

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(result.scoreLabel)
                        .font(.system(size: 38, weight: .black))
                    Text(" / 20")
                        .font(.system(size: 19, weight: .bold))
                }
                .foregroundStyle(Theme.surface)
                Text("Note de cette partie, ramenée sur 20")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.surface)
                    .opacity(0.82)
                Text(LatexToUnicode.toUnicodeMath(result.summary))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.surface)
                    .padding(.top, 6)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(22)
            .background(Theme.ink)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLarge))

            if !result.strengths.isEmpty {
                resultSection(title: "Points forts", icon: "checkmark.circle", items: result.strengths)
            }
            if !result.improvements.isEmpty {
                resultSection(title: "À retravailler", icon: "wrench.and.screwdriver", items: result.improvements)
            }

            ForEach(result.exerciseFeedback) { exercise in
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(exercise.label)
                            .font(.system(size: 14, weight: .heavy))
                            .foregroundStyle(Theme.ink)
                        Spacer(minLength: 8)
                        Text(exercise.scoreLabel)
                            .font(.system(size: 14, weight: .black))
                            .foregroundStyle(Theme.ink)
                    }
                    Text(LatexToUnicode.toUnicodeMath(exercise.feedback))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .duelloCard()
            }

            AnnOutlineButton(title: "Soumettre une autre partie", icon: "arrow.clockwise") {
                onNewAttempt()
            }
        }
    }

    private func resultSection(title: String, icon: String, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Text(title)
                    .font(.system(size: 17, weight: .heavy))
                    .foregroundStyle(Theme.ink)
            }
            ForEach(items, id: \.self) { item in
                Text(LatexToUnicode.toUnicodeMath("• \(item)"))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .duelloCard()
    }

    // MARK: Aides de données

    /// Parties déjà soumises pour cette annale, la plus récente d'abord.
    private var history: [AnnCopyJob] {
        monitor.jobs(for: itemId).filter { $0.jobId != job?.jobId }
    }

    private func append(pages additions: [AnnCopyPage]) {
        guard !additions.isEmpty else { return }
        var next = pages
        next.append(contentsOf: additions)
        pages = Array(next.prefix(Self.maxPages))
    }

    private func removePage(at index: Int) {
        guard pages.indices.contains(index) else { return }
        pages.remove(at: index)
    }

    /// Ouvre l'appareil photo, ou la photothèque à défaut.
    ///
    /// `Info.plist` ne déclare pas encore `NSCameraUsageDescription` : sans
    /// cette clé, iOS interrompt l'application dès l'accès à l'appareil photo.
    /// Le bouton se replie donc sur la photothèque en affichant le message de
    /// permission de l'application Expo, plutôt que de rester sans effet.
    private func requestCamera() {
        errorMessage = ""
        let available = UIImagePickerController.isSourceTypeAvailable(.camera)
        let declared = (Bundle.main.object(forInfoDictionaryKey: "NSCameraUsageDescription") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty == false
        if available && declared {
            activePicker = .camera
            return
        }
        errorMessage = "Autorise l’appareil photo pour photographier ta copie."
        activePicker = .library
    }

    // MARK: Actions

    private func submit() async {
        let trimmed = partLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        if submitting || job != nil || pages.isEmpty { return }
        guard !trimmed.isEmpty else {
            errorMessage = "Indique la partie de l’annale couverte par ces pages."
            return
        }
        submitting = true
        errorMessage = ""
        uploadProgress = 0
        let snapshot = pages
        do {
            let created = try await AnnCopyService.submit(
                attemptKey: attemptKey,
                itemId: itemId,
                title: title,
                partLabel: trimmed,
                subject: subject,
                statement: statement,
                solution: solution,
                durationMinutes: durationMinutes,
                pages: snapshot,
                token: session.token,
                onProgress: { value in
                    Task { @MainActor in uploadProgress = value }
                }
            )
            job = created
            monitor.upsert(created)
            onJobChange(created)
        } catch let error as DirectoryError {
            let message = error.message.trimmingCharacters(in: .whitespacesAndNewlines)
            errorMessage = message.isEmpty ? "La copie n’a pas pu être envoyée." : message
        } catch {
            errorMessage = "La copie n’a pas pu être envoyée."
        }
        submitting = false
    }

    private func retry(job: AnnCopyJob) async {
        do {
            let refreshed = try await AnnCopyService.retry(job: job, token: session.token)
            self.job = refreshed
            monitor.upsert(refreshed)
            onJobChange(refreshed)
        } catch {
            errorMessage = "La correction n’a pas pu être relancée."
        }
    }

    // MARK: Suivi de la correction affichée

    /// Identifiant de suivi : la boucle de rafraîchissement repart dès que la
    /// fiche change (`useVisibleAnnaleCopyJob`).
    private var pollingKey: String {
        guard let job else { return "aucune" }
        return "\(job.jobId)-\(job.status.rawValue)-\(Int(job.updatedAt))"
    }

    /// Une seule lecture à la fois, uniquement tant que la copie est active ;
    /// une coupure réseau n'annule pas le travail du serveur, la boucle repart
    /// donc au tour suivant. Le retour au premier plan relance la boucle via
    /// l'identifiant de tâche, et la fermeture de la fenêtre l'interrompt.
    private func pollActiveJob() async {
        guard let current = job, current.isActive else { return }
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: UInt64(AnnCopyService.visibleRefreshInterval * 1_000_000_000))
            if Task.isCancelled { return }
            guard let refreshed = try? await AnnCopyService.refresh(job: current, token: session.token) else {
                continue
            }
            job = refreshed
            monitor.upsert(refreshed)
            onJobChange(refreshed)
            if !refreshed.isActive { return }
        }
    }
}

// MARK: - Sélecteurs de photos

/// Sélecteur de la photothèque, à sélection multiple, sans autorisation
/// préalable (`PHPickerViewController`, iOS 14+). Reprend
/// `ImagePicker.launchImageLibraryAsync({ allowsMultipleSelection: true })`.
struct AnnPhotoLibraryPicker: UIViewControllerRepresentable {
    let selectionLimit: Int
    let onPick: ([AnnCopyPage]) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = .images
        configuration.selectionLimit = max(1, selectionLimit)
        let controller = PHPickerViewController(configuration: configuration)
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    /// Rassemble les images choisies, hors du fil principal.
    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        private let onPick: ([AnnCopyPage]) -> Void
        private let collector = AnnPageCollector()

        init(onPick: @escaping ([AnnCopyPage]) -> Void) {
            self.onPick = onPick
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            guard !results.isEmpty else { return }
            let group = DispatchGroup()
            let collector = self.collector
            for result in results {
                let provider = result.itemProvider
                guard provider.canLoadObject(ofClass: UIImage.self) else { continue }
                group.enter()
                _ = provider.loadObject(ofClass: UIImage.self) { object, _ in
                    defer { group.leave() }
                    guard let image = object as? UIImage,
                          let data = image.jpegData(compressionQuality: AnnCopyPage.jpegQuality)
                    else { return }
                    collector.append(AnnCopyPage(
                        imageBase64: data.base64EncodedString(),
                        mimeType: "image/jpeg"
                    ))
                }
            }
            let onPick = self.onPick
            group.notify(queue: .main) {
                onPick(collector.snapshot())
            }
        }
    }
}

/// Accumulateur de pages alimenté depuis plusieurs fils.
final class AnnPageCollector {
    private let lock = NSLock()
    private var pages: [AnnCopyPage] = []

    func append(_ page: AnnCopyPage) {
        lock.lock()
        pages.append(page)
        lock.unlock()
    }

    func snapshot() -> [AnnCopyPage] {
        lock.lock()
        defer { lock.unlock() }
        return pages
    }
}

/// Appareil photo (`ImagePicker.launchCameraAsync`). La cible est iOS : la
/// présentation exige la clé `NSCameraUsageDescription` dans `Info.plist` et
/// l'autorisation de l'utilisateur. Sur un appareil sans appareil photo — le
/// simulateur, par exemple — le sélecteur retombe sur la photothèque.
struct AnnCameraPicker: UIViewControllerRepresentable {
    let onPick: (AnnCopyPage) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let controller = UIImagePickerController()
        controller.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera)
            ? .camera
            : .photoLibrary
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        private let onPick: (AnnCopyPage) -> Void

        init(onPick: @escaping (AnnCopyPage) -> Void) {
            self.onPick = onPick
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            picker.dismiss(animated: true)
            guard let image = info[.originalImage] as? UIImage,
                  let data = image.jpegData(compressionQuality: AnnCopyPage.jpegQuality)
            else { return }
            onPick(AnnCopyPage(imageBase64: data.base64EncodedString(), mimeType: "image/jpeg"))
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}
