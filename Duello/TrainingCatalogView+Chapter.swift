import SwiftUI

/// Détail d'un chapitre ouvert : ligne, exercices, filtre de difficulté et
/// compteurs d'avancement. Extension de `TrainingCatalogView`.
extension TrainingCatalogView {

    // MARK: Chapitre

    @ViewBuilder
    func chapterBlock(_ chapter: TrackChapter) -> some View {
        TrainChapterRow(
            chapter: chapter,
            status: courseStatus.status(for: chapter.id),
            summaryText: summaryText(for: chapter),
            progressTotal: progressTotal(for: chapter),
            progressFraction: chapterFraction(for: chapter),
            isExpanded: expanded.contains(chapter.id),
            onToggleStatus: { courseStatus.cycle(chapter.id) },
            onToggleExpanded: { toggle(chapter) }
        )
        if expanded.contains(chapter.id) {
            chapterBody(chapter)
        }
    }

    @ViewBuilder
    private func chapterBody(_ chapter: TrackChapter) -> some View {
        switch chapterStates[chapter.id] ?? .idle {
        case .idle, .loading:
            HStack(spacing: 8) {
                ProgressView()
                Text("Chargement…")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.inkFaint)
            }
            .padding(.vertical, 14)
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
                difficultyFilterRow(chapter)
                if visible.isEmpty {
                    emptyExercises(chapter, hasLoadedItems: !loaded.isEmpty)
                } else {
                    ForEach(Array(visible.indices), id: \.self) { index in
                        TrainExerciseCard(
                            exercise: visible[index],
                            number: index + 1,
                            fraction: progress.progressFraction(for: visible[index].id),
                            hasProgress: progress.items[visible[index].id]?.bestOutcome != nil
                        )
                    }
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

    /// Filtre de difficulté du chapitre ouvert, comme le menu « Difficulté » de
    /// l'en-tête de chapitre Expo : « Tout » puis les six paliers.
    private func difficultyFilterRow(_ chapter: TrackChapter) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                DuelloChip(title: "Tout", selected: difficultyFilters[chapter.id] == nil) {
                    difficultyFilters[chapter.id] = nil
                }
                ForEach(TrainDifficulty.order, id: \.self) { level in
                    DuelloChip(
                        title: TrainDifficulty.label(for: level),
                        selected: difficultyFilters[chapter.id] == level
                    ) {
                        difficultyFilters[chapter.id] = difficultyFilters[chapter.id] == level ? nil : level
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }

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

    // MARK: Libellés et compteurs de chapitre

    /// Résumé affiché sous le nom du chapitre. Les mathématiques annoncent
    /// directement « 3/12 exercices réussis » ; les autres matières détaillent
    /// d'abord ce qui est disponible et corrigé, comme `ChapterRow`.
    private func summaryText(for chapter: TrackChapter) -> String {
        let summary = chapterSummary(for: chapter)
        let total = progressTotal(for: chapter)
        guard total > 0 else {
            if let catalogued = summary.catalogued {
                return TrainCopy.availability(.exercise, count: catalogued)
            }
            return "Aucun sujet disponible"
        }
        if subject.id == "maths" {
            return TrainCopy.success(.exercise, succeeded: summary.succeeded, available: total)
        }
        var text = TrainCopy.availability(.exercise, count: summary.available)
        if summary.withSolution > 0 {
            text += " · \(TrainCopy.solutions(count: summary.withSolution))"
        }
        text += " · \(TrainCopy.success(.exercise, succeeded: summary.succeeded, available: summary.available, withNoun: false))"
        return text
    }

    /// Avancement d'un chapitre, compté en sujets réussis comme la barre de la
    /// matière (`chapterItemsSummary`).
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

    /// Dénominateur d'avancement du chapitre (`chapterModeProgressTotal`).
    private func progressTotal(for chapter: TrackChapter) -> Int {
        chapterSummary(for: chapter).progressTotal(kind: .exercise)
    }

    private func chapterFraction(for chapter: TrackChapter) -> Double {
        let total = progressTotal(for: chapter)
        guard total > 0 else { return 0 }
        return min(1, max(0, Double(chapterSummary(for: chapter).succeeded) / Double(total)))
    }
}
