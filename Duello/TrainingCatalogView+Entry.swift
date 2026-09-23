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

    /// Chapitres dépliés.
    @State var expanded: Set<String> = []
    /// État de chargement des exercices, par identifiant de chapitre.
    @State var chapterStates: [String: LoadState] = [:]
    @State var chapterErrors: [String: String] = [:]
    /// Exercices chargés, par identifiant de chapitre.
    @State var loadedExercises: [String: [TrainExercise]] = [:]
    /// Filtre de difficulté, par identifiant de chapitre ; absence = « Tout ».
    @State var difficultyFilters: [String: Int] = [:]

    /// Mode d'entraînement choisi par l'élève ; `nil` tant qu'il n'a pas touché
    /// aux onglets, le mode par défaut de la matière s'appliquant alors.
    @State var modeOverride: SubjTrainingMode? = nil
    /// Filtre « Classique » du chapitre ouvert. Interface seule : la banque
    /// servie ne porte pas la marque « Classique ».
    @State var classicFilter: SubjClassicFilterValue = .all
    /// Visibilité de la légende du statut de cours — encart explicatif **et**
    /// rappel statique — persistée par compte, comme
    /// `useCourseLegendVisibility` de la source.
    @StateObject var legendStore = TrainCourseLegendStore()
    /// Sujet de reprise masqué à la main, par identifiant d'item
    /// (`dismissedResumableExerciseId`).
    @State var dismissedResumableExerciseId: String? = nil
    /// Feuille « Cartes » (flashcards) du sujet.
    @State var flashcardsOpen = false
    /// Classement XP ouvert depuis la barre de métriques (maths).
    @State var rankingOpen = false
    /// Décompte du catalogue par chapitre : exercices servis, colles et annales
    /// réunis (voir `TrainContent.catalogCounts`), dénominateur de l'en-tête.
    @State var catalogTotals: [String: Int] = [:]

    /// Repli de la page d'une matière vers la liste des matières.
    @Environment(\.dismiss) private var dismiss

    var body: some View {
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
        }
        .background(Theme.background)
        // L'en-tête de la source ne défile pas : la barre de métriques (maths)
        // et la barre de retour (autres matières) vivent dans le chrome collant,
        // hors du `ScrollView` (`SubjectsScreen.tsx:9611-9655`). En maths, les
        // onglets de modes y prennent place sous la barre, `paddingTop: 4`
        // (`mathsModeTabsRow`, `SubjectsScreen.tsx:9779-9785`).
        .safeAreaInset(edge: .top, spacing: 0) { pinnedHeader }
        // La source n'a pas de titre de navigation : la page d'une matière est
        // coiffée par son propre en-tête (barre de métriques en maths, barre de
        // retour ailleurs).
        .navigationBarTitleDisplayMode(.inline)
        // Écart assumé : la source ouvre les cartes d'un cours **depuis le
        // cours lui-même** (`coursePage === 'flashcards'`,
        // `SubjectsScreen.tsx:8064`) ; cet écran-là n'étant pas porté, la barre
        // de navigation reste la seule entrée vers `TrainIntFlashcardsSection`
        // — la retirer laisserait la surface « Cartes du cours » injoignable.
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    flashcardsOpen = true
                } label: {
                    Image(systemName: "rectangle.on.rectangle.angled")
                }
                .accessibilityLabel("Ouvrir les cartes du cours")
            }
        }
        .sheet(isPresented: $flashcardsOpen) { flashcardsSheet }
        .sheet(isPresented: $rankingOpen) { LeaderboardModalView() }
        .task { await loadManifest() }
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

    /// Feuille des cartes du cours (`CourseFlashcardsPanel`), présentée depuis
    /// la barre de navigation pour ne pas alourdir la liste des chapitres.
    private var flashcardsSheet: some View {
        NavigationStack {
            ScrollView {
                TrainIntFlashcardsSection(
                    subjectName: subject.name,
                    chapterId: subject.chapters.first?.id ?? subject.id,
                    chapterName: subject.chapters.first?.name ?? subject.name
                )
            }
            .background(Theme.background)
            .navigationTitle("Cartes")
            .navigationBarTitleDisplayMode(.inline)
        }
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

    /// Reprend un sujet : ouvre son mode et déplie son chapitre, faute de
    /// lecteur d'énoncé porté dans cet écran (`isOpenable: false`).
    private func resume(_ resumable: TrainResumableExercise) {
        modeOverride = resumable.mode
        guard let chapterId = resumable.chapterId,
              let chapter = subject.chapters.first(where: { $0.id == chapterId }),
              !expanded.contains(chapterId)
        else { return }
        toggle(chapter)
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
