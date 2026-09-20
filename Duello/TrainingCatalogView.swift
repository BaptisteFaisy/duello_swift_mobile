import Foundation
import SwiftUI

/// Catalogue d'entraînement d'une matière : les chapitres de son programme,
/// chacun dépliable vers ses exercices servis par l'API.
///
/// Porté de :
/// - `src/screens/SubjectsScreen.tsx` — écran « Entraînement » : en-tête de
///   matière (compteur « X/Y sujets réussis », barre d'avancement), ligne de
///   chapitre (statut de cours « À venir / En cours / Vu », avancement, libellés
///   accordés), regroupement par domaine, filtre de difficulté et tri par palier
///   (`groupItemsByDifficulty`) ;
/// - `src/data/tracks.ts` — `CHAPTER_DOMAINS`, `CHAPTER_DOMAIN_LABELS` et
///   `groupChaptersByDomain` : ordre d'affichage des domaines et groupe final
///   « Autres chapitres » ;
/// - `src/utils/itemDifficulty.ts` — `DIFFICULTY_ORDER` et `DIFFICULTY_LABELS`
///   (« Très facile » → « Extrême ») ;
/// - `src/utils/subjectSuccess.ts` — `chapterModeProgressTotal`, dénominateur
///   d'avancement d'un chapitre ;
/// - `src/content/contentStartup.ts` — `profileBundleIds` et
///   `exerciseContentBundleIds`, pour choisir dans `/content/manifest.json` la
///   banque d'énoncés du programme de l'élève ;
/// - `src/content/servedBank.ts` — forme de l'identifiant d'item
///   `chapitre::exercice::clé`, partagée avec `ProgressStore`.
///
/// Point d'entrée du contrat d'intégration : `TrainingCatalogView(subject:)`.
///
/// Limites assumées (détaillées sur chaque type concerné) : le contenu servi ne
/// porte ni prérequis, ni rôle, ni thème, ni marque « Classique » — les filtres
/// correspondants de l'écran Expo (Prêt / En partie / Plus tard, Type, Domaine,
/// Classique, Notions) ne sont donc pas portés ici ; seul le filtre de difficulté
/// et le tri par palier le sont.

// MARK: - Point d'entrée

/// Catalogue d'une matière : liste des chapitres de son programme, chaque
/// chapitre dépliable vers ses exercices chargés par
/// `DuelloAPI.chapterExercises(_:)`.
struct TrainingCatalogView: View {
    /// Matière dont on affiche le programme.
    let subject: TrackSubject

    @EnvironmentObject private var session: SessionStore
    /// Avancement local, partagé avec les autres écrans (`ProgressView`).
    @EnvironmentObject private var progress: ProgressStore
    /// Statut de cours des chapitres, faute de store partagé pour l'instant.
    @StateObject private var courseStatus = TrainCourseStatusStore()

    /// Chargement du manifeste de contenu (`GET /content/manifest.json`).
    @State private var state: LoadState = .idle
    @State private var manifestError: String?
    /// Descripteur de banque servie, par identifiant de chapitre.
    @State private var descriptors: [String: DuelloAPI.ContentChapterDescriptor] = [:]

    /// Chapitres dépliés.
    @State private var expanded: Set<String> = []
    /// État de chargement des exercices, par identifiant de chapitre.
    @State private var chapterStates: [String: LoadState] = [:]
    @State private var chapterErrors: [String: String] = [:]
    /// Exercices chargés, par identifiant de chapitre.
    @State private var loadedExercises: [String: [TrainExercise]] = [:]
    /// Filtre de difficulté, par identifiant de chapitre ; absence = « Tout ».
    @State private var difficultyFilters: [String: Int] = [:]

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                subjectHeader
                content
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 36)
        }
        .background(Theme.background)
        .navigationTitle(subject.name)
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadManifest() }
    }

    // MARK: En-tête de matière

    /// En-tête d'une matière ouverte : icône, nom, compteur de sujets réussis et
    /// barre d'avancement, comme `subjectHeaderContent` de `SubjectsScreen`.
    private var subjectHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 15)
                        .fill(Theme.primaryLight)
                        .frame(width: 44, height: 44)
                    Image(systemName: subject.icon)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Theme.ink)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(subject.name)
                        .font(.system(size: 16, weight: .heavy))
                        .foregroundStyle(Theme.ink)
                    Text(successHeadline)
                        .font(.system(size: 11, weight: .black))
                        .foregroundStyle(Theme.inkSoft)
                }
                Spacer(minLength: 0)
            }
            DuelloProgressTrack(fraction: successFraction, tint: Theme.progress, height: 7)
        }
        .duelloCard()
    }

    /// « 3/12 sujets réussis », ou « Aucun sujet disponible » quand le manifeste
    /// n'annonce aucun sujet pour cette matière. L'état intermédiaire d'Expo
    /// (« 12 sujets disponibles », avant relecture de la progression) n'existe
    /// pas ici : `ProgressStore` est local et toujours relu.
    private var successHeadline: String {
        let totals = subjectSuccess
        guard totals.total > 0 else { return "Aucun sujet disponible" }
        return TrainCopy.subjectSuccess(succeeded: totals.succeeded, total: totals.total)
    }

    private var successFraction: Double {
        let totals = subjectSuccess
        guard totals.total > 0 else { return 0 }
        return min(1, max(0, Double(totals.succeeded) / Double(totals.total)))
    }

    /// Sujets réussis et sujets servis de la matière, d'après les descripteurs du
    /// manifeste et l'avancement local enregistré.
    private var subjectSuccess: (succeeded: Int, total: Int) {
        let chapterIds = Set(subject.chapters.map { $0.id })
        let total = subject.chapters.reduce(0) { partial, chapter in
            partial + (descriptors[chapter.id]?.count ?? 0)
        }
        let succeeded = progress.items.keys.filter { itemId in
            guard let chapterId = TrainItemID.chapterId(of: itemId) else { return false }
            guard chapterIds.contains(chapterId) else { return false }
            return progress.items[itemId]?.bestOutcome == .success
        }.count
        return (succeeded, total)
    }

    // MARK: Corps

    @ViewBuilder
    private var content: some View {
        switch state {
        case .idle, .loading:
            loadingBlock
        case .error:
            errorBlock
        case .ready:
            if subject.chapters.isEmpty {
                DuelloEmptyState(
                    icon: "books.vertical",
                    title: "Aucun chapitre",
                    message: "Le programme de cette matière n’est pas encore disponible."
                )
                .padding(.top, 24)
            } else {
                chapterCatalogue
            }
        }
    }

    private var loadingBlock: some View {
        HStack(spacing: 10) {
            ProgressView()
            Text("Chargement…")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.inkSoft)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 40)
    }

    private var errorBlock: some View {
        VStack(spacing: 14) {
            DuelloEmptyState(
                icon: "exclamationmark.triangle",
                title: "Contenu indisponible",
                message: manifestError
            )
            Button {
                retry()
            } label: {
                Text("Réessayer")
                    .frame(maxWidth: .infinity, minHeight: 52)
            }
            .buttonStyle(DuelloPrimaryButton())
        }
        .padding(.top, 24)
    }

    /// Programme de la matière, groupé par domaine puis chapitre par chapitre.
    private var chapterCatalogue: some View {
        VStack(alignment: .leading, spacing: 0) {
            if subject.id != "maths" && subjectTotals.available > 0 {
                availabilityBanner
            }
            ForEach(TrainChapterGroup.grouped(subject.chapters)) { group in
                DuelloSectionHeader(title: group.title ?? "Autres chapitres")
                    .padding(.top, 18)
                ForEach(group.chapters) { chapter in
                    chapterBlock(chapter)
                }
            }
        }
    }

    /// Bandeau d'annonce de la matière, affiché hors mathématiques comme dans
    /// `SubjectsScreen` : « 12 exercices disponibles dans 4 chapitres · 3 avec
    /// corrigé ».
    private var availabilityBanner: some View {
        let totals = subjectTotals
        var text = "\(TrainCopy.availability(.exercise, count: totals.available)) dans \(totals.chapters) chapitre\(totals.chapters > 1 ? "s" : "")"
        if totals.withSolution > 0 {
            text += " · \(totals.withSolution) avec corrigé"
        }
        return HStack(spacing: 10) {
            Image(systemName: "books.vertical")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Theme.progress)
            Text(text)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Theme.ink)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Theme.primaryLight)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
        .padding(.top, 14)
    }

    /// Sujets servis, chapitres pourvus et corrigés disponibles de la matière.
    /// Les corrigés ne sont connus qu'après chargement d'un chapitre : le compte
    /// augmente au fil des dépliages, jamais à rebours.
    private var subjectTotals: (available: Int, chapters: Int, withSolution: Int) {
        var available = 0
        var chapters = 0
        var withSolution = 0
        for chapter in subject.chapters {
            guard let descriptor = descriptors[chapter.id] else { continue }
            available += descriptor.count
            chapters += 1
            withSolution += (loadedExercises[chapter.id] ?? []).filter { $0.hasSolution }.count
        }
        return (available, chapters, withSolution)
    }

    // MARK: Chapitre

    @ViewBuilder
    private func chapterBlock(_ chapter: TrackChapter) -> some View {
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

    // MARK: Chargement

    private func retry() {
        state = .idle
        manifestError = nil
        Task { await loadManifest() }
    }

    /// Manifeste de contenu : un seul appel pour tout le catalogue, puis un
    /// descripteur par chapitre de la matière.
    private func loadManifest() async {
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
            state = .ready
        } catch {
            manifestError = TrainErrorMessage.text(for: error)
            state = .error
        }
    }

    private func toggle(_ chapter: TrackChapter) {
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
    private func visibleExercises(_ chapter: TrackChapter) -> [TrainExercise] {
        let loaded = loadedExercises[chapter.id] ?? []
        guard let level = difficultyFilters[chapter.id] else {
            return TrainExercise.orderedByDifficulty(loaded)
        }
        return TrainExercise.orderedByDifficulty(loaded.filter { $0.difficulty == level })
    }
}

// MARK: - Ligne de chapitre

/// Une ligne de chapitre : statut du cours, nom, avancement et résumé.
/// Reprend `ChapterRow` de `SubjectsScreen.tsx` en remplaçant l'ouverture plein
/// écran par un dépliage sur place.
struct TrainChapterRow: View {
    let chapter: TrackChapter
    let status: TrainCourseStatus
    /// Résumé accordé du chapitre (« 3/12 exercices réussis »…).
    let summaryText: String
    /// Dénominateur d'avancement ; 0 masque la barre et le résumé fort.
    let progressTotal: Int
    let progressFraction: Double
    let isExpanded: Bool
    let onToggleStatus: () -> Void
    let onToggleExpanded: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onToggleStatus) {
                Image(systemName: status.icon)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(status.tint)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Statut cours — \(chapter.name)")
            .accessibilityValue(status.label)

            Button(action: onToggleExpanded) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(chapter.name)
                        .font(.system(size: 14, weight: status == .completed ? .bold : .semibold))
                        .foregroundStyle(Theme.ink)
                        .multilineTextAlignment(.leading)
                    if progressTotal > 0 {
                        DuelloProgressTrack(fraction: progressFraction, height: 6)
                    }
                    Text(summaryText)
                        .font(.system(size: 11, weight: progressTotal > 0 ? .bold : .semibold))
                        .foregroundStyle(progressTotal > 0 ? Theme.inkSoft : Theme.inkFaint)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Ouvrir les exercices — \(chapter.name)")

            Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Theme.inkFaint)
        }
        .padding(.vertical, 10)
        .padding(.trailing, 12)
    }
}

// MARK: - Fiche d'exercice

/// Une fiche d'exercice : numéro dans le chapitre, pastille de difficulté,
/// titre, marque de corrigé et avancement personnel. Reprend la fiche
/// `ExerciseItemCard` de `SubjectsScreen.tsx`.
///
/// Écart assumé : Expo masque le titre dans les listes (`showsItemTitles =
/// false`) parce que la fiche y sert de vignette de grille et que l'énoncé
/// s'ouvre ailleurs. Sans lecteur d'énoncé ici, la fiche garde le titre du sujet
/// — il vient du serveur et sert aussi de libellé d'accessibilité.
struct TrainExerciseCard: View {
    let exercise: TrainExercise
    /// Position affichée dans le chapitre (« Sujet n »).
    let number: Int
    let fraction: Double
    let hasProgress: Bool

    private var percentage: Int { Int((min(1, max(0, fraction)) * 100).rounded()) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("\(number)")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(Theme.inkSoft)
                    .accessibilityLabel("Sujet \(number)")
                if let level = exercise.difficulty, TrainDifficulty.order.contains(level) {
                    TrainDifficultyPill(level: level, showsLabel: false)
                }
                Spacer(minLength: 8)
                if exercise.hasSolution {
                    DuelloPill(text: "Corrigé", tone: .success, icon: "checkmark.circle")
                }
            }
            Text(exercise.title)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.leading)
            if hasProgress {
                HStack(spacing: 8) {
                    DuelloProgressTrack(fraction: fraction, height: 6)
                    Text("\(percentage) %")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundStyle(Theme.inkSoft)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Avancement : \(percentage) %")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .duelloCard()
    }
}

// MARK: - Difficulté

/// Paliers de difficulté servis par l'API (`DIFFICULTY_ORDER` de
/// `src/utils/itemDifficulty.ts`) et leurs libellés (`DIFFICULTY_LABELS`).
enum TrainDifficulty {
    /// Ordre de présentation : on entre dans un chapitre par le plus accessible.
    static let order: [Int] = [1, 2, 3, 4, 5, 6]

    /// Libellé d'un palier ; chaîne vide pour un palier hors barème.
    static func label(for level: Int) -> String {
        switch level {
        case 1: return "Très facile"
        case 2: return "Facile"
        case 3: return "Moyen"
        case 4: return "Difficile"
        case 5: return "Très difficile"
        case 6: return "Extrême"
        default: return ""
        }
    }
}

/// Six points, remplis jusqu'au niveau de difficulté (`DifficultyDots`).
struct TrainDifficultyDots: View {
    let level: Int

    var body: some View {
        HStack(spacing: 3) {
            ForEach(TrainDifficulty.order, id: \.self) { dot in
                Circle()
                    .fill(dot <= level ? Theme.ink : Theme.border)
                    .frame(width: 6, height: 6)
            }
        }
    }
}

/// Pastille de difficulté : les points, et le libellé quand le contexte le
/// permet (`DifficultyPill`).
struct TrainDifficultyPill: View {
    let level: Int
    var showsLabel: Bool = true

    var body: some View {
        HStack(spacing: 6) {
            TrainDifficultyDots(level: level)
            if showsLabel {
                Text(TrainDifficulty.label(for: level))
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundStyle(Theme.inkSoft)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Theme.surfaceMuted)
        .clipShape(Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Difficulté : \(TrainDifficulty.label(for: level))")
    }
}

// MARK: - Domaines de programme

/// Domaines d'un programme de mathématiques, dans l'ordre de `CHAPTER_DOMAINS`
/// (`src/data/tracks.ts`).
enum TrainDomain: String, CaseIterable {
    case fondements
    case analyse
    case algebre
    case geometrie
    case probabilites
    case synthese
    case informatique

    /// Libellé affiché (`CHAPTER_DOMAIN_LABELS`).
    var label: String {
        switch self {
        case .fondements: return "Fondements"
        case .analyse: return "Analyse"
        case .algebre: return "Algèbre"
        case .geometrie: return "Géométrie"
        case .probabilites: return "Probabilités"
        case .synthese: return "Synthèse"
        case .informatique: return "Informatique"
        }
    }
}

/// Groupe de chapitres d'un domaine. Le groupe final de `groupChaptersByDomain`
/// n'a pas de domaine : son titre de repli est « Autres chapitres ».
struct TrainChapterGroup: Identifiable {
    let domain: TrainDomain?
    let chapters: [TrackChapter]

    var id: String { domain?.rawValue ?? "sans-domaine" }

    /// Titre affiché ; `nil` pour le groupe sans domaine, que le rendu coiffe
    /// de « Autres chapitres ».
    var title: String? { domain?.label }

    /// Port de `groupChaptersByDomain` : domaines connus dans l'ordre du
    /// programme, puis un groupe sans domaine pour les chapitres restants.
    static func grouped(_ chapters: [TrackChapter]) -> [TrainChapterGroup] {
        var groups: [TrainChapterGroup] = TrainDomain.allCases.compactMap { domain -> TrainChapterGroup? in
            let matching = chapters.filter { $0.domain == domain.rawValue }
            return matching.isEmpty ? nil : TrainChapterGroup(domain: domain, chapters: matching)
        }
        let others = chapters.filter { chapter in
            guard let domain = chapter.domain else { return true }
            return TrainDomain(rawValue: domain) == nil
        }
        if !others.isEmpty {
            groups.append(TrainChapterGroup(domain: nil, chapters: others))
        }
        return groups
    }
}

// MARK: - Sujets et avancement

/// Nature du sujet, qui décide de l'accord des libellés (`getItemLabel`,
/// `availabilityLabel`, `successLabel` de `SubjectsScreen.tsx`).
enum TrainExerciseKind {
    case exercise
    case colle
    case dissertation

    /// Nom au singulier.
    var singular: String {
        switch self {
        case .exercise: return "exercice"
        case .colle: return "colle"
        case .dissertation: return "dissertation"
        }
    }

    /// Colles et dissertations sont féminines dans les libellés accordés.
    var isFeminine: Bool { self != .exercise }

    /// Nom accordé au nombre annoncé.
    func noun(count: Int) -> String { count > 1 ? singular + "s" : singular }
}

/// Un exercice servi par l'API, avec l'identifiant d'item utilisé par
/// l'avancement local.
struct TrainExercise: Identifiable, Hashable {
    let key: String
    let chapterId: String
    let title: String
    let difficulty: Int?
    let solution: String?

    /// Identifiant d'item `chapitre::exercice::clé` (`servedBank.ts`), la clé
    /// sous laquelle `ProgressStore` enregistre une tentative.
    var id: String { TrainItemID.make(chapterId: chapterId, key: key) }

    /// Le serveur laisse le corrigé absent tant que la relecture n'a pas eu lieu.
    var hasSolution: Bool {
        !(solution ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    init(seed: DuelloAPI.ChapterExercise) {
        key = seed.key
        chapterId = seed.chapterId
        title = seed.title
        difficulty = seed.difficulty
        solution = seed.solution
    }

    /// Port de `groupItemsByDifficulty` : on entre dans un chapitre par le plus
    /// accessible, l'ordre de la banque étant conservé à l'intérieur d'un
    /// palier. Un palier absent de `DIFFICULTY_ORDER` ferme la marche au lieu
    /// d'être perdu, le contenu servi n'étant pas garanti sur les six niveaux.
    static func orderedByDifficulty(_ items: [TrainExercise]) -> [TrainExercise] {
        let known = TrainDifficulty.order.flatMap { level in
            items.filter { $0.difficulty == level }
        }
        let unknown = items.filter { item in
            guard let difficulty = item.difficulty else { return true }
            return !TrainDifficulty.order.contains(difficulty)
        }
        return known + unknown
    }
}

/// Avancement d'un chapitre dans le mode ouvert (`ChapterModeSummary`) : seuls
/// les sujets réellement servis entrent dans le dénominateur.
struct TrainChapterSummary: Equatable {
    /// Sujets servis pour ce chapitre.
    var available: Int = 0
    /// Sujets connus du catalogue mais pas encore chargés sur l'appareil.
    var catalogued: Int? = nil
    /// Sujets disposant d'un corrigé.
    var withSolution: Int = 0
    /// Sujets entièrement réussis : c'est ce que la barre du chapitre remplit.
    var succeeded: Int = 0

    /// Dénominateur d'avancement (`chapterModeProgressTotal`) : les colles
    /// comptent aussi les sujets seulement catalogués.
    func progressTotal(kind: TrainExerciseKind) -> Int {
        kind == .colle ? max(available, catalogued ?? 0) : available
    }
}

/// Identifiant d'item partagé avec `ProgressStore` : `chapitre::exercice::clé`.
enum TrainItemID {
    static func make(chapterId: String, key: String) -> String {
        "\(chapterId)::exercice::\(key)"
    }

    /// Chapitre d'un identifiant d'item ; `nil` si la forme est inattendue.
    static func chapterId(of itemId: String) -> String? {
        guard let separator = itemId.range(of: "::") else { return nil }
        let chapter = String(itemId[itemId.startIndex..<separator.lowerBound])
        return chapter.isEmpty ? nil : chapter
    }
}

// MARK: - Libellés accordés

/// Libellés accordés du catalogue, repris mot pour mot de `SubjectsScreen.tsx`.
enum TrainCopy {
    /// « 12 exercices disponibles », « 3 colles disponibles ».
    static func availability(_ kind: TrainExerciseKind, count: Int) -> String {
        let feminine = kind.isFeminine ? "e" : ""
        let plural = count > 1 ? "s" : ""
        return "\(count) \(kind.noun(count: count)) disponible\(feminine)\(plural)"
    }

    /// « 0/32 exercices réussis », « 1/8 colles réussies » : le pluriel suit le
    /// nombre total annoncé par le dénominateur.
    static func success(
        _ kind: TrainExerciseKind,
        succeeded: Int,
        available: Int,
        withNoun: Bool = true
    ) -> String {
        let plural = available > 1 ? "s" : ""
        let noun = withNoun ? "\(kind.noun(count: available)) " : ""
        let feminine = kind.isFeminine ? "e" : ""
        return "\(succeeded)/\(available) \(noun)réussi\(feminine)\(plural)"
    }

    /// « 3/12 sujets réussis », en-tête d'une matière.
    static func subjectSuccess(succeeded: Int, total: Int) -> String {
        "\(succeeded)/\(total) sujets réussis"
    }

    /// « 3 corrigés » du résumé de chapitre.
    static func solutions(count: Int) -> String {
        "\(count) corrigé\(count > 1 ? "s" : "")"
    }
}

// MARK: - Statut de cours

/// Statut du cours d'un chapitre (`Chapter['courseStatus']`), dans l'ordre du
/// cycle d'appui : à venir → en cours → vu → à venir.
enum TrainCourseStatus: String, CaseIterable {
    case notStarted = "not-started"
    case inProgress = "in-progress"
    case completed = "completed"

    /// Libellé affiché (`COURSE_STATUS_LABELS`).
    var label: String {
        switch self {
        case .notStarted: return "À venir"
        case .inProgress: return "En cours"
        case .completed: return "Vu"
        }
    }

    /// Icône du rond de statut (`COURSE_STATUS_ICONS`, transposée en SF Symbols).
    var icon: String {
        switch self {
        case .notStarted: return "circle"
        case .inProgress: return "clock"
        case .completed: return "checkmark.circle"
        }
    }

    /// Couleur du rond de statut (`COURSE_STATUS_COLORS`).
    var tint: Color {
        switch self {
        case .notStarted: return Theme.inkFaint
        case .inProgress: return Theme.inkSoft
        case .completed: return Theme.progress
        }
    }

    /// Statut suivant du cycle (`toggleCourseStatus`).
    var next: TrainCourseStatus {
        switch self {
        case .notStarted: return .inProgress
        case .inProgress: return .completed
        case .completed: return .notStarted
        }
    }
}

/// Statut de cours des chapitres, persisté localement.
///
/// L'écran Expo range `courseStatus` dans la progression de matière ; le port
/// n'a pas encore de store partagé pour ce champ. En attendant, ce store local
/// tient la même information, dans un JSON séparé, sous la même convention de
/// persistance que `SessionStore` et `ProgressStore`.
final class TrainCourseStatusStore: ObservableObject {
    @Published private(set) var statuses: [String: String] = [:]

    private static let storageKey = "com.duello.ios.training.course-status"

    init() {
        restore()
    }

    /// Statut d'un chapitre ; « À venir » tant qu'il n'a jamais été touché.
    func status(for chapterId: String) -> TrainCourseStatus {
        guard let raw = statuses[chapterId], let status = TrainCourseStatus(rawValue: raw) else {
            return .notStarted
        }
        return status
    }

    /// Fait avancer un chapitre d'un cran dans le cycle des statuts.
    func cycle(_ chapterId: String) {
        guard !chapterId.isEmpty else { return }
        statuses[chapterId] = status(for: chapterId).next.rawValue
        persist()
    }

    private func restore() {
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey),
              let stored = try? JSONDecoder().decode([String: String].self, from: data)
        else { return }
        statuses = stored.filter { !$0.key.isEmpty && TrainCourseStatus(rawValue: $0.value) != nil }
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(statuses) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }
}

// MARK: - Contenu servi

/// Résolution des banques servies pour la matière affichée.
///
/// Port de `src/content/contentStartup.ts` : l'ordre des banques du profil
/// décide quel descripteur de chapitre retenir quand plusieurs banques servent
/// le même chapitre (1re et 2e année, colles, annales). La matière et l'option
/// viennent du profil, la même source que `DuelloProgram.subjects`.
private enum TrainContent {
    /// Retire les accents et la casse, comme `DuelloProgram.normalize`.
    static func normalize(_ value: String) -> String {
        value.folding(options: .diacriticInsensitive, locale: Locale(identifier: "fr_FR"))
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Année de programme du profil : tout libellé contenant « 2 » vaut 2.
    static func programYear(from year: String) -> Int {
        year.lowercased().contains("2") ? 2 : 1
    }

    /// Banques du programme de l'élève, année affichée en tête
    /// (`profileBundleIds`). Le lycée n'a pas de banque servie.
    static func profileBundleIds(track: String, specialty: String, year: Int) -> [String] {
        let normalizedTrack = normalize(track)
        if normalizedTrack.contains("lycee") { return [] }

        if normalizedTrack.contains("mpsi") {
            let first = ["mpsi-statements", "colles-mpsi-1"]
            let second = ["mp-statements"]
            return year == 2 ? second + first : first + second
        }

        guard normalizedTrack.contains("ecg") else { return [] }

        if normalize(specialty).contains("applique") {
            let first = [
                "ecg-applied-1-statements",
                "colles-ecg-appliquees-1",
                "ecg-applied-annales-year-1",
            ]
            let second = [
                "ecg-applied-2-statements",
                "colles-ecg-appliquees-2",
                "ecg-applied-annales-2025",
                "ecg-applied-annales-2024",
                "ecg-applied-annales-legendre",
            ]
            return (year == 2 ? second + first : first + second) + ["oral-drive-exercises"]
        }

        let first = [
            "ecg-advanced-1-statements",
            "colles-ecg-approfondies-1",
            "ecg-advanced-annales-1",
            "ecg-advanced-annales-1-kleber",
        ]
        let second = [
            "ecg-advanced-2-statements",
            "colles-ecg-approfondies-2",
            "ecg-advanced-annales-2",
            "ecg-advanced-annales-2-drive",
            "ecg-advanced-maths-i-annales",
            "ecg-advanced-maths-ii-annales",
        ]
        return (year == 2 ? second + first : first + second) + ["oral-drive-exercises"]
    }

    /// Banques d'énoncés de l'année affichée, la première portant le corpus
    /// principal (`exerciseContentBundleIds`).
    static func exerciseBundleIds(track: String, specialty: String, year: Int) -> [String] {
        let normalizedTrack = normalize(track)
        if normalizedTrack.contains("mpsi") {
            return [year == 2 ? "mp-statements" : "mpsi-statements"]
        }
        let profile = profileBundleIds(track: track, specialty: specialty, year: year)
        let marker = year == 2 ? "-2-" : "-1-"
        return profile.filter { $0.contains(marker) && $0.hasSuffix("-statements") }
    }

    /// Descripteur retenu par identifiant de chapitre. Quand plusieurs banques
    /// servent le même chapitre, la plus prioritaire pour le profil gagne ; à
    /// priorité égale, la première du manifeste est conservée.
    static func chapterIndex(
        manifest: DuelloAPI.ContentManifest,
        track: String,
        specialty: String,
        year: String
    ) -> [String: DuelloAPI.ContentChapterDescriptor] {
        let order = exerciseBundleIds(
            track: track,
            specialty: specialty,
            year: programYear(from: year)
        )
        var best: [String: (rank: Int, descriptor: DuelloAPI.ContentChapterDescriptor)] = [:]
        for descriptor in manifest.chapters ?? [] {
            let rank = order.firstIndex(of: descriptor.bundleId) ?? order.count
            if let current = best[descriptor.chapterId], current.rank <= rank { continue }
            best[descriptor.chapterId] = (rank, descriptor)
        }
        return best.mapValues { $0.descriptor }
    }
}

// MARK: - Erreurs

/// Message affiché pour une erreur du client Duello.
private enum TrainErrorMessage {
    /// Message localisé du client quand il en porte un, repli sinon.
    static func text(for error: Error) -> String {
        if let localized = error as? LocalizedError,
           let description = localized.errorDescription,
           !description.isEmpty {
            return description
        }
        return "Le contenu Duello est injoignable."
    }
}
