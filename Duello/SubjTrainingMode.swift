// [SubjTrainingMode] Modes d'entraînement, catalogue d'onglets et barre de sélection.
// Porté de `src/screens/SubjectsScreen.tsx` (lignes 397-421, 570-663) et
// `src/utils/installedDesktopNavigation.ts` (`InstalledDesktopTrainingSection`).

import SwiftUI

/// Façons de travailler une matière, proposées au clic sur la matière
/// (`TrainingMode` de `SubjectsScreen.tsx`).
enum SubjTrainingMode: String, CaseIterable, Identifiable {
    case cours
    case exercices
    case colles
    case annales
    case dissertations

    var id: String { rawValue }

    /// Libellé de l'onglet (`TRAINING_MODES[].label`).
    var label: String {
        switch self {
        case .cours: return "Cours"
        case .exercices: return "Exercices"
        case .colles: return "Colles"
        case .annales: return "Annales"
        case .dissertations: return "Dissertations"
        }
    }

    /// Icône de l'onglet : les Ionicons d'origine sont transposés en SF Symbols
    /// (`TRAINING_MODES[].icon`).
    var systemImage: String {
        switch self {
        case .cours: return "book"
        case .exercices: return "dumbbell"
        case .colles: return "bubble.left.and.bubble.right"
        case .annales: return "books.vertical"
        case .dissertations: return "square.and.pencil"
        }
    }

    /// Mode de travail d'un chapitre, quand il en existe un : « Cours » et
    /// « Annales » n'ouvrent pas un mode de chapitre
    /// (`ChapterTrainingMode = Exclude<TrainingMode, 'cours' | 'annales'>`).
    var chapterMode: SubjChapterTrainingMode? {
        SubjChapterTrainingMode(rawValue: rawValue)
    }
}

/// Modes de travail d'un chapitre, hors « Cours » et « Annales »
/// (`ChapterTrainingMode`).
enum SubjChapterTrainingMode: String, CaseIterable, Identifiable {
    case exercices
    case colles
    case dissertations

    var id: String { rawValue }

    /// Nature du sujet, qui décide de l'accord des libellés (`getItemLabel`,
    /// `availabilityLabel`, `successLabel`).
    var kind: TrainExerciseKind {
        switch self {
        case .exercices: return .exercise
        case .colles: return .colle
        case .dissertations: return .dissertation
        }
    }

    /// `getModeLabel` : « Exercices », « Colles », « Dissertations », avec la
    /// variante en minuscules des libellés en ligne.
    func label(lowercase: Bool = false) -> String {
        let value: String
        switch self {
        case .exercices: value = "Exercices"
        case .colles: value = "Colles"
        case .dissertations: value = "Dissertations"
        }
        return lowercase ? value.lowercased() : value
    }
}

/// Une option d'onglet appariée à son mode (`TrainingModeOption`).
struct SubjTrainingModeOption: Identifiable, Hashable {
    let mode: SubjTrainingMode

    var id: String { mode.rawValue }
    var label: String { mode.label }
    var systemImage: String { mode.systemImage }
}

/// `TRAINING_MODES` : toutes les options, dans l'ordre de l'app Expo, et le
/// filtre qui décide des onglets réellement proposés (`availableTrainingModesFor`).
enum SubjTrainingModeCatalog {
    /// Les cinq modes, dans l'ordre affiché.
    static let all: [SubjTrainingModeOption] =
        SubjTrainingMode.allCases.map(SubjTrainingModeOption.init)

    /// Onglets d'une matière : le Cours et les Annales ne concernent que les
    /// maths (les Annales seulement si elles sont servies), et les
    /// dissertations remplacent les exercices en ESH et HGG.
    static func options(
        forSubjectId subjectId: String,
        hasMathsAnnales: Bool
    ) -> [SubjTrainingModeOption] {
        all.filter { option in
            switch option.mode {
            case .cours:
                return subjectId == SubjSubjectRules.mathsSubjectId
            case .annales:
                return hasMathsAnnales && subjectId == SubjSubjectRules.mathsSubjectId
            case .dissertations:
                return SubjSubjectRules.usesDissertations(subjectId)
            case .exercices:
                return !SubjSubjectRules.usesDissertations(subjectId)
            case .colles:
                return true
            }
        }
    }
}

/// Barre d'onglets des modes (`TrainingModeTabs`).
///
/// La pastille choisie change dans un état local : le retour visuel reste sous
/// le doigt, la page et ses listes se remplacent ensuite via `onSelect`.
struct SubjTrainingModeTabs: View {
    let subjectId: String
    let subjectName: String
    let mode: SubjTrainingMode
    let availableModes: [SubjTrainingModeOption]
    var compact: Bool = false
    let onSelect: (SubjTrainingMode) -> Void

    @State private var displayedMode: SubjTrainingMode

    init(
        subjectId: String,
        subjectName: String,
        mode: SubjTrainingMode,
        availableModes: [SubjTrainingModeOption],
        compact: Bool = false,
        onSelect: @escaping (SubjTrainingMode) -> Void
    ) {
        self.subjectId = subjectId
        self.subjectName = subjectName
        self.mode = mode
        self.availableModes = availableModes
        self.compact = compact
        self.onSelect = onSelect
        _displayedMode = State(initialValue: mode)
    }

    var body: some View {
        HStack(spacing: compact ? 4 : 6) {
            ForEach(availableModes) { option in
                tab(option)
            }
        }
        .onChange(of: mode) { newValue in
            if displayedMode != newValue { displayedMode = newValue }
        }
    }

    /// Un onglet : pastille sélectionnée en encre pleine, les autres en gris.
    private func tab(_ option: SubjTrainingModeOption) -> some View {
        let selected = displayedMode == option.mode
        return Button {
            guard option.mode != displayedMode else { return }
            displayedMode = option.mode
            onSelect(option.mode)
        } label: {
            HStack(spacing: 5) {
                Image(systemName: option.systemImage)
                    .font(.system(size: compact ? 12 : 14, weight: .semibold))
                Text(option.label)
                    .font(.system(size: compact ? 12 : 13, weight: .heavy))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .foregroundStyle(selected ? Color.white : Theme.inkSoft)
            .padding(.horizontal, compact ? 8 : 10)
            .padding(.vertical, compact ? 5 : 7)
            .background(selected ? Theme.ink : Theme.surfaceMuted)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(option.label) — \(subjectName)")
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }
}
