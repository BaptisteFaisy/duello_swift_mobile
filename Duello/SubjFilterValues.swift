//
//  SubjFilterValues.swift
//  Duello
//
//  Lot « Subj » (9-D) — valeurs, libellés et formatage des filtres du catalogue.
//
//  Fichiers source Expo portés (libellés repris mot pour mot) :
//    - src/screens/SubjectsScreen.tsx (lignes 1166-1172, 1246-1249, 1287-1288,
//        1399, 1541-1554) : `ExerciseFilterValue`, `ClassicFilterValue`,
//        `isPrerequisiteFilterValue`, `badgeFilterValueLabel`,
//        `SUBJECTS_DROPDOWN_SCOPE`, `DIFFICULTY_MENU_MIN_WIDTH`,
//        `CLASSIQUE_OPTIONS`, `errorDateFormatter`, `formatErrorDate`,
//        `formatErrorRecurrence`.
//    - src/utils/exerciseBadgeFilter.ts : `ExerciseBadgeFilterValue` et
//        `PrerequisiteFilterValue` (les deux branches de la réunion
//        `ExerciseFilterValue`), `PREREQUISITE_FILTER_OPTIONS`.
//    - src/utils/itemDifficulty.ts : `DIFFICULTY_LABELS`, réutilisé via
//        `TrainDifficulty.label(for:)` (jamais recopié).
//
//  `ERROR_SORT_OPTIONS` (ligne 1556) est **déjà porté** par le lot 9-E sous
//  `SubjErrorSortOptions` (`SubjFlashcardSelection.swift`) : il n'est pas
//  redéclaré ici (types uniques).
//
//  Cible : iOS 16, aucune dépendance externe.
//
import CoreGraphics
import Foundation

// MARK: - État de prérequis

/// `PrerequisiteFilterValue` : état d'un prérequis proposé au filtre.
enum SubjPrerequisiteFilterValue: String, CaseIterable, Identifiable {
    case ready = "Prêt"
    case partly = "En partie"
    case later = "Plus tard"

    var id: String { rawValue }

    /// `PREREQUISITE_FILTER_OPTIONS`, dans l'ordre affiché.
    static let options: [SubjPrerequisiteFilterValue] = [.ready, .partly, .later]
}

// MARK: - Valeur de filtre

/// `ExerciseFilterValue` = `ExerciseBadgeFilterValue | PrerequisiteFilterValue`.
///
/// Côté Expo la valeur est un `number | string` : un palier de difficulté, un
/// badge, ou l'un des trois états de prérequis. Le test `typeof value ===
/// 'number'` qui distingue les paliers devient ici un cas d'énumération, donc
/// infaillible à la compilation.
enum SubjExerciseFilterValue: Hashable {
    /// Un badge, un rôle ou une épreuve du catalogue
    /// (`ExerciseBadge | ExerciseRole | AnnaleType`).
    case badge(String)
    /// Un palier de difficulté (`Difficulty`, 1 à 6).
    case difficulty(Int)
    /// Un état de prérequis.
    case prerequisite(SubjPrerequisiteFilterValue)

    /// `isPrerequisiteFilterValue` : vrai pour « Prêt / En partie / Plus tard ».
    /// `nil` sinon (badge ou palier).
    var prerequisiteValue: SubjPrerequisiteFilterValue? {
        if case let .prerequisite(value) = self { return value }
        return nil
    }
}

extension SubjExerciseFilterValue: Identifiable {
    /// Clé de liste : reprend la forme `${typeof badge}-${badge}` du JSX
    /// (`number-4`, `string-DS 2h`), prolongée au cas prérequis.
    var id: String {
        switch self {
        case .badge(let badge): return "string-\(badge)"
        case .difficulty(let level): return "number-\(level)"
        case .prerequisite(let value): return "prerequisite-\(value.rawValue)"
        }
    }
}

// MARK: - Filtre « Classique »

/// `ClassicFilterValue` : tout le catalogue, ou les seuls classiques.
enum SubjClassicFilterValue: String, CaseIterable, Identifiable {
    case all = "Tout"
    case classiques = "Classiques"

    var id: String { rawValue }
}

/// `CLASSIQUE_OPTIONS` : les deux choix du menu « Classique », dans l'ordre.
enum SubjClassicOptions {
    static let all: [SubjClassicFilterValue] = [.all, .classiques]
}

// MARK: - Libellés

/// Libellés et libellés d'accessibilité des filtres, repris mot pour mot du JSX.
enum SubjFilterCopy {
    /// Libellé de l'absence de filtre (`'Tout'`).
    static let tout = "Tout"
    static let difficulty = "Difficulté"
    static let notions = "Notions"
    static let classique = "Classique"

    /// `accessibilityLabel` du menu « Notions », qui n'a aucune option.
    static let notionsAccessibilityLabel = "Notions : aucune option disponible"

    /// `badgeFilterValueLabel` : « Tout » sans valeur, le libellé du palier pour
    /// une difficulté, la valeur brute sinon. Le repli sur le numéro couvre un
    /// palier hors barème, là où `DIFFICULTY_LABELS[value]` rendrait `undefined`.
    static func label(for value: SubjExerciseFilterValue?) -> String {
        guard let value = value else { return tout }
        switch value {
        case .difficulty(let level):
            let label = TrainDifficulty.label(for: level)
            return label.isEmpty ? "\(level)" : label
        case .badge(let badge):
            return badge
        case .prerequisite(let prerequisite):
            return prerequisite.rawValue
        }
    }

    /// Compte affiché par un déclencheur multi-sélection : « N choix ».
    static func choiceCount(_ count: Int) -> String { "\(count) choix" }

    /// `accessibilityLabel` du déclencheur :
    /// « Filtrer par <label> : <sélection> » (`label.toLocaleLowerCase('fr')`).
    static func filterAccessibilityLabel(label: String, selection: String) -> String {
        "Filtrer par \(label.lowercased()) : \(selection)"
    }

    /// `accessibilityLabel` du menu « Classique » : « Classique : <valeur> ».
    static func classicAccessibilityLabel(_ value: SubjClassicFilterValue) -> String {
        "Classique : \(value.rawValue)"
    }
}

// MARK: - Constantes de l'écran

/// Constantes partagées par les menus de l'écran « Matières »
/// (`SUBJECTS_DROPDOWN_SCOPE`, `DIFFICULTY_MENU_MIN_WIDTH`).
enum SubjSubjectsDropdownScope {
    /// Portée de coordination des voiles de menu (`coordinationScope`) : côté
    /// Expo, un seul voile ouvert à la fois dans cette portée.
    static let coordinationScope = "subjects-screen"

    /// Largeur minimale du menu « Difficulté », pour ses libellés longs
    /// (« Très difficile »). Les autres menus s'en passent.
    static let difficultyMenuMinWidth: CGFloat = 210
}

// MARK: - Formatage des erreurs

/// `errorDateFormatter`, `formatErrorDate` et `formatErrorRecurrence` du
/// panneau « Mes erreurs » (mes erreurs récurrentes d'un chapitre).
enum SubjErrorFormatting {
    /// `new Intl.DateTimeFormat('fr-FR', { day: 'numeric', month: 'short' })` :
    /// jour numérique et mois abrégé, p. ex. « 12 sept. ».
    static let errorDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "d MMM"
        return formatter
    }()

    /// `formatErrorDate` : date de la dernière fois où l'erreur a été commise.
    /// Le JSX reçoit `seenAt` en **millisecondes** (`number`) ; l'appelant
    /// convertit donc en `Date` (`Date(timeIntervalSince1970: ms / 1000)`).
    static func formatErrorDate(_ seenAt: Date) -> String {
        errorDateFormatter.string(from: seenAt)
    }

    /// `formatErrorRecurrence` : « N erreurs de ce type » (N > 1) ou
    /// « 1 erreur de ce type ».
    static func formatErrorRecurrence(_ count: Int) -> String {
        count > 1 ? "\(count) erreurs de ce type" : "1 erreur de ce type"
    }
}
