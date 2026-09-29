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
///
/// Découpage (règles de complexité Duello : ≤ 500 lignes et ≤ 10 `func` par
/// fichier) : ce fichier porte l'état, le corps et l'en-tête de matière ; le
/// catalogue vit dans `TrainingCatalogView+Content.swift`, le détail d'un
/// chapitre dans `TrainingCatalogView+Chapter.swift` et le chargement dans
/// `TrainingCatalogView+Loading.swift`. Les membres appelés depuis un autre
/// fichier du découpage sont `internal` ; ceux d'un seul fichier restent
/// `private`.

// MARK: - Point d'entrée

/// Catalogue d'une matière : liste des chapitres de son programme, chaque
/// chapitre dépliable vers ses exercices chargés par
/// `DuelloAPI.chapterExercises(_:)`.
struct TrainingCatalogView: View {
    /// Matière dont on affiche le programme.
    let subject: TrackSubject

    /// Année du programme affichée par le sélecteur de l'en-tête, et année du
    /// compte (marquée « actuelle »). `nil` hors de l'onglet Entraînement —
    /// repli ouvert depuis la liste des matières.
    var programYear: Int? = nil
    var profileYear: Int? = nil
    var onSelectYear: ((Int) -> Void)? = nil

    @EnvironmentObject var session: SessionStore
    /// Avancement local, partagé avec les autres écrans (`ProgressView`).
    @EnvironmentObject var progress: ProgressStore
    /// Statut de cours des chapitres, faute de store partagé pour l'instant.
    @StateObject var courseStatus = TrainCourseStatusStore()

    /// Chargement du manifeste de contenu (`GET /content/manifest.json`).
    @State var state: LoadState = .idle
    @State var manifestError: String?
    /// Descripteur de banque servie, par identifiant de chapitre.
    @State var descriptors: [String: DuelloAPI.ContentChapterDescriptor] = [:]

    /// Chapitre ouvert en plein écran (`openChapter` de la source) : la page du
    /// chapitre remplace le programme de la matière, `nil` affiche le catalogue.
    @State var openChapter: TrackChapter? = nil
    /// État de chargement des exercices, par identifiant de chapitre.
    @State var chapterStates: [String: LoadState] = [:]
    @State var chapterErrors: [String: String] = [:]
    /// Exercices chargés, par identifiant de chapitre.
    @State var loadedExercises: [String: [TrainExercise]] = [:]
    /// Filtre de difficulté, par identifiant de chapitre : multi-choix des
    /// paliers (`badgeFilters` de la source) ; ensemble vide = « Tout ».
    @State var difficultyFilters: [String: Set<Int>] = [:]
    /// Filtre de prérequis, par identifiant de chapitre (multi-choix) ;
    /// ensemble vide = « Tout ».
    @State var prerequisiteFilters: [String: Set<SubjPrerequisiteFilterValue>] = [:]

    /// Mode d'entraînement choisi par l'élève ; `nil` tant qu'il n'a pas touché
    /// aux onglets, le mode par défaut de la matière s'appliquant alors.
    @State var modeOverride: SubjTrainingMode? = nil
    /// Visibilité de la légende du statut de cours — encart explicatif **et**
    /// rappel statique — persistée par compte, comme
    /// `useCourseLegendVisibility` de la source.
    @StateObject var legendStore = TrainCourseLegendStore()
    /// Sujet de reprise masqué à la main, par identifiant d'item
    /// (`dismissedResumableExerciseId`).
    @State var dismissedResumableExerciseId: String? = nil
    /// Classement XP ouvert depuis la barre de métriques (maths).
    @State var rankingOpen = false
    /// Décompte du catalogue par chapitre : exercices servis, colles et annales
    /// réunis (voir `TrainContent.catalogCounts`), dénominateur de l'en-tête.
    @State var catalogTotals: [String: Int] = [:]
    /// Énoncé ouvert en plein écran (`openAnnale` de la source).
    @State var readerEntry: AnnEntry? = nil
    /// Repère de cours par chapitre (`coursePositionsByKey`) : alimente la barre
    /// des lignes Cours.
    @State var coursePositions: [String: Double] = [:]
    /// Chapitres pourvus d'un document de cours (`courseDocumentsByKey`).
    @State var courseDocuments: [String: Bool] = [:]

    /// Repli de la page d'une matière vers la liste des matières.
    @Environment(\.dismiss) private var dismiss

    /// Visibilité du chrome repliable (barre de métriques des maths) pendant le
    /// défilement (`useScrollChromeVisibility`), et ancre de la session en cours.
    @State private var chromeVisible = true
    @State private var chromeSession: TrainChromeSession?

    /// Manifeste servi, conservé pour ré-indexer au changement d'onglet sans
    /// nouvel appel (`chapterCardCatalog` / `colleCardCatalog`).
    @State var manifest: DuelloAPI.ContentManifest?
    /// Banque d'annales servie de la matière (`annaleItems`,
    /// `SubjectsScreen.tsx:4493`), chargée à l'ouverture de l'onglet Annales.
    @State var annaleItems: [AnnEntry] = []
    /// Mémoire du défilement du catalogue (`chapterListScrollOffsetRef`) :
    /// offset publié au défilement, replacement au retour d'un chapitre.
    @ObservedObject var scrollMemory = TrainCatalogueScrollMemory.shared

    var body: some View {
        Group {
            if let openChapter {
                chapterDetailPage(openChapter)
            } else {
                cataloguePage
            }
        }
        .background(Theme.background)
        .navigationBarTitleDisplayMode(.inline)
        // `onOpenProfile` (`SubjectsScreen.tsx:8555-8560`) : le tap d'une ligne
        // du classement ouvre la fiche publique du membre via le coordinateur
        // racine — même couture que le tap de notification.
        .sheet(isPresented: $rankingOpen) {
            LeaderboardModalView(initialTab: .weeklyXp, xpOnly: true, onOpenProfile: { memberId in
                Task { @MainActor in
                    PushNotifRootCoordinator.shared.pendingMember =
                        PushNotifPendingMember(id: memberId)
                }
            })
        }
        .fullScreenCover(item: $readerEntry) { entry in readerCover(entry) }
        .task { await loadManifest() }
        // Ré-indexation au changement d'onglet (`colleCardCatalog` /
        // `chapterCardCatalog`) : la banque servie dépend du mode ouvert.
        .onChange(of: activeMode) { _ in reindexChapters() }
    }

    /// Programme de la matière : le catalogue de chapitres, coiffé du chrome
    /// collant (barre de métriques en maths, barre de retour ailleurs).
    private var cataloguePage: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    resumableExerciseCard
                    // Les onglets d'une matière non-maths restent dans le contenu et
                    // s'affichent dès l'ouverture de la page, avant le chargement du
                    // manifeste (`renderModeTabs`, `SubjectsScreen.tsx:10006`).
                    if subject.id != SubjSubjectRules.mathsSubjectId {
                        modeTabsRow.padding(.top, 12)
                    }
                    content
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 40)
                .background(chromeOffsetReader)
            }
            .coordinateSpace(name: Self.scrollSpace)
            .onPreferenceChange(TrainChromeOffsetKey.self) { offset in
                handleChromeScroll(offset)
            }
            // L'en-tête de la source ne défile pas : la barre de métriques (maths)
            // et la barre de retour (autres matières) vivent dans le chrome collant,
            // hors du `ScrollView` (`SubjectsScreen.tsx:9611-9655`). En maths, les
            // onglets de modes y prennent place sous la barre, `paddingTop: 4`
            // (`mathsModeTabsRow`, `SubjectsScreen.tsx:9779-9785`).
            //
            // U06#A1 : en maths, le chrome se replie au défilement vers le bas et
            // revient au défilement vers le haut (ressort `friction 26 / tension 60`,
            // translation `-24`, opacité ; `9648-9823`).
            .safeAreaInset(edge: .top, spacing: 0) {
                pinnedHeader
                    .opacity(chromeVisible ? 1 : 0)
                    .offset(y: chromeVisible ? 0 : -24)
                    .animation(.interpolatingSpring(stiffness: 60, damping: 26), value: chromeVisible)
                    .accessibilityHidden(!chromeVisible)
            }
            // Replacement au retour d'un chapitre (`recentlyClosedChapter`,
            // `SubjectsScreen.tsx:4085-4100`) : le catalogue revient sur la ligne
            // du chapitre quitté, sans animation.
            .onAppear { applyScrollRestore(proxy) }
            .onChange(of: scrollMemory.restore) { _ in applyScrollRestore(proxy) }
        }
        // La source n'a pas de titre de navigation : la page d'une matière est
        // coiffée par son propre en-tête (barre de métriques en maths, barre de
        // retour ailleurs).
    }

    /// Applique le replacement mémorisé au retour d'un chapitre : le catalogue
    /// revient sur la ligne quittée (`ScrollViewReader.scrollTo`). La mémoire est
    /// consommée (remise à `nil`) ; un retour pour une autre matière est ignoré.
    private func applyScrollRestore(_ proxy: ScrollViewProxy) {
        guard let restore = scrollMemory.restore, restore.subjectId == subject.id else { return }
        scrollMemory.restore = nil
        // Laisse la liste se poser avant de viser la ligne : la cible d'un
        // `LazyVStack` n'existe qu'une fois la mise en page faite.
        DispatchQueue.main.async {
            withAnimation(nil) { proxy.scrollTo(restore.chapterId, anchor: .top) }
        }
    }

    /// Espace de coordonnées du défilement, pour mesurer l'offset du contenu.
    static let scrollSpace = "training-catalogue-scroll"

    /// Sonde d'offset du défilement (fond transparent en tête de contenu).
    private var chromeOffsetReader: some View {
        GeometryReader { geometry in
            Color.clear.preference(
                key: TrainChromeOffsetKey.self,
                value: -geometry.frame(in: .named(Self.scrollSpace)).minY
            )
        }
    }

    /// Suit la direction du défilement et décide de la visibilité du chrome
    /// (`scrollChromeVisibilitySessionAfterScroll`). Seules les maths replient
    /// leur chrome (`hasCollapsibleTrainingChrome`).
    private func handleChromeScroll(_ offset: CGFloat) {
        // Publication de l'offset courant (`chapterListScrollOffsetRef`) : figé à
        // l'ouverture d'un chapitre, rendu au retour. Vaut pour toutes les
        // matières, seules les maths replient leur chrome.
        scrollMemory.offset = max(0, offset)
        guard subject.id == SubjSubjectRules.mathsSubjectId else { return }
        let session = chromeSession ?? TrainChromeVisibility.beginSession(
            visible: chromeVisible, offset: offset
        )
        let next = TrainChromeVisibility.sessionAfterScroll(session, next: offset)
        chromeSession = next
        if next.visible != chromeVisible { chromeVisible = next.visible }
    }

    /// En-tête épinglé, hors du défilement : la barre de métriques des maths
    /// (avec les onglets de modes juste dessous), ou la barre de retour des
    /// autres matières. `SubjectsScreen.tsx:9619-9687` branche le chrome sur
    /// `openedSubject.id === 'maths'`.
    private var pinnedHeader: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerBlock
            if subject.id == SubjSubjectRules.mathsSubjectId {
                modeTabsRow.padding(.top, 4)
            }
        }
        .padding(.horizontal, subject.id == SubjSubjectRules.mathsSubjectId ? 20 : 16)
        .background(Theme.background)
        .overlay(alignment: .bottom) {
            // L'en-tête d'une matière non-maths est séparé du contenu par un
            // filet (`detailHeader` de la source) ; celui des maths n'en a pas.
            if subject.id != SubjSubjectRules.mathsSubjectId {
                Rectangle().fill(Theme.border).frame(height: 1)
            }
        }
    }

    /// En-tête de la page : en maths, la barre de métriques de la source
    /// (année du programme, avancement, classement XP) ; ailleurs, la barre de
    /// retour. `SubjectsScreen.tsx:9619-9687` branche la barre sur
    /// `openedSubject.id === 'maths'`.
    @ViewBuilder var headerBlock: some View {
        if subject.id == "maths", let programYear, let profileYear {
            SubjTrainingMetricsBar(
                programYear: programYear,
                profileYear: profileYear,
                succeeded: subjectSuccess.succeeded,
                total: subjectSuccess.total,
                onSelectYear: { onSelectYear?($0) },
                onOpenRanking: { rankingOpen = true }
            )
        } else {
            subjectHeader
        }
    }

    /// Relit le repère et la présence du document de **tous** les chapitres du
    /// programme (`coursePositionsByKey` / `courseDocumentsByKey`), comme la
    /// source au chargement (`SubjectsScreen.tsx:4826-4883`).
    func loadCourseMarkers() {
        for chapter in subject.chapters {
            refreshCourseMarkers(for: chapter.id)
        }
    }

    /// Relit le repère et la présence du document d'un chapitre (barre Cours).
    func refreshCourseMarkers(for chapterId: String) {
        let stored = TrainCourseDocument.load(year: programYear ?? 1, chapterId: chapterId)
        coursePositions[chapterId] = stored?.classProgress?.position
        courseDocuments[chapterId] = stored == nil ? nil : true
    }

    /// Lecteur d'énoncé plein écran (`AnnaleViewer`, `9156`) : ouvert par les
    /// fiches (`onOpenSubject` → `openTrainingItemInstantly`).
    private func readerCover(_ entry: AnnEntry) -> some View {
        NavigationStack {
            AnnReaderView(
                entry: entry,
                subject: subject.name,
                track: session.profile.track,
                specialty: session.profile.specialty,
                monitor: AnnCorrectionMonitor(),
                onClose: { readerEntry = nil }
            )
            .environmentObject(session)
            .environmentObject(progress)
        }
        .onDisappear { readerEntry = nil }
    }

    // MARK: En-tête de matière

    /// En-tête d'une matière ouverte **hors mathématiques** : barre de retour,
    /// compteur accordé au mode ouvert et piste neutre, puis l'accès au
    /// classement — **sans** nom ni icône de matière (`detailHeader` de
    /// `SubjectsScreen`, branche `openedSubject.id !== 'maths'`).
    private var subjectHeader: some View {
        HStack(spacing: 8) {
            backButton
            VStack(alignment: .leading, spacing: 0) {
                Text(successHeadline)
                    .font(.system(size: 11, weight: .black))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                subjectProgressTrack
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            rankingButton
        }
        .padding(.vertical, 8)
    }

    /// Barre de retour de la page d'une matière (`styles.backButton`) : carré de
    /// 40 points bordé, chevron vers la liste des matières.
    private var backButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "chevron.left")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .frame(width: 40, height: 40)
                .background(Theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Revenir à Mathématiques")
    }

    /// Piste d'avancement de la matière : fond blanc bordé, remplissage neutre
    /// `#D8D8D8` (`PROGRESS_FILL_COLORS.current`), hauteur 7
    /// (`subjectProgressTrack` / `subjectProgressFill`).
    private var subjectProgressTrack: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3.5).fill(Theme.surface)
                RoundedRectangle(cornerRadius: 3.5)
                    .fill(Color(hex: 0xD8D8D8))
                    .frame(width: neutralFillWidth(in: geometry.size.width))
            }
        }
        .frame(height: 7)
        .overlay(
            RoundedRectangle(cornerRadius: 3.5).stroke(Theme.border, lineWidth: 1)
        )
        .padding(.top, 7)
    }

    /// Largeur du remplissage neutre : la part réussie, avec un départ visible
    /// de 8 points dès la première réussite (`subjectProgressFill`).
    private func neutralFillWidth(in available: CGFloat) -> CGFloat {
        let totals = subjectSuccess
        guard totals.total > 0, totals.succeeded > 0 else { return 0 }
        let fraction = min(1, max(0, Double(totals.succeeded) / Double(totals.total)))
        return max(8, available * CGFloat(fraction))
    }

    /// Accès au classement de la matière, à droite de sa barre d'avancement
    /// (`rankingButton`, icône `trophy-outline`).
    private var rankingButton: some View {
        Button {
            rankingOpen = true
        } label: {
            Image(systemName: "trophy")
                .font(.system(size: 21))
                .foregroundStyle(Theme.ink)
                .frame(width: 40, height: 40)
                .background(Theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Ouvrir le classement de \(subject.name)")
    }

    // MARK: Reprise du dernier sujet

    /// Carte « Reprendre le dernier exercice », en tête du contenu des maths
    /// (`resumableExerciseCard`, rendue en tête du `ScrollView`).
    @ViewBuilder
    private var resumableExerciseCard: some View {
        if let resumable = resumableExercise,
           resumable.itemId != dismissedResumableExerciseId {
            TrainResumeCard(
                onResume: { resume(resumable) },
                onDismiss: { dismissedResumableExerciseId = resumable.itemId }
            )
        }
    }

    /// Reprend un sujet : ouvre son mode et son chapitre, puis ouvre l'énoncé
    /// du sujet repris quand il est chargé (`openAnnaleItem`).
    private func resume(_ resumable: TrainResumableExercise) {
        modeOverride = resumable.mode
        // Le mode repris change la banque servie : ré-indexer tout de suite pour
        // que le chapitre charge les sujets du bon mode (`chapterCardCatalog` /
        // `colleCardCatalog`), avant le chargement déclenché ci-dessous.
        reindexChapters()
        guard let chapterId = resumable.chapterId,
              let chapter = subject.chapters.first(where: { $0.id == chapterId })
        else { return }
        openChapter = chapter
        Task {
            await loadExercisesIfNeeded(for: chapter)
            if let exercise = (loadedExercises[chapterId] ?? []).first(where: { $0.id == resumable.itemId }) {
                readerEntry = TrainReaderLink.entry(
                    exercise,
                    mode: resumable.mode,
                    chapterName: chapter.name
                )
            }
        }
    }

    // MARK: Compteurs

    /// Compteur de l'en-tête d'une matière : accordé au mode ouvert
    /// (`modeSuccessLabel`), ou « Aucun sujet disponible » quand le catalogue
    /// n'annonce aucun sujet.
    private var successHeadline: String {
        let totals = subjectSuccess
        guard totals.total > 0 else { return "Aucun sujet disponible" }
        return SubjModeCopy.modeSuccess(activeMode, succeeded: totals.succeeded, total: totals.total)
    }

    /// Sujets réussis et sujets servis de la matière. Le total couvre les
    /// exercices servis, les colles **et** les annales (`buildSubjectSuccessSummaries`
    /// de `src/utils/subjectSuccess.ts`) ; la réussite se lit dans l'avancement
    /// local, toutes natures de sujets confondues.
    private var subjectSuccess: (succeeded: Int, total: Int) {
        let chapterIds = Set(subject.chapters.map { $0.id })
        let total = subject.chapters.reduce(0) { partial, chapter in
            partial + (catalogTotals[chapter.id] ?? descriptors[chapter.id]?.count ?? 0)
        }
        let succeeded = progress.items.keys.filter { itemId in
            guard let chapterId = TrainItemID.chapterId(of: itemId) else { return false }
            guard chapterIds.contains(chapterId) else { return false }
            return progress.items[itemId]?.bestOutcome == .success
        }.count
        return (succeeded, total)
    }
}
