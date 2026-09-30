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
    /// descripteur par chapitre de la matière. Le manifeste est conservé pour
    /// ré-indexer au changement d'onglet sans nouvel appel réseau.
    func loadManifest() async {
        guard case .idle = state else { return }
        state = .loading
        do {
            let manifest = try await DuelloAPI.contentManifest()
            self.manifest = manifest
            descriptors = TrainContent.chapterIndex(
                manifest: manifest,
                track: session.profile.track,
                specialty: session.profile.specialty,
                year: session.profile.year,
                mode: activeMode
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

    /// Ré-indexe les descripteurs de chapitre pour le mode ouvert, au changement
    /// d'onglet (`colleCardCatalog` / `chapterCardCatalog`, `SubjectsScreen.tsx:4617`) :
    /// en Colles, les banques `colles-*` passent devant les énoncés, ailleurs les
    /// énoncés servent. Sans manifeste (avant chargement), rien à ré-indexer. Le
    /// mode change la banque servie : les sujets déjà chargés appartiennent à
    /// l'ancien mode, ils sont relus au prochain dépliage.
    func reindexChapters() {
        guard let manifest else { return }
        descriptors = TrainContent.chapterIndex(
            manifest: manifest,
            track: session.profile.track,
            specialty: session.profile.specialty,
            year: session.profile.year,
            mode: activeMode
        )
        loadedExercises.removeAll()
        chapterStates.removeAll()
        chapterErrors.removeAll()
    }

    /// Banque d'annales servie de la matière (`annaleItems` / `getTrackAnnaleItems`,
    /// `SubjectsScreen.tsx:4493-4510`) : les annales des banques `*-annales-*`
    /// du manifeste de l'année, converties en entrées de lecteur. Chargée à la
    /// première ouverture de l'onglet Annales, puis conservée.
    ///
    /// V6 2026-09-30 (écart 06#3) : les banques d'annales ne figurent **que**
    /// dans les `bundles` du manifeste — `chapters` ne décrit que les
    /// `*-statements`. La lecture filtre donc `manifest.bundles` par identifiant
    /// (et non plus `manifest.chapters`, qui ne retenait rien) ; chaque banque
    /// est servie entière via `DuelloAPI.bundleItems(_:)` puis décodée par
    /// `AnnServedBank` (formes avancées et appliquées réunies).
    func loadAnnaleItems() async {
        guard annaleItems.isEmpty, let manifest else { return }
        let year = TrainContent.programYear(from: session.profile.year)
        let bankIds = TrainContent.yearBundleIds(
            track: session.profile.track,
            specialty: session.profile.specialty,
            year: year
        ).filter { $0.contains("annales") }
        guard !bankIds.isEmpty, let banks = manifest.bundles else { return }
        var loaded: [AnnEntry] = []
        for bankId in bankIds {
            guard let descriptor = banks.first(where: { $0.id == bankId }) else { continue }
            guard let items = try? await DuelloAPI.bundleItems(descriptor) else { continue }
            loaded.append(contentsOf: AnnServedBank.entries(items))
        }
        annaleItems = loaded
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
    /// la matière, le chapitre et l'offset figé à l'ouverture sont mémorisés
    /// pour que le catalogue s'y replace.
    func closeChapterDetail() {
        TrainCatalogueScrollMemory.shared.restore = TrainCatalogueScrollRestore(
            subjectId: subject.id,
            chapterId: openChapter?.id ?? "",
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

/// Retour attendu au catalogue (`recentlyClosedChapter`).
///
/// Écart assumé (iOS 16) : RN restaure l'offset **au pixel**
/// (`contentOffset={{y: listScrollOffset}}`, `SubjectsScreen.tsx:9912-9920`).
/// SwiftUI n'a pas d'API d'offset (`scrollPosition` est iOS 17) : le catalogue
/// se replace sur la **ligne du chapitre** quitté (`ScrollViewReader.scrollTo`,
/// ancrage haut), l'offset restant publié pour la mémoire de défilement.
struct TrainCatalogueScrollRestore: Equatable {
    let subjectId: String
    /// Chapitre quitté : ancre du replacement au retour.
    let chapterId: String
    let offset: CGFloat
}

/// Mémoire du défilement du catalogue (`chapterListScrollOffsetRef` +
/// `recentlyClosedChapter` de `SubjectsScreen.tsx`) : l'offset du programme est
/// figé à l'ouverture d'un chapitre et rendu au retour, pour que la liste
/// reprenne là où elle était.
///
/// Raccord fait dans `TrainingCatalogView` (`TrainingCatalogView+Entry.swift`) :
/// l'offset courant est publié au défilement (`handleChromeScroll` → `offset`)
/// et `restore` est appliqué à l'apparition du catalogue (`ScrollViewReader` →
/// `scrollTo` du chapitre), puis remis à `nil`.
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
