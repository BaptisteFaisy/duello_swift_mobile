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
//  l'onglet Annales est donc retiré (l'ancien état vide était visible en ECG et
//  MPSI). Le mode « Cours » n'ouvre pas de document PDF ici :
//  `SubjCourseChapterRow` lit le statut du chapitre, faute de repère.
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

    /// Onglets réellement proposés pour la matière. L'onglet Annales est retiré
    /// tant que la banque d'annales n'est pas branchée sur cet écran : sa
    /// section s'arrête sinon sur un état vide, visible dès que `hasAnnaleBank`
    /// est vrai (ECG et MPSI) — cf. `annalesFallback`.
    var modeOptions: [SubjTrainingModeOption] {
        SubjTrainingModeCatalog.options(
            forSubjectId: subject.id,
            hasMathsAnnales: SubjTrainingModeCatalog.hasAnnaleBank(track: session.profile.track)
        )
        .filter { $0.mode != .annales }
    }

    /// Barre d'onglets : le retour visuel reste sous le doigt, le contenu se
    /// remplace ensuite via `onSelect`. Le rembourrage haut est appliqué par
    /// l'appelant (4 en maths, sous la barre de métriques épinglée ; 12 dans le
    /// contenu d'une matière non-maths).
    var modeTabsRow: some View {
        SubjTrainingModeTabs(
            subjectId: subject.id,
            subjectName: subject.name,
            mode: activeMode,
            availableModes: modeOptions,
            onSelect: { modeOverride = $0 }
        )
    }

    /// L'encart explicatif animé ne concerne que les maths, dans les modes
    /// Cours, Exercices et Colles (`courseLegendVisible` + branche maths).
    var showsCourseHint: Bool {
        subject.id == SubjSubjectRules.mathsSubjectId
            && [.cours, .exercices, .colles].contains(activeMode)
    }

    /// Le guide du parcours suit les listes qui mènent à un sujet (Exercices,
    /// Colles, Annales) ; il disparaît en Cours et en Dissertations.
    var showsWorkflowGuide: Bool {
        activeMode != .cours && activeMode != .dissertations
    }

    // MARK: Assemblage

    /// Panneau d'une matière ouverte : encart de légende, contenu du mode, puis
    /// rappel de légende et guide. Les onglets de modes n'y figurent plus : ceux
    /// des maths vivent dans l'en-tête épinglé, ceux des autres matières dans le
    /// corps du `ScrollView`, hors de la garde de chargement.
    @ViewBuilder
    var catalogueSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            if showsCourseHint && legendStore.isVisible {
                SubjCourseProgressLegend(onDismiss: { legendStore.dismiss() })
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

    /// Pied du panneau : rappel statique de la légende — pour **toute** matière
    /// ouverte hors annales, dès lors que l'encart n'a pas été masqué —, puis
    /// guide du parcours.
    @ViewBuilder
    var catalogueFooter: some View {
        if activeMode != .annales && legendStore.isVisible {
            SubjCourseProgressLegend()
        }
        if showsWorkflowGuide {
            SubjTrainingWorkflowGuide()
        }
    }

    // MARK: Reprise du dernier sujet

    /// Sujet entamé mais non réussi, à reprendre en tête du contenu des maths
    /// (`resumableExercise`). Le store local ne retient pas l'instant de la
    /// dernière tentative (`ItemProgress` d'Expo porte `lastAttempt`, pas sa
    /// copie Swift) : à défaut de savoir lequel est le plus récent, la reprise
    /// désigne le premier item entamé dans l'ordre du programme. Les annales,
    /// absentes de cet écran, ne sont pas candidates.
    var resumableExercise: TrainResumableExercise? {
        guard subject.id == SubjSubjectRules.mathsSubjectId else { return nil }
        let chapterOrder = subject.chapters.map { $0.id }
        let chapterIds = Set(chapterOrder)
        let candidates: [TrainResumableExercise] = progress.items.compactMap { itemId, item in
            guard item.attempts > 0, item.bestOutcome != .success else { return nil }
            guard let chapterId = TrainItemID.chapterId(of: itemId),
                  chapterIds.contains(chapterId) else { return nil }
            return TrainResumableExercise(
                itemId: itemId,
                chapterId: chapterId,
                title: resumableTitle(forItemId: itemId, chapterId: chapterId),
                mode: resumableMode(forItemId: itemId)
            )
        }
        return candidates.min { left, right in
            let leftRank = left.chapterId.flatMap { chapterOrder.firstIndex(of: $0) } ?? Int.max
            let rightRank = right.chapterId.flatMap { chapterOrder.firstIndex(of: $0) } ?? Int.max
            return leftRank == rightRank ? left.itemId < right.itemId : leftRank < rightRank
        }
    }

    /// Mode d'entraînement d'un sujet repris : les colles se reprennent en
    /// Colles, le reste en Exercices (`activity` de `resumableExercise`).
    private func resumableMode(forItemId itemId: String) -> SubjTrainingMode {
        itemId.contains("::colle::") ? .colles : .exercices
    }

    /// Titre du sujet, quand son chapitre est déjà chargé (`item?.title`).
    private func resumableTitle(forItemId itemId: String, chapterId: String) -> String {
        (loadedExercises[chapterId] ?? []).first { $0.id == itemId }?.title
            ?? "Dernier sujet commencé"
    }
}

/// Sujet à reprendre, tel que le lit la carte de reprise (`resumableExercise`).
struct TrainResumableExercise: Equatable {
    let itemId: String
    /// Chapitre du sujet ; `nil` pour une annale, qui n'en a pas.
    let chapterId: String?
    let title: String
    /// Onglet à ouvrir pour retrouver le sujet.
    let mode: SubjTrainingMode
}

/// Carte « Reprendre le dernier exercice » (`exerciseResumeRow` de
/// `SubjectsScreen.tsx`) : une pastille sur fond d'encre pâle et une croix de
/// masquage, dans une carte bordée.
struct TrainResumeCard: View {
    let onResume: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onResume) {
                Text("Reprendre le dernier exercice")
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundStyle(Theme.inkSoft)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Theme.ink.opacity(0.10))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Reprendre le dernier exercice")

            Spacer(minLength: 0)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 18))
                    .foregroundStyle(Theme.inkSoft)
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Masquer la reprise")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .frame(minHeight: 44)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLarge))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusLarge)
                .stroke(Theme.border, lineWidth: 1)
        )
        .padding(.top, 7)
        .padding(.bottom, 12)
    }
}
