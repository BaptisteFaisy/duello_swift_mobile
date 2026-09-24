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
//  Vague 3 : les trois menus sont désormais rendus par le composant partagé
//  `DropdownOverlay` (`DropdownOverlayView.swift`) — voile flottant ancré au
//  déclencheur, à la place du panneau déplié **dans le flux** de la vague 1.
//  C'est la `Modal` transparente du RN : le menu recouvre le contenu au lieu de
//  le pousser. Le menu des badges reste ouvert après un choix (le JSX n'appelle
//  pas `setOpen(false)` dans `onSelect` : la sélection est cumulative) ; celui
//  de « Classique » se referme (`setOpen(false)`), comme le JSX.
//
//  Le **contenu** passé au voile est le panneau seul (`SubjFilterMenuPanel`) :
//  le composant se charge du défilement, du rognage, de l'ancrage et de la
//  coordination des menus de la portée `subjects-screen` (un seul voile ouvert
//  à la fois). `SubjFilterMenuPanel` garde son `marginTop` de 6 pt
//  (`badgeFilterMenu` / `emptyNotionsMenu`) : il s'ajoute aux 6 pt du voile, soit
//  l'écart réel de 12 pt du RN — le composant n'ajoute que 6 (pas de double).
//
//  Réutilise sans les redéfinir : `Theme`, `SubjBadgeFilterValueTag`,
//  `SubjFilterFieldChrome`, `SubjFilterTrigger`, `SubjFilterAllBadge`,
//  `SubjFilterOptionRow`, `SubjFilterMenuPanel` (fichiers 9-D) ;
//  `SubjDifficultyPill` (9-C) ; `SubjFilterCopy`, `SubjClassicOptions`,
//  `SubjSubjectsDropdownScope` (SubjFilterValues.swift) ;
//  `DropdownOverlay`, `DropdownOverlayRegistry`, `.dropdownAnchor`
//  (DropdownOverlayView.swift, KIT partagé).
//
//  Cible : iOS 16, aucune API iOS 17.
//
import SwiftUI
import UIKit

// MARK: - Coordination des menus (portée « subjects-screen »)

/// Registre partagé des déclencheurs de menu du catalogue. Côté Expo, la `Map`
/// `registeredDropdowns` de `DropdownOverlay.tsx` est **module-globale** : les
/// menus d'une même portée (`SubjSubjectsDropdownScope.coordinationScope`) s'y
/// coordonnent (un seul voile ouvert à la fois ; l'appui sur le déclencheur d'un
/// menu frère lui transmet l'ouverture). On reprend cette globalité ici, faute
/// de pouvoir hisser le registre jusqu'à la racine de l'écran.
enum SubjFilterDropdownRegistry {
    static let shared = DropdownOverlayRegistry()
}

// MARK: - Montage du voile

/// Monte le voile `DropdownOverlay` d'un menu de filtre **au niveau de la
/// fenêtre**, depuis la cellule du filtre.
///
/// `DropdownOverlay` se pose sur la vue racine : son `GeometryReader` prend la
/// fenêtre pour région de référence et son voile plein écran la recouvre. Ici
/// l'état `isOpen` vit dans la cellule (chaque menu est autonome, comme le
/// `useState` du RN), donc le voile est monté depuis la cellule : on lui donne
/// le cadre de la fenêtre et on annule l'origine globale de la cellule pour que
/// son repère soit celui de la fenêtre — le même que la `Modal` du RN.
private struct SubjFilterOverlayPresenter<Menu: View>: ViewModifier {
    @Binding var isPresented: Bool
    let anchorID: String
    let minWidth: CGFloat
    let scrollable: Bool
    @ViewBuilder let menu: () -> Menu

    /// Origine globale de la cellule hôte, annulée au placement du voile.
    @State private var hostOrigin: CGPoint = .zero

    func body(content: Content) -> some View {
        content
            .background {
                GeometryReader { proxy in
                    Color.clear
                        .onAppear { hostOrigin = proxy.frame(in: .global).origin }
                        .onChange(of: proxy.frame(in: .global)) { frame in
                            hostOrigin = frame.origin
                        }
                }
            }
            .overlay(alignment: .topLeading) {
                if isPresented {
                    DropdownOverlay(
                        isPresented: $isPresented,
                        anchorID: anchorID,
                        registry: SubjFilterDropdownRegistry.shared,
                        coordinationScope: SubjSubjectsDropdownScope.coordinationScope,
                        minWidth: minWidth,
                        scrollable: scrollable,
                        menu: menu
                    )
                    .frame(width: windowSize.width, height: windowSize.height)
                    .offset(x: -hostOrigin.x, y: -hostOrigin.y)
                }
            }
    }

    /// Cadre de la fenêtre (région de référence du composant).
    private var windowSize: CGSize {
        #if os(iOS)
        UIScreen.main.bounds.size
        #else
        // Hors iOS (contrôle de types Linux) : sans objet.
        CGSize(width: 0, height: 0)
        #endif
    }
}

private extension View {
    /// Monte le voile d'un menu de filtre du catalogue (cf.
    /// `SubjFilterOverlayPresenter`).
    func subjFilterOverlay<Menu: View>(
        isPresented: Binding<Bool>,
        anchorID: String,
        minWidth: CGFloat = 0,
        scrollable: Bool,
        @ViewBuilder menu: @escaping () -> Menu
    ) -> some View {
        modifier(
            SubjFilterOverlayPresenter(
                isPresented: isPresented,
                anchorID: anchorID,
                minWidth: minWidth,
                scrollable: scrollable,
                menu: menu
            )
        )
    }
}

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
    /// `anchorRef` du RN : identité du déclencheur dans le registre partagé.
    @State private var anchorID = UUID().uuidString

    var body: some View {
        let selection = SubjBadgeFilterModel.selectionLabel(selected: selected)
        SubjFilterFieldChrome(
            label: label,
            minWidth: inChapterHeader ? nil : SubjSubjectsDropdownScope.badgeFilterMinWidth
        ) {
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
            .dropdownAnchor(
                anchorID,
                in: SubjFilterDropdownRegistry.shared,
                scope: SubjSubjectsDropdownScope.coordinationScope,
                onRequestOpen: { isOpen = true }
            )
        }
        // `minWidth: 210` du voile pour « Difficulté » (libellés longs) : porté
        // par le composant, pas par le panneau (pas de contrainte en double).
        .subjFilterOverlay(
            isPresented: $isOpen,
            anchorID: anchorID,
            minWidth: label == SubjFilterCopy.difficulty
                ? SubjSubjectsDropdownScope.difficultyMenuMinWidth
                : 0,
            scrollable: true
        ) { menu }
    }

    /// Contenu du déclencheur : la valeur unique, « N choix », ou « Tout ».
    ///
    /// Le JSX passe `compact={inChapterHeader}` : la pastille n'est resserrée
    /// que dans l'en-tête de chapitre.
    @ViewBuilder private var triggerContent: some View {
        if selected.count == 1 {
            SubjBadgeFilterValueTag(value: selected[0], compact: inChapterHeader)
        } else if selected.count > 1 {
            // Ionicons `checkmark-done-outline` : la double coche n'a pas
            // d'équivalent exact dans SF Symbols (voir le rapport).
            SubjFilterAllBadge(
                icon: "checkmark.circle",
                iconColor: Theme.primary,
                text: SubjFilterCopy.choiceCount(selected.count)
            )
        } else {
            // Ionicons `apps-outline` (grille 2×2 de carrés) → `square.grid.2x2`.
            SubjFilterAllBadge(icon: "square.grid.2x2", text: SubjFilterCopy.tout)
        }
    }

    /// Le menu : « Tout » puis chaque option, sans refermer le menu au choix.
    private var menu: some View {
        let choices = SubjBadgeFilterModel.choices(options: options)
        return SubjFilterMenuPanel {
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
                            // Le JSX rend `<BadgeFilterValueTag value={badge} />`
                            // sans `compact` : la valeur du menu est standard.
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
    @State private var anchorID = UUID().uuidString

    var body: some View {
        SubjFilterFieldChrome(
            label: SubjFilterCopy.notions,
            minWidth: inChapterHeader ? nil : SubjSubjectsDropdownScope.badgeFilterMinWidth
        ) {
            SubjFilterTrigger(
                isOpen: isOpen,
                inChapterHeader: inChapterHeader,
                accessibilityLabel: SubjFilterCopy.notionsAccessibilityLabel,
                onTap: { isOpen.toggle() },
                content: { SubjFilterAllBadge(text: SubjFilterCopy.tout) }
            )
            .dropdownAnchor(
                anchorID,
                in: SubjFilterDropdownRegistry.shared,
                scope: SubjSubjectsDropdownScope.coordinationScope,
                onRequestOpen: { isOpen = true }
            )
        }
        // `emptyNotionsMenu` : un `View` simple (pas de `ScrollView`), donc
        // `scrollable: false` — panneau rogné, sans défilement.
        .subjFilterOverlay(isPresented: $isOpen, anchorID: anchorID, scrollable: false) {
            // Un bloc vide, haut de 44 pt.
            SubjFilterMenuPanel {
                Color.clear
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 44)
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
    @State private var anchorID = UUID().uuidString

    var body: some View {
        SubjFilterFieldChrome(
            label: SubjFilterCopy.classique,
            minWidth: inChapterHeader ? nil : SubjSubjectsDropdownScope.badgeFilterMinWidth
        ) {
            SubjFilterTrigger(
                isOpen: isOpen,
                inChapterHeader: inChapterHeader,
                accessibilityLabel: SubjFilterCopy.classicAccessibilityLabel(selected),
                onTap: { isOpen.toggle() },
                content: { SubjFilterAllBadge(text: selected.rawValue) }
            )
            .dropdownAnchor(
                anchorID,
                in: SubjFilterDropdownRegistry.shared,
                scope: SubjSubjectsDropdownScope.coordinationScope,
                onRequestOpen: { isOpen = true }
            )
        }
        .subjFilterOverlay(
            isPresented: $isOpen,
            anchorID: anchorID,
            scrollable: true
        ) { menu }
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
