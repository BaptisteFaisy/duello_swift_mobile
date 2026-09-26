//
//  SubjFilterDropdowns.swift
//  Duello
//
//  Lot « Subj » (9-D) — menus de filtre du catalogue : badges (multi-choix),
//  « Notions » (emplacement réservé) et « Classique » (choix unique).
//
//  Fichiers source Expo portés (libellés repris mot pour mot) :
//    - src/screens/SubjectsScreen.tsx (lignes 1290-1539) :
//        `BadgeFilterDropdown`, `NotionsDropdown`, `ClassiqueDropdown`.
//
//  Choix de transposition (voir aussi l'en-tête de
//  `SubjFilterDropdownChrome.swift`) : Expo ancre un voile flottant
//  (`DropdownOverlay`) au déclencheur. On le rend ici comme un **panneau déplié
//  dans le flux**, et non comme un `Menu` natif SwiftUI :
//    - le menu des badges reste ouvert après un choix (le JSX n'appelle pas
//      `setOpen(false)` dans `onSelect` : la sélection est cumulative) ;
//    - le menu « Classique » se referme après un choix (`setOpen(false)`), ce
//      qu'un `Menu` natif ferait aussi — on garde néanmoins le même panneau
//      pour l'homogénéité visuelle ;
//    - les lignes portent des pastilles (`SubjBadgeFilterValueTag`) que le
//      `Menu` natif ne sait pas composer.
//
//  Réutilise sans les redéfinir : `Theme`, `SubjBadgeFilterValueTag`,
//  `SubjFilterFieldChrome`, `SubjFilterTrigger`, `SubjFilterAllBadge`,
//  `SubjFilterOptionRow`, `SubjFilterMenuPanel` (fichiers 9-D) ;
//  `SubjDifficultyPill` (9-C) ; `SubjFilterCopy`, `SubjClassicOptions`,
//  `SubjSubjectsDropdownScope` (SubjFilterValues.swift).
//
//  Cible : iOS 16, aucune API iOS 17.
//
import SwiftUI

// MARK: - Composition du menu des badges

/// Algèbre du menu des badges, extraite du JSX (`choices`, libellé du
/// déclencheur, test de sélection).
enum SubjBadgeFilterModel {
    /// `choices` : l'entrée « Tout » (`null`), puis les options, dans l'ordre.
    static func choices(options: [SubjExerciseFilterValue]) -> [SubjFilterChoice] {
        [SubjFilterChoice(value: nil)] + options.map { SubjFilterChoice(value: $0) }
    }

    /// `selected.includes(badge)`, l'entrée « Tout » valant « aucune sélection ».
    static func isSelected(
        _ value: SubjExerciseFilterValue?,
        selected: [SubjExerciseFilterValue]
    ) -> Bool {
        guard let value = value else { return selected.isEmpty }
        return selected.contains(value)
    }

    /// Libellé du déclencheur : « Tout », la valeur unique, ou « N choix ».
    static func selectionLabel(selected: [SubjExerciseFilterValue]) -> String {
        if selected.isEmpty { return SubjFilterCopy.tout }
        if selected.count == 1 { return SubjFilterCopy.label(for: selected[0]) }
        return SubjFilterCopy.choiceCount(selected.count)
    }
}

// MARK: - Menu des badges

/// `BadgeFilterDropdown` : filtre multi-choix d'une famille de badges
/// (type, domaine, difficulté, prérequis…).
///
/// `inChapterHeader` reprend l'usage en en-tête de chapitre (déclencheur plus
/// court, cf. `chapterHeaderFilterTrigger`).
struct SubjBadgeFilterDropdown: View {
    let label: String
    let options: [SubjExerciseFilterValue]
    let selected: [SubjExerciseFilterValue]
    let onSelect: (SubjExerciseFilterValue?) -> Void
    var inChapterHeader: Bool = false

    @State private var isOpen = false

    var body: some View {
        let selection = SubjBadgeFilterModel.selectionLabel(selected: selected)
        SubjFilterFieldChrome(label: label) {
            VStack(alignment: .leading, spacing: 0) {
                SubjFilterTrigger(
                    isOpen: isOpen,
                    inChapterHeader: inChapterHeader,
                    accessibilityLabel: SubjFilterCopy.filterAccessibilityLabel(
                        label: label,
                        selection: selection
                    ),
                    onTap: { isOpen.toggle() },
                    content: { triggerContent }
                )
                if isOpen { menu }
            }
        }
    }

    /// Contenu du déclencheur : la valeur unique, « N choix », ou « Tout ».
    @ViewBuilder private var triggerContent: some View {
        if selected.count == 1 {
            SubjBadgeFilterValueTag(value: selected[0])
        } else if selected.count > 1 {
            SubjFilterAllBadge(
                icon: "checkmark.circle",
                iconColor: Theme.primary,
                text: SubjFilterCopy.choiceCount(selected.count)
            )
        } else {
            SubjFilterAllBadge(icon: "square.grid.2x2", text: SubjFilterCopy.tout)
        }
    }

    /// Le menu : « Tout » puis chaque option, sans refermer le menu au choix.
    private var menu: some View {
        let choices = SubjBadgeFilterModel.choices(options: options)
        let minWidth = label == SubjFilterCopy.difficulty
            ? SubjSubjectsDropdownScope.difficultyMenuMinWidth
            : nil
        return SubjFilterMenuPanel(minWidth: minWidth) {
            VStack(spacing: 0) {
                ForEach(choices) { choice in
                    SubjFilterOptionRow(
                        isSelected: SubjBadgeFilterModel.isSelected(
                            choice.value,
                            selected: selected
                        ),
                        accessibilityLabel: SubjFilterCopy.label(for: choice.value),
                        onTap: { onSelect(choice.value) }
                    ) {
                        if let value = choice.value {
                            SubjBadgeFilterValueTag(value: value)
                        } else {
                            SubjFilterAllBadge(
                                icon: "square.grid.2x2",
                                text: SubjFilterCopy.tout
                            )
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Menu « Notions »

/// `NotionsDropdown` : emplacement réservé au futur filtre de notions des
/// exercices. Le menu s'ouvre sur un bloc vide (`emptyNotionsMenu`), et le
/// déclencheur n'annonce aucune option.
struct SubjNotionsDropdown: View {
    var inChapterHeader: Bool = false

    @State private var isOpen = false

    var body: some View {
        SubjFilterFieldChrome(label: SubjFilterCopy.notions) {
            VStack(alignment: .leading, spacing: 0) {
                SubjFilterTrigger(
                    isOpen: isOpen,
                    inChapterHeader: inChapterHeader,
                    accessibilityLabel: SubjFilterCopy.notionsAccessibilityLabel,
                    onTap: { isOpen.toggle() },
                    content: { SubjFilterAllBadge(text: SubjFilterCopy.tout) }
                )
                if isOpen {
                    // `emptyNotionsMenu` : un bloc vide, haut de 44 pt.
                    SubjFilterMenuPanel {
                        Color.clear
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 44)
                    }
                }
            }
        }
    }
}

// MARK: - Menu « Classique »

/// `ClassiqueDropdown` : filtre à choix unique entre « Tout » et « Classiques ».
/// Le choix referme le menu, comme le JSX.
struct SubjClassiqueDropdown: View {
    let selected: SubjClassicFilterValue
    let onSelect: (SubjClassicFilterValue) -> Void
    var inChapterHeader: Bool = false

    @State private var isOpen = false

    var body: some View {
        SubjFilterFieldChrome(label: SubjFilterCopy.classique) {
            VStack(alignment: .leading, spacing: 0) {
                SubjFilterTrigger(
                    isOpen: isOpen,
                    inChapterHeader: inChapterHeader,
                    accessibilityLabel: SubjFilterCopy.classicAccessibilityLabel(selected),
                    onTap: { isOpen.toggle() },
                    content: { SubjFilterAllBadge(text: selected.rawValue) }
                )
                if isOpen { menu }
            }
        }
    }

    /// Les deux options ; un choix referme le menu (`setOpen(false)`).
    private var menu: some View {
        SubjFilterMenuPanel {
            VStack(spacing: 0) {
                ForEach(SubjClassicOptions.all, id: \.rawValue) { option in
                    SubjFilterOptionRow(
                        isSelected: option == selected,
                        accessibilityLabel: option.rawValue,
                        onTap: {
                            onSelect(option)
                            isOpen = false
                        }
                    ) {
                        SubjFilterAllBadge(
                            icon: option == .all ? "square.grid.2x2" : "graduationcap",
                            text: option.rawValue
                        )
                    }
                }
            }
        }
    }
}
