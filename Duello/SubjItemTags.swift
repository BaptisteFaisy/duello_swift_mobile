//
//  SubjItemTags.swift
//  Duello
//
//  Lot 9-H « lignes de chapitre, étiquettes et barre de progression »
//  (préfixe `Subj`).
//
//  Fichiers source Expo portés :
//    - src/screens/SubjectsScreen.tsx
//        · lignes 2997-3027 : `ItemThemeTag`, `ProgramStatusTag`
//        · lignes 1257-1285 : `ExerciseBadgeTag`
//        · lignes 3239-3278 : pastille de prérequis (`prerequisitesButton*`)
//        · styles `itemTag`, `itemTagText`, `badgeFilterValuePill`,
//          `badgeFilterValueText`
//
//  `isDownloadedDesktopApp()` (`src/utils/downloadedDesktopApp.ts`) renvoie
//  toujours `false` sur mobile : la branche « application de bureau » de
//  `ItemThemeTag` (étiquette masquée) ne rend jamais rien et n'est pas portée.
//  Cible iOS 16, aucune API iOS 17.
//
import SwiftUI

/// Thème d'une annale (`ItemThemeTag`) : le seul repère de tri qui ne tient pas
/// dans les badges.
struct SubjItemThemeTag: View {
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "tag")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.inkFaint)
            Text(label)
                .font(.system(size: 10, weight: .heavy))
                .foregroundStyle(Theme.inkSoft)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Theme.surfaceMuted)
        .clipShape(Capsule())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Thème : \(label)")
    }
}

/// Signalement explicite des sujets conservés au-delà du programme courant
/// (`ProgramStatusTag`).
///
/// Ne rend rien pour `auProgramme` : la source teste la valeur avant de monter
/// l'étiquette, la garde est ici dans la vue.
struct SubjProgramStatusTag: View {
    let status: SubjProgramStatus

    @ViewBuilder
    var body: some View {
        if status.isVisible {
            HStack(spacing: 4) {
                Image(systemName: status.systemImage)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.inkFaint)
                Text(status.label)
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundStyle(Theme.inkSoft)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Theme.surfaceMuted)
            .clipShape(Capsule())
            .accessibilityElement(children: .combine)
            .accessibilityLabel(status.label)
        }
    }
}

/// Pastille de type ou de badge d'un sujet (`ExerciseBadgeTag`).
///
/// Les annales enrichissent certains types avec l'année de session avant
/// affichage : la pastille accepte donc le libellé final, pas seulement les
/// valeurs brutes du catalogue.
struct SubjExerciseBadgeTag: View {
    let badge: String
    var compact: Bool = false

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: badge == "Calcul" ? "calculator" : "graduationcap")
                .font(.system(size: compact ? 10 : 12, weight: .semibold))
                .foregroundStyle(Theme.inkFaint)
            Text(badge)
                .font(.system(size: compact ? 10 : 11, weight: .heavy))
                .foregroundStyle(Theme.inkSoft)
                .lineLimit(compact ? 1 : nil)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Theme.surfaceMuted)
        .clipShape(Capsule())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(badge)
    }
}

/// Pastille des prérequis d'un sujet (`prerequisitesButton`).
///
/// Deux formes, exactement comme la source : une pastille **statique** quand les
/// prérequis sont prêts et la relecture terminée, une pastille **dépliable**
/// (chevron) sinon — c'est elle qui ouvre le panneau de détail.
struct SubjPrerequisiteBadge: View {
    let status: SubjPrerequisiteStatus
    /// Libellé d'accessibilité (`prerequisiteAccessibilityLabel`).
    let accessibilityText: String
    /// Vrai pour la pastille non cliquable (`isReady && !isReviewPending`).
    var isStatic: Bool = false
    var isExpanded: Bool = false
    var onToggle: () -> Void = {}

    var body: some View {
        Group {
            if isStatic {
                content(showsChevron: false)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(accessibilityText)
            } else {
                Button(action: onToggle) { content(showsChevron: true) }
                    .buttonStyle(.plain)
                    .accessibilityLabel(accessibilityText)
                    .accessibilityValue(isExpanded ? "Détail ouvert" : "Détail fermé")
            }
        }
    }

    /// Corps de la pastille : symbole du statut, chevron optionnel, fond teinté.
    private func content(showsChevron: Bool) -> some View {
        HStack(spacing: 5) {
            Image(systemName: status.systemImage)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(status.tint)
            if showsChevron {
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(status.tint)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(status.background)
        .clipShape(Capsule())
        .contentShape(Capsule())
    }
}
