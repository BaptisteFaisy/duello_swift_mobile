//
//  SubjFilterTags.swift
//  Duello
//
//  Lot « Subj » (9-D) — pastilles affichées par les filtres du catalogue.
//
//  Fichiers source Expo portés (libellés repris mot pour mot) :
//    - src/screens/SubjectsScreen.tsx (lignes 1174-1244) :
//        `PrerequisiteFilterValueTag`, `BadgeFilterValueTag`.
//        (`ExerciseBadgeTag`, ligne 1257, est **déjà porté** par le lot 9-H sous
//        `SubjExerciseBadgeTag` — `SubjItemTags.swift` — et n'est jamais
//        redéclaré : on le réutilise.)
//
//  Réutilise sans les redéfinir :
//    - `Theme` (couleurs `prerequisitesReady`, `prerequisitesMissing` et leurs
//        fonds clairs, ajoutés par `ThemePalette.swift`) ;
//    - `SubjExerciseBadgeTag(badge:compact:)` (9-H) pour la branche « badge » ;
//    - `SubjDifficultyPill(level:compact:)` (`SubjDifficultyViews.swift`) pour la
//        branche « palier de difficulté » — le mode `compact` est celui du
//        drapeau du JSX (`compact={inChapterHeader}` au déclencheur, `false`
//        dans les lignes du menu) ;
//    - `TrainDifficulty` (via `SubjFilterValues`), jamais recopié.
//
//  Les Ionicons d'origine sont transposés en SF Symbols (mêmes intentions) :
//  `checkmark-circle-outline` → `checkmark.circle`, `time-outline` → `clock`,
//  `alert-circle-outline` → `exclamationmark.circle`.
//
//  Cible : iOS 16, aucune API iOS 17.
//
import SwiftUI

// MARK: - Étiquette de prérequis

/// `PrerequisiteFilterValueTag` : état de prérequis d'un filtre, avec les
/// couleurs de la carte (« Prêt » en vert, « En partie » au gris neutre,
/// « Plus tard » en rouge).
///
/// La source applique **toujours** `badgeFilterValuePill` (mode compact) : la
/// pastille n'a donc pas de variante standard. Couleurs : `prerequisitesReady`
/// pour l'acquis, `inkSoft` pour l'entamé, `prerequisitesMissing` pour le
/// manquant.
struct SubjPrerequisiteFilterValueTag: View {
    let value: SubjPrerequisiteFilterValue

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: SubjPrerequisiteFilterValueTag.icon(for: value))
                .font(.system(size: 10))
                .foregroundColor(SubjPrerequisiteFilterValueTag.foreground(for: value))
            Text(value.rawValue)
                .font(.system(size: 9, weight: .heavy))
                .foregroundColor(SubjPrerequisiteFilterValueTag.foreground(for: value))
                .lineLimit(1)
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 4)
        .background(SubjPrerequisiteFilterValueTag.background(for: value))
        .clipShape(Capsule())
        .accessibilityElement(children: .combine)
    }

    private static func icon(for value: SubjPrerequisiteFilterValue) -> String {
        switch value {
        case .ready: return "checkmark.circle"
        case .partly: return "clock"
        case .later: return "exclamationmark.circle"
        }
    }

    private static func foreground(for value: SubjPrerequisiteFilterValue) -> Color {
        switch value {
        case .ready: return Theme.prerequisitesReady
        case .partly: return Theme.inkSoft
        case .later: return Theme.prerequisitesMissing
        }
    }

    private static func background(for value: SubjPrerequisiteFilterValue) -> Color {
        switch value {
        case .ready: return Theme.prerequisitesReadyLight
        case .partly: return Theme.surfaceMuted
        case .later: return Theme.prerequisitesMissingLight
        }
    }
}

// MARK: - Aiguillage

/// `BadgeFilterValueTag` : apparence commune d'une valeur proposée par un filtre.
///
/// Le JSX distingue les trois natures par `typeof` / `isPrerequisiteFilterValue` ;
/// ici le cas de l'énumération le fait directement.
///
/// `compact` reprend le drapeau du JSX : le **déclencheur** d'un menu l'active en
/// en-tête de chapitre (`compact={inChapterHeader}`) et le laisse à `false` dans
/// la rangée de filtres d'annales, alors que les **lignes du menu** rendent
/// toujours la valeur non compacte (`<BadgeFilterValueTag value={badge} />`).
struct SubjBadgeFilterValueTag: View {
    let value: SubjExerciseFilterValue
    var compact: Bool = false

    var body: some View {
        switch value {
        case .difficulty(let level):
            SubjDifficultyPill(level: level, compact: compact)
        case .prerequisite(let prerequisite):
            // `PrerequisiteFilterValueTag` applique `badgeFilterValuePill` sans
            // condition : cette branche est toujours compacte.
            SubjPrerequisiteFilterValueTag(value: prerequisite)
        case .badge(let badge):
            SubjExerciseBadgeTag(badge: badge, compact: compact)
        }
    }
}
