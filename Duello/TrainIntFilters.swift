//
//  TrainIntFilters.swift
//  Duello
//
//  Lot 16 « intégration de l'onglet Entraînement » (préfixe `TrainInt`).
//
//  Ligne de filtres d'un chapitre ouvert : menus « Notions », « Difficulté »
//  (multi-choix des paliers) et « Classique », comme `chapterHeaderFilters` de
//  l'écran Expo.
//
//  Fichiers source Expo portés :
//    - src/screens/SubjectsScreen.tsx (lignes 9153-9205) : `NotionsDropdown`,
//      `BadgeFilterDropdown` (contrôle des prérequis puis des badges) et
//      `ClassiqueDropdown` en en-tête de chapitre.
//
//  Limite assumée : la banque servie en Swift n'expose ni badges, ni rôles, ni
//  prérequis — seul le palier de difficulté est connu. Le menu « Difficulté »
//  filtre donc réellement les sujets ; « Notions » (emplacement réservé) et
//  « Classique » restent des sélecteurs d'interface. Dans la source, ces deux
//  derniers sont d'ailleurs masqués (« masqué à la demande de l'utilisateur ») :
//  les composants portés sont ici réexposés.
//
//  Cible iOS 16, aucune dépendance externe.
//
import SwiftUI

extension TrainingCatalogView {

    /// Options du menu « Difficulté » : les six paliers du barème.
    var difficultyOptions: [SubjExerciseFilterValue] {
        TrainDifficulty.order.map { SubjExerciseFilterValue.difficulty($0) }
    }

    /// Sélection courante du menu « Difficulté » pour un chapitre ; vide quand
    /// aucun palier n'est retenu (« Tout »).
    func difficultySelection(_ chapter: TrackChapter) -> [SubjExerciseFilterValue] {
        difficultyFilters[chapter.id].map { [SubjExerciseFilterValue.difficulty($0)] } ?? []
    }

    /// Ligne des menus de filtre du chapitre ouvert. Le menu « Difficulté »
    /// n'offre qu'un palier à la fois, comme les anciennes puces : retenir un
    /// palier remplace le précédent, « Tout » l'efface.
    func filterRow(_ chapter: TrackChapter) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: TrainGridStyles.filterRowAlignment, spacing: 8) {
                SubjNotionsDropdown(inChapterHeader: true)
                SubjBadgeFilterDropdown(
                    label: SubjFilterCopy.difficulty,
                    options: difficultyOptions,
                    selected: difficultySelection(chapter),
                    onSelect: { value in
                        if let value, case .difficulty(let level) = value {
                            difficultyFilters[chapter.id] = level
                        } else {
                            difficultyFilters[chapter.id] = nil
                        }
                    },
                    inChapterHeader: true
                )
                SubjClassiqueDropdown(
                    selected: classicFilter,
                    onSelect: { classicFilter = $0 },
                    inChapterHeader: true
                )
            }
            .padding(.vertical, 2)
        }
    }
}
