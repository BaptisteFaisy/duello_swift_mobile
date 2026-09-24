//
//  SubjFlashcardDropdowns.swift
//  Duello
//
//  Lot « Subj » (9-E) — menus de sélection des flashcards : paquets (avec
//  « tous les types », « sans type », « créer un type ») et chapitres.
//
//  Fichiers source Expo portés (libellés repris mot pour mot) :
//    - src/screens/SubjectsScreen.tsx (lignes 1585-1815)
//        `FlashcardDropdown` et `FlashcardChapterDropdown`.
//
//  Voile ancré (vague 3) : Expo ancre un voile flottant au déclencheur
//  (`DropdownOverlay` + `SUBJECTS_DROPDOWN_SCOPE`). Le menu n'est donc plus
//  déplié **dans le flux** : le déclencheur publie son cadre
//  (`.dropdownAnchor`) et le panneau (`SubjDropdownMenuList`, styles
//  `badgeFilterMenu` / `badgeFilterOption`) est confié à `DropdownOverlay`,
//  qui le pose sous le déclencheur, le rogne et le fait défiler — le RN
//  l'enveloppe dans un `ScrollView` (`scrollable: true`). Le menu des
//  chapitres **reste ouvert** après un choix pour en cocher plusieurs, comme
//  le JSX ; celui des types se referme (`setOpen(false)`).
//
//  Styles repris tels quels : `flashcardDropdownField`, `flashcardFieldLabel`,
//  `flashcardDropdownTrigger`, `badgeFilterMenu`, `badgeFilterOption` et
//  `flashcardDropdownMessage`.
//
//  Cible : iOS 16, aucune API iOS 17.
//
import SwiftUI

// MARK: - Identités des menus

/// Identités des déclencheurs dans le registre des menus ancrés
/// (`DropdownOverlay`) et portée de coordination commune aux menus de l'écran
/// « Matières » (`SUBJECTS_DROPDOWN_SCOPE` de `SubjectsScreen.tsx:1289`).
enum SubjFlashcardDropdownAnchor {
    /// `anchorRef` du menu « Type de flashcards » (`FlashcardDropdown`).
    static let type = "subj-flashcard-type"
    /// `anchorRef` du menu « Chapitres » (`FlashcardChapterDropdown`).
    static let chapters = "subj-flashcard-chapters"
    /// `coordinationScope` partagée (`subjects-screen`) : côté Expo, un seul
    /// voile ouvert à la fois dans cette portée.
    static let scope = SubjSubjectsDropdownScope.coordinationScope
}

// MARK: - Entrées de menu

/// Une entrée affichée par un menu : un paquet ou une clé sentinelle.
struct SubjFlashcardDropdownChoice: Identifiable, Hashable {
    let key: String
    let label: String

    var id: String { key }
}

/// Composition des entrées et du libellé du déclencheur, extraite du JSX.
enum SubjFlashcardDropdownModel {
    /// `choices` : « tous », puis « sans type », puis les paquets, puis
    /// « créer un type » — dans cet ordre exact.
    static func choices(
        options: [CollDeckDefinition],
        allowAll: Bool,
        allLabel: String,
        allowNone: Bool,
        allowCreate: Bool
    ) -> [SubjFlashcardDropdownChoice] {
        var choices: [SubjFlashcardDropdownChoice] = []
        if allowAll {
            choices.append(.init(key: SubjFlashcardSelectionKey.all, label: allLabel))
        }
        if allowNone {
            choices.append(
                .init(key: SubjFlashcardSelectionKey.none, label: SubjFlashcardSelectionCopy.noneType)
            )
        }
        choices.append(contentsOf: options.map { .init(key: $0.key, label: $0.label) })
        if allowCreate {
            choices.append(
                .init(key: SubjFlashcardSelectionKey.create, label: SubjFlashcardSelectionCopy.createType)
            )
        }
        return choices
    }

    /// `selectedLabel` du déclencheur : sentinelle nommée, sinon libellé du
    /// paquet, sinon la clé brute.
    static func selectedLabel(
        selected: String,
        options: [CollDeckDefinition],
        allLabel: String
    ) -> String {
        switch selected {
        case SubjFlashcardSelectionKey.all:
            return allLabel
        case SubjFlashcardSelectionKey.none:
            return SubjFlashcardSelectionCopy.noneType
        case SubjFlashcardSelectionKey.create:
            return SubjFlashcardSelectionCopy.createType
        default:
            return options.first { $0.key == selected }?.label ?? selected
        }
    }
}

// MARK: - Chrome commun

/// Étiquette + déclencheur (`flashcardDropdownField`, `flashcardFieldLabel`).
struct SubjDropdownFieldChrome<Trigger: View>: View {
    let label: String
    @ViewBuilder let trigger: () -> Trigger

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 11, weight: .black))
                .tracking(0.35)
                .textCase(.uppercase)
                .foregroundColor(Theme.inkSoft)
            trigger()
        }
    }
}

/// Déclencheur d'un menu (`flashcardDropdownTrigger`) : bord fin, valeur
/// tronquée à une ligne, chevron — ou roue d'attente pendant le chargement.
struct SubjDropdownTrigger: View {
    let value: String
    let isOpen: Bool
    let isLoading: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                Text(value)
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundColor(Theme.ink)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if isLoading {
                    ProgressView().progressViewStyle(.circular).tint(Theme.inkSoft)
                } else {
                    Image(systemName: isOpen ? "chevron.up" : "chevron.down")
                        .font(.system(size: 15))
                        .foregroundColor(Theme.inkSoft)
                }
            }
            .padding(.horizontal, 13)
            .frame(minHeight: 46)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusMedium)
                    .stroke(Theme.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(value)
        .accessibilityValue(isOpen ? "Déplié" : "Replié")
    }
}

// MARK: - Lignes du menu

/// Une ligne cochable (`badgeFilterOption`) : libellé, coche, fond teinté
/// quand la ligne est retenue.
struct SubjDropdownOptionRow: View {
    let label: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 3) {
                Text(label)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Theme.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Theme.primary)
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 7)
            .frame(minHeight: 44)
            .frame(maxWidth: .infinity)
            .background(isSelected ? Theme.primaryLight : Color.clear)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Theme.border).frame(height: 0.5)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isSelected ? AccessibilityTraits.isSelected : AccessibilityTraits())
    }
}

/// Panneau du menu (`badgeFilterMenu`) : les lignes, puis un éventuel message
/// (« Recherche des chapitres… » avec roue, ou « Aucun chapitre… »).
///
/// C'est le **contenu** confié à `DropdownOverlay` (fond, bord et
/// `marginTop: 6` du `badgeFilterMenu`) : le voile se charge du défilement et
/// du rognage, et son `MENU_GAP` (6) s'ajoute à ce `padding(.top, 6)` — l'écart
/// déclencheur→panneau réel vaut donc 12, comme le RN (`MENU_GAP` + `marginTop`).
struct SubjDropdownMenuList: View {
    let choices: [SubjFlashcardDropdownChoice]
    let selectedKeys: Set<String>
    let message: String?
    let showsSpinner: Bool
    let onTap: (String) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(choices) { choice in
                SubjDropdownOptionRow(
                    label: choice.label,
                    isSelected: selectedKeys.contains(choice.key)
                ) {
                    onTap(choice.key)
                }
            }
            if let message {
                HStack(spacing: 8) {
                    if showsSpinner {
                        ProgressView().progressViewStyle(.circular).tint(Theme.inkSoft)
                    }
                    Text(message)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Theme.inkSoft)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: 52)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
        }
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusMedium)
                .stroke(Theme.border, lineWidth: 1)
        )
        .padding(.top, 6)
    }
}

// MARK: - Menus

/// Menu d'un paquet de flashcards (`FlashcardDropdown`). Le choix referme le
/// menu, comme le JSX. Le voile est ancré au déclencheur (`DropdownOverlay`).
struct SubjFlashcardDropdown: View {
    let label: String
    let options: [CollDeckDefinition]
    let selected: String
    let onSelect: (String) -> Void
    var allowAll = false
    var allLabel = SubjFlashcardSelectionCopy.allTypes
    var allowNone = false
    var allowCreate = false

    @State private var isOpen = false
    /// Registre du déclencheur, partagé entre l'ancre et le voile.
    @StateObject private var registry = DropdownOverlayRegistry()

    var body: some View {
        let choices = SubjFlashcardDropdownModel.choices(
            options: options,
            allowAll: allowAll,
            allLabel: allLabel,
            allowNone: allowNone,
            allowCreate: allowCreate
        )
        let value = SubjFlashcardDropdownModel.selectedLabel(
            selected: selected,
            options: options,
            allLabel: allLabel
        )

        SubjDropdownFieldChrome(label: label) {
            SubjDropdownTrigger(value: value, isOpen: isOpen, isLoading: false) {
                isOpen.toggle()
            }
            .dropdownAnchor(
                SubjFlashcardDropdownAnchor.type,
                in: registry,
                scope: SubjFlashcardDropdownAnchor.scope,
                onRequestOpen: { isOpen = true }
            )
        }
        .overlay {
            DropdownOverlay(
                isPresented: $isOpen,
                anchorID: SubjFlashcardDropdownAnchor.type,
                registry: registry,
                coordinationScope: SubjFlashcardDropdownAnchor.scope,
                scrollable: true
            ) {
                SubjDropdownMenuList(
                    choices: choices,
                    selectedKeys: [selected],
                    message: nil,
                    showsSpinner: false
                ) { key in
                    onSelect(key)
                    isOpen = false
                }
            }
        }
    }
}

/// Menu des chapitres révisables (`FlashcardChapterDropdown`). Il **reste
/// ouvert** après un choix, pour en cocher plusieurs.
struct SubjFlashcardChapterDropdown: View {
    let options: [CollDeckDefinition]
    let selected: SubjFlashcardChapterSelection
    let loading: Bool
    let onSelect: (SubjFlashcardChapterSelection) -> Void

    @State private var isOpen = false
    /// Registre du déclencheur, partagé entre l'ancre et le voile.
    @StateObject private var registry = DropdownOverlayRegistry()

    var body: some View {
        let allKeys = options.map { $0.key }
        let isAll = selected.chapterIds == nil
        let checked = isAll
            ? Set(allKeys + [SubjFlashcardSelectionKey.all])
            : Set(selected.chapterIds ?? [])
        let value = loading
            ? SubjFlashcardSelectionCopy.loading
            : SubjFlashcardSelectionCopy.chapterLabel(selected, options: options)
        let message = loading
            ? SubjFlashcardSelectionCopy.searchingChapters
            : (options.isEmpty ? SubjFlashcardSelectionCopy.emptyChapters : nil)
        let choices: [SubjFlashcardDropdownChoice] = loading ? [] : [
            SubjFlashcardDropdownChoice(
                key: SubjFlashcardSelectionKey.all,
                label: SubjFlashcardSelectionCopy.allChapters
            ),
        ] + options.map { SubjFlashcardDropdownChoice(key: $0.key, label: $0.label) }

        SubjDropdownFieldChrome(label: SubjFlashcardSelectionCopy.chaptersLabel) {
            SubjDropdownTrigger(value: value, isOpen: isOpen, isLoading: loading) {
                isOpen.toggle()
            }
            .dropdownAnchor(
                SubjFlashcardDropdownAnchor.chapters,
                in: registry,
                scope: SubjFlashcardDropdownAnchor.scope,
                onRequestOpen: { isOpen = true }
            )
        }
        .overlay {
            DropdownOverlay(
                isPresented: $isOpen,
                anchorID: SubjFlashcardDropdownAnchor.chapters,
                registry: registry,
                coordinationScope: SubjFlashcardDropdownAnchor.scope,
                scrollable: true
            ) {
                SubjDropdownMenuList(
                    choices: choices,
                    selectedKeys: checked,
                    message: message,
                    showsSpinner: loading
                ) { key in
                    if key == SubjFlashcardSelectionKey.all {
                        onSelect(isAll ? .chapters([]) : .all)
                    } else {
                        onSelect(selected.toggling(key, allKeys: allKeys))
                    }
                }
            }
        }
    }
}
