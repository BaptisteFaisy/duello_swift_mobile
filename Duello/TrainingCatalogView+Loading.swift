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
            loadCourseMarkers()
        } catch {
            manifestError = TrainErrorMessage.text(for: error)
            state = .error
        }
    }

    /// Ouvre un chapitre en plein écran (`openChapterList` de la source) et
    /// lance le chargement de ses sujets au premier affichage (hors mode Cours,
    /// qui n'affiche pas de liste de sujets).
    func openChapterDetail(_ chapter: TrackChapter) {
        // L'offset du catalogue est figé à l'ouverture, comme
        // `openChapter.listScrollOffset` de la source (`SubjectsScreen.tsx:7376`).
        TrainCatalogueScrollMemory.shared.pendingOpenOffset = TrainCatalogueScrollMemory.shared.offset
        openChapter = chapter
        guard activeMode != .cours else { return }
        Task { await loadExercisesIfNeeded(for: chapter) }
    }

    /// Referme la page du chapitre et revient au programme de la matière, à
    /// l'endroit quitté (`recentlyClosedChapter`, `SubjectsScreen.tsx:4085-4100`) :
    /// la matière et l'offset figé à l'ouverture sont mémorisés pour que le
    /// catalogue s'y replace.
    func closeChapterDetail() {
        TrainCatalogueScrollMemory.shared.restore = TrainCatalogueScrollRestore(
            subjectId: subject.id,
            offset: TrainCatalogueScrollMemory.shared.pendingOpenOffset
        )
        openChapter = nil
    }

    /// Énoncés d'un chapitre, chargés à sa première ouverture seulement.
    func loadExercisesIfNeeded(for chapter: TrackChapter) async {
        guard loadedExercises[chapter.id] == nil, chapterStates[chapter.id] == nil else { return }
        await loadExercises(for: chapter)
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
            var items = seeds.map { TrainExercise(seed: $0) }
            // Revue de prérequis du chapitre (`chapterItems.ts`) : scope lu dans
            // le `bundleId` du descripteur, empreinte de la filière, puis revue
            // aiguillée par `ProgPrereq.review(_:)`.
            TrainExercisePrereq.apply(&items, descriptor: descriptor)
            loadedExercises[chapter.id] = items
            chapterErrors[chapter.id] = nil
            chapterStates[chapter.id] = .ready
        } catch {
            chapterErrors[chapter.id] = TrainErrorMessage.text(for: error)
            chapterStates[chapter.id] = .error
        }
    }

    /// Sujets du chapitre filtrés par difficulté (multi-choix) puis par
    /// prérequis, et rangés par palier (`filterItemsByBadges` puis
    /// `filterItemsByPrerequisite` de la source).
    func visibleExercises(_ chapter: TrackChapter) -> [TrainExercise] {
        let loaded = loadedExercises[chapter.id] ?? []
        var items = loaded
        if let levels = difficultyFilters[chapter.id], !levels.isEmpty {
            items = items.filter { exercise in
                guard let level = exercise.difficulty else { return false }
                return levels.contains(level)
            }
        }
        let prerequisites = prerequisiteFilters[chapter.id] ?? []
        if !prerequisites.isEmpty {
            let context = prerequisiteCardContext()
            items = items.filter { exercise in
                prerequisites.contains(
                    prerequisiteFilterValue(exercise, chapter: chapter, context: context)
                )
            }
        }
        return TrainExercise.orderedByDifficulty(items)
    }
}

// MARK: - Mémoire du défilement du catalogue

/// Offset à réappliquer au retour d'un chapitre (`recentlyClosedChapter`).
struct TrainCatalogueScrollRestore {
    let subjectId: String
    let offset: CGFloat
}

/// Mémoire du défilement du catalogue (`chapterListScrollOffsetRef` +
/// `recentlyClosedChapter` de `SubjectsScreen.tsx`) : l'offset du programme est
/// figé à l'ouverture d'un chapitre et rendu au retour, pour que la liste
/// reprenne là où elle était.
///
/// Raccord à faire dans `TrainingCatalogView` (`TrainingCatalogView+Entry.swift`,
/// hors lot) : publier l'offset courant (`handleChromeScroll` → `offset`) et
/// appliquer `restore` à l'apparition de la page du catalogue
/// (`ScrollViewReader` → `scrollTo`), puis remettre `restore` à `nil`.
@MainActor
final class TrainCatalogueScrollMemory: ObservableObject {
    static let shared = TrainCatalogueScrollMemory()

    /// Dernier offset observé du catalogue (publié par le défilement).
    var offset: CGFloat = 0
    /// Offset figé à l'ouverture du chapitre courant.
    var pendingOpenOffset: CGFloat = 0
    /// Retour attendu : matière et offset à réappliquer, consommé à l'affichage.
    @Published var restore: TrainCatalogueScrollRestore?

    private init() {}
}
