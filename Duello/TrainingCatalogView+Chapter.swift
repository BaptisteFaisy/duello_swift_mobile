import SwiftUI

/// Détail d'un chapitre ouvert : ligne, exercices, filtre de difficulté et
/// compteurs d'avancement. Extension de `TrainingCatalogView`.
extension TrainingCatalogView {

    // MARK: Chapitre

    @ViewBuilder
    func chapterBlock(_ chapter: TrackChapter) -> some View {
        let subjChapter = TrainIntProgram.subjChapter(
            chapter,
            status: courseStatus.status(for: chapter.id)
        )
        if activeMode == .cours {
            // Vue Cours : la ligne sert à mettre à jour l'avancement du cours
            // (`CourseChapterRow`), sans résumé de sujets ni chevron.
            SubjCourseChapterRow(
                chapter: subjChapter,
                coursePosition: nil,
                hasCourseDocument: false,
                isReturnHighlighted: false,
                onToggleCourseStatus: { courseStatus.cycle(chapter.id) },
                onOpen: { toggle(chapter) }
            )
        } else if let chapterMode = activeMode.chapterMode {
            SubjChapterRow(
                subjectId: subject.id,
                chapter: subjChapter,
                mode: chapterMode,
                summary: chapterSummary(for: chapter),
                isReturnHighlighted: false,
                onToggleCourseStatus: { courseStatus.cycle(chapter.id) },
                onOpen: { toggle(chapter) }
            )
        }
        if expanded.contains(chapter.id) {
            chapterBody(chapter)
        }
    }

    @ViewBuilder
    private func chapterBody(_ chapter: TrackChapter) -> some View {
        switch chapterStates[chapter.id] ?? .idle {
        case .idle, .loading:
            // Repli de chargement dans le flux (`DeferredInlineFallback`).
            SubjDeferredInlineFallback(label: "Ouverture du chapitre…")
                .padding(.leading, 4)
        case .error:
            DuelloEmptyState(
                icon: "exclamationmark.triangle",
                title: "Téléchargement impossible",
                message: chapterErrors[chapter.id]
            )
            .duelloCard()
        case .ready:
            let loaded = loadedExercises[chapter.id] ?? []
            let visible = visibleExercises(chapter)
            VStack(alignment: .leading, spacing: 8) {
                if !loaded.isEmpty {
                    detailSummary(loaded: loaded)
                }
                filterRow(chapter)
                if visible.isEmpty {
                    emptyExercises(chapter, hasLoadedItems: !loaded.isEmpty)
                } else {
                    exerciseList(visible)
                }
            }
            .padding(.top, 2)
            .padding(.bottom, 6)
        }
    }

    /// Récapitulatif d'un chapitre ouvert : « 12 exercices disponibles · 3 avec
    /// corrigé » (branche `!canFilterByBadge` de `SubjectsScreen`).
    private func detailSummary(loaded: [TrainExercise]) -> some View {
        let solutions = loaded.filter { $0.hasSolution }.count
        var text = TrainCopy.availability(.exercise, count: loaded.count)
        if solutions > 0 {
            text += " · \(solutions) avec corrigé"
        }
        return Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Theme.inkFaint)
    }

    // Le filtre du chapitre ouvert (menus « Notions », « Difficulté » et
    // « Classique ») vit dans `TrainIntFilters.swift` (`filterRow(_:)`).

    @ViewBuilder
    private func emptyExercises(_ chapter: TrackChapter, hasLoadedItems: Bool) -> some View {
        if hasLoadedItems {
            // Des sujets existent, mais le filtre de difficulté les masque tous.
            DuelloEmptyState(
                icon: "line.3.horizontal.decrease.circle",
                title: "Aucun exercice",
                message: "Aucun exercice ne correspond à ce filtre."
            )
        } else if descriptors[chapter.id] == nil {
            DuelloEmptyState(
                icon: "tray",
                title: "Aucun exercice",
                message: "Aucun exercice n’est rattaché à ce chapitre."
            )
        } else {
            DuelloEmptyState(
                icon: "tray",
                title: "Aucun exercice",
                message: "Aucun contenu détaillé n’est disponible pour les exercices de ce chapitre."
            )
        }
    }

    // MARK: Compteurs de chapitre

    /// Avancement d'un chapitre, compté en sujets réussis comme la barre de la
    /// matière (`chapterItemsSummary`). Le résumé affiché sous le nom du
    /// chapitre est construit par la ligne elle-même
    /// (`SubjChapterRowSummary.make`, `SubjChapterRows.swift`).
    private func chapterSummary(for chapter: TrackChapter) -> TrainChapterSummary {
        let loaded = loadedExercises[chapter.id] ?? []
        let catalogued = descriptors[chapter.id]?.count ?? 0
        let succeeded = progress.items.keys.filter { itemId in
            TrainItemID.chapterId(of: itemId) == chapter.id
                && progress.items[itemId]?.bestOutcome == .success
        }.count
        return TrainChapterSummary(
            available: catalogued,
            catalogued: catalogued > 0 ? catalogued : nil,
            withSolution: loaded.filter { $0.hasSolution }.count,
            succeeded: succeeded
        )
    }
}
