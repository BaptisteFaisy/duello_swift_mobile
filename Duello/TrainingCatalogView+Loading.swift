import SwiftUI

/// Chargement du manifeste de contenu et des exercices d'un chapitre.
/// Extension de `TrainingCatalogView`.
extension TrainingCatalogView {

    // MARK: Chargement

    func retry() {
        state = .idle
        manifestError = nil
        Task { await loadManifest() }
    }

    /// Manifeste de contenu : un seul appel pour tout le catalogue, puis un
    /// descripteur par chapitre de la matière.
    func loadManifest() async {
        guard case .idle = state else { return }
        state = .loading
        do {
            let manifest = try await DuelloAPI.contentManifest()
            descriptors = TrainContent.chapterIndex(
                manifest: manifest,
                track: session.profile.track,
                specialty: session.profile.specialty,
                year: session.profile.year
            )
            // Décompte du catalogue, exercices servis, colles et annales réunis :
            // c'est le dénominateur de l'en-tête de la matière.
            catalogTotals = TrainContent.catalogCounts(
                manifest: manifest,
                track: session.profile.track,
                specialty: session.profile.specialty,
                year: session.profile.year
            )
            state = .ready
        } catch {
            manifestError = TrainErrorMessage.text(for: error)
            state = .error
        }
    }

    func toggle(_ chapter: TrackChapter) {
        if expanded.contains(chapter.id) {
            expanded.remove(chapter.id)
            return
        }
        expanded.insert(chapter.id)
        guard loadedExercises[chapter.id] == nil, chapterStates[chapter.id] == nil else { return }
        Task { await loadExercises(for: chapter) }
    }

    /// Énoncés d'un chapitre, chargés à son premier dépliage seulement.
    private func loadExercises(for chapter: TrackChapter) async {
        guard let descriptor = descriptors[chapter.id] else {
            loadedExercises[chapter.id] = []
            chapterStates[chapter.id] = .ready
            return
        }
        chapterStates[chapter.id] = .loading
        do {
            let seeds = try await DuelloAPI.chapterExercises(descriptor)
            loadedExercises[chapter.id] = seeds.map { TrainExercise(seed: $0) }
            chapterErrors[chapter.id] = nil
            chapterStates[chapter.id] = .ready
        } catch {
            chapterErrors[chapter.id] = TrainErrorMessage.text(for: error)
            chapterStates[chapter.id] = .error
        }
    }

    /// Sujets du chapitre filtrés par difficulté, puis rangés par palier.
    func visibleExercises(_ chapter: TrackChapter) -> [TrainExercise] {
        let loaded = loadedExercises[chapter.id] ?? []
        guard let level = difficultyFilters[chapter.id] else {
            return TrainExercise.orderedByDifficulty(loaded)
        }
        return TrainExercise.orderedByDifficulty(loaded.filter { $0.difficulty == level })
    }
}
