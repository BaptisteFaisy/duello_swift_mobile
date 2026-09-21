//
//  TrainIntMode.swift
//  Duello
//
//  Lot 16 « intégration de l'onglet Entraînement » (préfixe `TrainInt`).
//
//  Assemblage réel d'une matière ouverte : barre d'onglets des modes, encart
//  explicatif du statut de cours, catalogue de chapitres par mode, puis rappel
//  de la légende et guide du parcours. Remplace la version réduite qui
//  enchaînait directement les chapitres.
//
//  Fichiers source Expo portés :
//    - src/screens/SubjectsScreen.tsx (lignes 9967-10193 : `subjectPanel`) :
//      `CourseProgressLegend` (encart puis rappel statique), `TrainingModeTabs`
//      (`renderModeTabs`), bandeau de disponibilité, section Annales,
//      `TrainingWorkflowGuide`.
//
//  Réutilise, sans rien redéfinir : `SubjTrainingModeTabs`,
//  `SubjTrainingModeCatalog`, `SubjModeAvailability`, `SubjCourseProgressLegend`,
//  `SubjTrainingWorkflowGuide`, `DuelloEmptyState` et les briques déjà en place
//  dans `TrainingCatalogView+Content.swift`.
//
//  Limite assumée : la section Annales n'a pas de banque servie dans cet écran,
//  elle s'arrête donc sur un état vide (les annales d'une matière ne sont pas
//  encore chargées sur l'appareil). Le mode « Cours » n'ouvre pas de document
//  PDF ici : `SubjCourseChapterRow` lit le statut du chapitre, faute de repère.
//
//  Cible iOS 16, aucune dépendance externe.
//
import SwiftUI

extension TrainingCatalogView {

    // MARK: Mode ouvert

    /// Mode ouvert : le choix de l'élève, ou le mode par défaut de la matière.
    var activeMode: SubjTrainingMode {
        modeOverride ?? TrainIntProgram.defaultMode(forSubjectId: subject.id)
    }

    /// Onglets réellement proposés pour la matière. Les annales des maths ne
    /// sont pas servies ici, donc l'onglet reste masqué (`hasMathsAnnales`).
    var modeOptions: [SubjTrainingModeOption] {
        SubjTrainingModeCatalog.options(forSubjectId: subject.id, hasMathsAnnales: false)
    }

    /// Barre d'onglets : le retour visuel reste sous le doigt, le contenu se
    /// remplace ensuite via `onSelect`.
    var modeTabsRow: some View {
        SubjTrainingModeTabs(
            subjectId: subject.id,
            subjectName: subject.name,
            mode: activeMode,
            availableModes: modeOptions,
            onSelect: { modeOverride = $0 }
        )
        .padding(.top, 12)
    }

    /// La légende du statut de cours ne concerne que les maths, dans les modes
    /// Cours, Exercices et Colles (`courseLegendVisible`).
    var showsCourseLegend: Bool {
        subject.id == SubjSubjectRules.mathsSubjectId
            && [.cours, .exercices, .colles].contains(activeMode)
    }

    /// Le guide du parcours suit les listes qui mènent à un sujet (Exercices,
    /// Colles, Annales) ; il disparaît en Cours et en Dissertations.
    var showsWorkflowGuide: Bool {
        activeMode != .cours && activeMode != .dissertations
    }

    // MARK: Assemblage

    /// Panneau d'une matière ouverte : onglets, encart de légende, contenu du
    /// mode, puis légende statique et guide.
    @ViewBuilder
    var catalogueSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            modeTabsRow
            if showsCourseLegend && legendHintVisible {
                SubjCourseProgressLegend(onDismiss: { legendHintVisible = false })
                    .padding(.top, 12)
            }
            if activeMode == .annales {
                annalesFallback
            } else {
                chapterCatalogue
            }
            catalogueFooter
        }
    }

    /// État vide de la section Annales, faute de banque servie dans cet écran.
    var annalesFallback: some View {
        DuelloEmptyState(
            icon: "books.vertical",
            title: "Annales indisponibles",
            message: "Les annales de cette matière ne sont pas encore chargées sur l’appareil."
        )
        .padding(.top, 20)
    }

    /// Pied du panneau : rappel statique de la légende, puis guide du parcours.
    @ViewBuilder
    var catalogueFooter: some View {
        if showsCourseLegend {
            SubjCourseProgressLegend()
        }
        if showsWorkflowGuide {
            SubjTrainingWorkflowGuide()
        }
    }
}
