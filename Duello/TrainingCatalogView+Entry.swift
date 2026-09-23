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
    /// Encart explicatif du statut de cours, montré une fois en tête de matière.
    @State var legendHintVisible = true
    /// Feuille « Cartes » (flashcards) du sujet.
    @State var flashcardsOpen = false
    /// Classement XP ouvert depuis la barre de métriques (maths).
    @State var rankingOpen = false

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                headerBlock
                content
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 36)
        }
        .background(Theme.background)
        // La source n'a pas de titre de navigation : la page d'une matière est
        // coiffée par son propre en-tête (barre de métriques en maths, carte de
        // matière ailleurs).
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

    /// En-tête de la page : en maths, la barre de métriques de la source
    /// (année du programme, avancement, classement XP) ; ailleurs, la carte de
    /// matière. `SubjectsScreen.tsx:9619-9687` branche la barre sur
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
}
