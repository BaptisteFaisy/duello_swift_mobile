//
//  SubjFilterDropdownChrome.swift
//  Duello
//
//  Lot « Subj » (9-D) — chrome commun des menus de filtre du catalogue :
//  étiquette, déclencheur, ligne d'option, pastille « Tout / N choix ».
//
//  Fichiers source Expo portés (styles repris à l'identique) :
//    - src/screens/SubjectsScreen.tsx : `badgeFilter`, `badgeFilterLabel`,
//        `badgeFilterTrigger`, `chapterHeaderFilter`, `chapterHeaderFilterTrigger`,
//        `badgeFilterPressed`, `badgeFilterAll`, `badgeFilterAllText`,
//        `badgeFilterMenu`, `badgeFilterOption`, `badgeFilterOptionSelected`,
//        `emptyNotionsMenu` (lignes 12242-12330).
//
//  Choix de transposition (documenté) : Expo ancre un **voile flottant** au
//  déclencheur (`DropdownOverlay` + `SUBJECTS_DROPDOWN_SCOPE`). Deux options
//  SwiftUI s'offraient : le `Menu` natif, ou un panneau déplié **dans le flux**.
//  On retient le panneau dans le flux, comme le lot 9-E
//  (`SubjFlashcardDropdowns.swift`) :
//    - le menu des badges reste **ouvert** après un choix (multi-sélection,
//      `onSelect` sans fermeture dans le JSX) — un `Menu` natif se referme à
//      chaque coche ;
//    - les lignes affichent des **pastilles** (`SubjBadgeFilterValueTag`), que
//      le `Menu` natif ne permet pas d'insérer telles quelles ;
//    - l'apparence (bord fin, chevron, fonds teintés) reste celle du JSX.
//  `SUBJECTS_DROPDOWN_SCOPE` (un seul voile ouvert à la fois) n'a plus d'objet :
//  chaque menu gère son propre `isOpen`.
//
//  Cible : iOS 16, aucune API iOS 17.
//
import SwiftUI

// MARK: - Entrée de menu

/// Une ligne de menu : une valeur de filtre, ou `nil` pour l'entrée « Tout ».
struct SubjFilterChoice: Identifiable {
    let value: SubjExerciseFilterValue?

    /// Clé de liste : `id` de la valeur, ou `all` pour l'entrée « Tout ».
    var id: String { value?.id ?? "all" }
}

// MARK: - Chrome

/// Étiquette + contenu (`badgeFilter`, `badgeFilterLabel`).
///
/// Le libellé est en 9 pt, en gras, en capitales, avec un léger interlettrage —
/// c'est ce que demandait `badgeFilterLabel` (le champ des flashcards, lui, use
/// 11 pt : on ne réutilise donc pas `SubjDropdownFieldChrome`).
struct SubjFilterFieldChrome<Content: View>: View {
    let label: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 9, weight: .heavy))
                .tracking(0.2)
                .textCase(.uppercase)
                .foregroundColor(Theme.inkSoft)
                .frame(maxWidth: .infinity, alignment: .leading)
            content()
        }
    }
}

/// Déclencheur d'un menu (`badgeFilterTrigger`) : bord fin, contenu à gauche,
/// chevron à droite. La hauteur passe de 42 à 36 en en-tête de chapitre
/// (`chapterHeaderFilterTrigger`).
struct SubjFilterTrigger<Content: View>: View {
    let isOpen: Bool
    let inChapterHeader: Bool
    let accessibilityLabel: String
    let onTap: () -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 3) {
                content()
                Spacer(minLength: 0)
                Image(systemName: isOpen ? "chevron.up" : "chevron.down")
                    .font(.system(size: 14))
                    .foregroundColor(Theme.inkSoft)
            }
            .padding(.horizontal, inChapterHeader ? 4 : 6)
            .frame(maxWidth: .infinity)
            .frame(minHeight: inChapterHeader ? 36 : 42)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusMedium)
                    .stroke(Theme.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(isOpen ? "Déplié" : "Replié")
    }
}

// MARK: - Pastille « Tout / N choix »

/// Pastille neutre des déclencheurs et de l'entrée « Tout »
/// (`badgeFilterAll`, `badgeFilterAllText`). L'icône est facultative : le
/// déclencheur « Notions » n'en porte pas.
struct SubjFilterAllBadge: View {
    var icon: String? = nil
    var iconColor: Color = Theme.inkFaint
    let text: String

    var body: some View {
        HStack(spacing: 5) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundColor(iconColor)
            }
            Text(text)
                .font(.system(size: 10, weight: .heavy))
                .foregroundColor(Theme.mutedSurfaceText)
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Theme.surfaceMuted)
        .clipShape(Capsule())
    }
}

// MARK: - Ligne d'option

/// Une ligne cochable (`badgeFilterOption`) : un contenu libre à gauche (une
/// pastille), une coche à droite, un fond teinté quand la ligne est retenue.
struct SubjFilterOptionRow<Leading: View>: View {
    let isSelected: Bool
    let accessibilityLabel: String
    let onTap: () -> Void
    @ViewBuilder let leading: () -> Leading

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 3) {
                leading()
                Spacer(minLength: 0)
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Theme.primary)
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 44)
            .background(isSelected ? Theme.primaryLight : Color.clear)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Theme.border).frame(height: 0.5)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(isSelected ? .isSelected : AccessibilityTraits())
    }
}

// MARK: - Panneau de menu

/// Panneau déplié (`badgeFilterMenu`) : lignes, fond blanc, bord fin, décalé
/// sous le déclencheur. `minWidth` élargit le menu « Difficulté ».
struct SubjFilterMenuPanel<Content: View>: View {
    var minWidth: CGFloat? = nil
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .frame(minWidth: minWidth, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusMedium)
                    .stroke(Theme.border, lineWidth: 1)
            )
            .padding(.top, 6)
    }
}
