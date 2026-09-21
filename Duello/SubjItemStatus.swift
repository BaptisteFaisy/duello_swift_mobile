//
//  SubjItemStatus.swift
//  Duello
//
//  Lot 9-H « lignes de chapitre, étiquettes et barre de progression »
//  (préfixe `Subj`).
//
//  Fichiers source Expo portés :
//    - src/screens/SubjectsScreen.tsx
//        · lignes 3009-3027 : statuts de programme (`ProgramStatusTag`)
//        · lignes 3096-3141 : meilleure note, statut et détail des prérequis
//        · lignes 3347-3384 : textes du panneau de prérequis
//    - src/utils/annaleThemes.ts : `ANNALE_THEME_LABELS`
//    - src/utils/exerciseBadgeFilter.ts : `prerequisiteFilterValue`
//    - src/utils/exerciseProgress.ts : `progressFraction`
//
//  Déjà portés ailleurs et réutilisés tels quels (jamais redéfinis ici) :
//  `ItemProgress` / `ItemOutcome` (ProgressStore.swift), `ExGFormat.score`
//  (port de `formatGradingScore`), `TrainDifficultyPill`, `DuelloAvatar`.
//  Cible iOS 16, aucune API iOS 17.
//
import SwiftUI

/// Périmètre d'un sujet par rapport au programme 2026
/// (`ChapterItem['programStatus']`).
///
/// `auProgramme` est la valeur par défaut et la seule qui n'est jamais rendue :
/// l'étiquette n'existe que pour signaler un écart.
enum SubjProgramStatus: String, CaseIterable {
    case auProgramme = "au-programme"
    case aVerifier = "a-verifier"
    case horsProgramme = "hors-programme"

    /// Vrai pour les deux statuts que `ProgramStatusTag` rend réellement.
    var isVisible: Bool { self != .auProgramme }

    /// Libellé de l'étiquette, repris mot pour mot de la source.
    var label: String {
        switch self {
        case .horsProgramme: return "Hors programme 2026"
        case .aVerifier: return "Programme 2026 à vérifier"
        case .auProgramme: return ""
        }
    }

    /// Icône SF Symbol transposée des Ionicons de la source
    /// (`warning-outline`, `help-circle-outline`).
    var systemImage: String {
        switch self {
        case .horsProgramme: return "exclamationmark.triangle"
        case .aVerifier: return "questionmark.circle"
        case .auProgramme: return "checkmark.circle"
        }
    }
}

/// Libellés des thèmes d'annales (`ANNALE_THEME_LABELS`).
///
/// La résolution d'un thème depuis les badges (`visibleItemTheme`) n'est pas
/// portée : la banque servie en Swift n'expose pas encore `badges` / `theme`.
enum SubjItemThemeLabel {
    /// Libellé d'un thème ; `nil` hors des trois thèmes connus.
    static func label(for theme: String) -> String? {
        switch theme {
        case "analyse": return "Analyse"
        case "algebre": return "Algèbre"
        case "probabilites": return "Probabilités"
        default: return nil
        }
    }
}

/// État des prérequis d'un sujet (`prerequisiteFilterValue`).
///
/// Le badge ne porte qu'une décision globale : « En partie » signifie
/// strictement qu'une fraction des questions est faisable, jamais seulement
/// qu'un chapitre est en cours.
enum SubjPrerequisiteStatus: String, CaseIterable {
    case ready = "Prêt"
    case partly = "En partie"
    case later = "Plus tard"

    /// Décision globale à partir des questions traitables et du total affiché.
    static func value(availableCount: Int, totalCount: Int) -> SubjPrerequisiteStatus {
        if availableCount == totalCount { return .ready }
        return availableCount > 0 ? .partly : .later
    }

    /// Icône SF Symbol (`checkmark-circle-outline`, `time-outline`,
    /// `alert-circle-outline`).
    var systemImage: String {
        switch self {
        case .ready: return "checkmark.circle"
        case .partly: return "clock"
        case .later: return "exclamationmark.circle"
        }
    }

    /// Teinte du symbole (`prerequisitesReady`, `inkSoft`, `prerequisitesMissing`).
    var tintHex: Int {
        switch self {
        case .ready: return 0x15803D
        case .partly: return 0x555B58
        case .later: return 0xB42318
        }
    }

    var tint: Color { Color(hex: tintHex) }

    /// Fond de la pastille (`prerequisitesButtonReady/Started/NotReady`).
    var backgroundHex: Int {
        switch self {
        case .ready: return 0xE7F7EC
        case .partly: return 0xF4F5F4
        case .later: return 0xFDECEC
        }
    }

    var background: Color { Color(hex: backgroundHex) }
}

/// Fraction de remplissage d'une fiche d'item (`progressFraction`).
enum SubjItemProgress {
    /// Part remplie d'après le meilleur résultat acquis : une réussite garde sa
    /// barre à 100 % pendant toutes ses reprises.
    static func fraction(_ progress: ItemProgress?) -> Double {
        guard let outcome = progress?.bestOutcome else { return 0 }
        switch outcome {
        case .fail: return 0.25
        case .partial: return 0.6
        case .success: return 1
        }
    }
}

/// Premier profil affiché parmi les réussites (`VeryHardExerciseAchiever`).
struct SubjItemAchiever: Equatable, Identifiable {
    let id: String
    let displayName: String
    /// Photo de profil, quand elle est servie.
    var photoURL: URL?

    /// Initiale de repli (`firstAchieverInitial`), en majuscule française.
    var initial: String {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.first else { return "?" }
        return String(first).uppercased(with: Locale(identifier: "fr_FR"))
    }
}

/// Avancement question par question (`granularProgress`).
struct SubjGranularProgress: Equatable {
    var completed: Int
    var total: Int

    /// Vrai seulement avec un total : un avancement sans dénominateur ne prime
    /// pas sur la fraction du meilleur résultat.
    var isUsable: Bool { total > 0 }

    var fraction: Double { total > 0 ? Double(completed) / Double(total) : 0 }
}

/// Données d'une fiche d'item : `ChapterItem` réduit à ce que la carte lit.
///
/// Les rôles (`visibleRoles`) puis les badges visibles (`visibleBadges`) sont
/// déjà concaténés dans `badges`, dans l'ordre d'affichage de la source.
struct SubjItemCardModel: Equatable {
    var title: String
    var difficulty: Int?
    var badges: [String] = []
    /// Domaine fiable d'une annale (`visibleItemTheme`), `nil` pour les colles
    /// et les annales où la pastille disparaît.
    var themeLabel: String?
    var programStatus: SubjProgramStatus = .auProgramme
    /// Meilleure note d'un bilan terminé, sur 20.
    var bestScore: Double?
    /// Note de prérequis rédigée (`prerequisiteNote`).
    var prerequisiteNote: String?
    /// Relecture des prérequis en cours (`prerequisiteReview.status == 'pending'`).
    var isPrerequisiteReviewPending: Bool = false
    var missingPrerequisites: [String] = []
    /// Prérequis entamés mais pas terminés : ni acquis, ni vraiment manquants.
    var startedPrerequisites: [String] = []
    /// Questions que l'avancement actuel permet réellement de traiter.
    var availableQuestionCount: Int = 0
    /// Questions totales affichées dans le lecteur.
    var totalQuestionCount: Int = 0
    /// Premier profil affiché, réservé aux exercices très difficiles
    /// (`item.difficulty >= 5`).
    var firstAchiever: SubjItemAchiever?
    var granularProgress: SubjGranularProgress?
}

/// Textes du détail des prérequis (`prerequisitesPanel`).
enum SubjPrerequisiteCopy {
    /// Relecture des prérequis d'un nouvel exercice en cours.
    static let reviewPending =
        "Les prérequis précis de ce nouvel exercice sont en cours de vérification."

    /// Un sujet qui suppose une année entière de cours annonce ce qu'il en
    /// reste : la liste des chapitres tiendrait sur dix lignes sans rien
    /// apprendre de plus.
    static func note(_ note: String, missing: Int, started: Int) -> String {
        var text = "Cet oral se travaille avec \(note) : \(missing) reste"
        if missing > 1 { text += "nt" }
        text += " à voir"
        if started > 0 { text += ", \(started) en cours d’étude" }
        return text + "."
    }

    /// Liste des prérequis manquants, séparés par un point médian.
    static func missing(_ names: [String]) -> String {
        "À connaître avant de commencer : \(names.joined(separator: " · "))"
    }

    /// Liste des prérequis entamés.
    static func started(_ names: [String]) -> String {
        "Encore en cours d’étude : \(names.joined(separator: " · "))."
    }
}
