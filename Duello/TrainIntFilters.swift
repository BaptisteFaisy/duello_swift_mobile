//
//  TrainIntFilters.swift
//  Duello
//
//  Lot 16 « intégration de l'onglet Entraînement » (préfixe `TrainInt`).
//
//  Ligne de filtres de l'en-tête de chapitre : menus « Prérequis » et
//  « Difficulté », comme `chapterHeaderFilters` de l'écran Expo.
//
//  Fichiers source Expo portés :
//    - src/screens/SubjectsScreen.tsx (lignes 9087-9136, 9208-9256) :
//      `showChapterHeaderFilters`, `chapterBadgeControls` (limités au groupe
//      `difficulty`), `chapterPrerequisiteControl` (options
//      `PREREQUISITE_FILTER_OPTIONS`), puis `filterItemsByBadges` et
//      `filterItemsByPrerequisite`.
//    - src/utils/exerciseBadgeFilter.ts : `PREREQUISITE_FILTER_OPTIONS`,
//      `prerequisiteFilterValue`, `filterItemsByPrerequisite`.
//
//  V2 2026-09-28 (U06#7, #8, #14, #15) : les menus « Notions » et « Classique »
//  ne sont plus réexposés (masqués dans la source : le JSX les commente) ;
//  « Difficulté » devient multi-choix (badges cumulés) et un menu « Prérequis »
//  est ajouté. La ligne n'est montée que lorsque `canFilterByBadge` et que des
//  sujets sont chargés (`showChapterHeaderFilters`).
//
//  Cible iOS 16, aucune dépendance externe.
//
import SwiftUI

extension TrainingCatalogView {

    /// Libellé du menu des prérequis (`chapterPrerequisiteControl.label`).
    static let prerequisiteFilterLabel = "Prérequis"

    /// `canFilterByBadge` : la banque servie d'une matière de maths, en
    /// Exercices ou en Colles, ouvre le filtrage par badges et prérequis.
    func canFilterByBadge(_ chapter: TrackChapter) -> Bool {
        subject.id == SubjSubjectRules.mathsSubjectId
            && (activeMode == .exercices || activeMode == .colles)
            && descriptors[chapter.id] != nil
    }

    /// `showChapterHeaderFilters` : en Exercices le chrome de filtres est
    /// toujours armé (le menu Notions, masqué, suffit à le déclencher) ; ailleurs
    /// il ne paraît que si la banque servie et des sujets sont présents.
    func showsChapterHeaderFilters(_ chapter: TrackChapter) -> Bool {
        activeMode == .exercices || (canFilterByBadge(chapter) && !(loadedExercises[chapter.id] ?? []).isEmpty)
    }

    /// Options du menu « Difficulté » : les six paliers du barème.
    var difficultyOptions: [SubjExerciseFilterValue] {
        TrainDifficulty.order.map { SubjExerciseFilterValue.difficulty($0) }
    }

    /// Options du menu « Prérequis » (`PREREQUISITE_FILTER_OPTIONS`).
    var prerequisiteOptions: [SubjExerciseFilterValue] {
        SubjPrerequisiteFilterValue.options.map { SubjExerciseFilterValue.prerequisite($0) }
    }

    /// Sélection courante du menu « Difficulté » pour un chapitre ; vide quand
    /// aucun palier n'est retenu (« Tout »).
    func difficultySelection(_ chapter: TrackChapter) -> [SubjExerciseFilterValue] {
        (difficultyFilters[chapter.id] ?? []).sorted().map { SubjExerciseFilterValue.difficulty($0) }
    }

    /// Sélection courante du menu « Prérequis » pour un chapitre ; vide quand
    /// aucun état n'est retenu (« Tout »).
    func prerequisiteSelection(_ chapter: TrackChapter) -> [SubjExerciseFilterValue] {
        SubjPrerequisiteFilterValue.options
            .filter { (prerequisiteFilters[chapter.id] ?? []).contains($0) }
            .map { SubjExerciseFilterValue.prerequisite($0) }
    }

    /// `prerequisiteFilterValue` : l'état de prérequis d'un sujet, ramené aux
    /// trois choix du filtre (même décision que la pastille de la carte).
    func prerequisiteFilterValue(
        _ exercise: TrainExercise, chapter: TrackChapter, context: PrerequisiteCardContext
    ) -> SubjPrerequisiteFilterValue {
        let model = itemCardModel(exercise, chapter: chapter, context: context)
        switch SubjPrerequisiteStatus.value(
            availableCount: model.availableQuestionCount,
            totalCount: model.totalQuestionCount
        ) {
        case .ready: return .ready
        case .partly: return .partly
        case .later: return .later
        }
    }

    /// Ligne des menus de filtre du chapitre ouvert. La sélection des paliers
    /// comme des prérequis est cumulative (« N choix »), comme le JSX.
    func filterRow(_ chapter: TrackChapter) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: TrainGridStyles.filterRowAlignment, spacing: 8) {
                SubjBadgeFilterDropdown(
                    label: Self.prerequisiteFilterLabel,
                    options: prerequisiteOptions,
                    selected: prerequisiteSelection(chapter),
                    onSelect: { value in
                        var current = prerequisiteFilters[chapter.id] ?? []
                        guard let prerequisite = value?.prerequisiteValue else {
                            current.removeAll()
                            prerequisiteFilters[chapter.id] = current
                            return
                        }
                        if current.contains(prerequisite) {
                            current.remove(prerequisite)
                        } else {
                            current.insert(prerequisite)
                        }
                        prerequisiteFilters[chapter.id] = current
                    },
                    inChapterHeader: true
                )
                SubjBadgeFilterDropdown(
                    label: SubjFilterCopy.difficulty,
                    options: difficultyOptions,
                    selected: difficultySelection(chapter),
                    onSelect: { value in
                        var current = difficultyFilters[chapter.id] ?? []
                        guard let value, case .difficulty(let level) = value else {
                            current.removeAll()
                            difficultyFilters[chapter.id] = current
                            return
                        }
                        if current.contains(level) {
                            current.remove(level)
                        } else {
                            current.insert(level)
                        }
                        difficultyFilters[chapter.id] = current
                    },
                    inChapterHeader: true
                )
            }
            .padding(.vertical, 2)
        }
    }
}
