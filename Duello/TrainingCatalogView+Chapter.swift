import SwiftUI

// V1 2026-09-26 (U06#1, U06#3, U06#4) : fichier modifié. U06#1 : `SubjItemCard`
// ouvrable, `onOpen` réel vers le lecteur d'énoncé (`TrainReaderLink`,
// `openTrainingReader`) ; U06#3 : page « Mon cours » câblée sur
// `SubjCourseChapterRow.onOpen` ; U06#4 : feuille « Cartes » alimentée par les
// cartes persistées du chapitre + révision (`SubjFlashcardReviewModal`).
//
// V2 2026-09-28 (U06#5, #8, #9) : un chapitre s'ouvre désormais en **plein
// écran** (`openChapterList` → `if (openChapter && activeSubject && activeChapter)`,
// `SubjectsScreen.tsx:7595-9400`), au lieu d'un dépliage inline. L'en-tête du
// chapitre porte le retour et les menus de filtre (`showChapterHeaderFilters`) ;
// le récapitulatif (`detailSummary`) ne paraît plus dans les maths Exercices et
// Colles, où la source le masque (`summaryProgressTotal > 0 && canFilterByBadge`).

/// Détail d'un chapitre ouvert : ligne, exercices, filtre de difficulté et
/// compteurs d'avancement. Extension de `TrainingCatalogView`.
extension TrainingCatalogView {

    // MARK: Catalogue (liste des chapitres)

    /// Ligne d'un chapitre dans le programme de la matière. L'appui ouvre la
    /// page du chapitre (`openChapterList`) : la source remplace tout l'écran,
    /// elle ne déplie pas la ligne.
    @ViewBuilder
    func chapterBlock(_ chapter: TrackChapter) -> some View {
        let subjChapter = TrainIntProgram.subjChapter(
            chapter,
            status: courseStatus.status(for: chapter.id)
        )
        // R07 2026-09-29 (U06#10) : identité explicite de la ligne de chapitre.
        // Le `ForEach(group.chapters)` de `TrainingCatalogView+Content.swift`
        // donne déjà `chapter.id` comme identité, mais le replacement au retour
        // d'un chapitre (`ScrollViewReader.scrollTo(restore.chapterId)`,
        // `TrainingCatalogView+Entry.swift`) exige une cible stable : `.id()`
        // l'ancre sans dépendre de l'identité implicite du `ForEach`.
        Group {
            if activeMode == .cours {
                // Vue Cours : la ligne ouvre la page « Mon cours » du chapitre
                // (`TrainCoursePage`), qui porte le lecteur, l'import et le repère.
                SubjCourseChapterRow(
                    chapter: subjChapter,
                    coursePosition: coursePositions[chapter.id],
                    hasCourseDocument: courseDocuments[chapter.id] ?? false,
                    isReturnHighlighted: false,
                    onToggleCourseStatus: { courseStatus.cycle(chapter.id) },
                    onOpen: { openChapterDetail(chapter) }
                )
            } else if let chapterMode = activeMode.chapterMode {
                SubjChapterRow(
                    subjectId: subject.id,
                    chapter: subjChapter,
                    mode: chapterMode,
                    summary: chapterSummary(for: chapter),
                    isReturnHighlighted: false,
                    onToggleCourseStatus: { courseStatus.cycle(chapter.id) },
                    onOpen: { openChapterDetail(chapter) }
                )
            }
        }
        .id(chapter.id)
    }

    // MARK: Page d'un chapitre (plein écran)

    /// Page d'un chapitre ouvert : en-tête (retour + filtres), puis le contenu du
    /// mode — page « Mon cours » en Cours, liste des sujets sinon. Remplace le
    /// programme de la matière, comme `openChapter` de la source.
    func chapterDetailPage(_ chapter: TrackChapter) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            chapterDetailHeader(chapter)
            ScrollView {
                if activeMode == .cours {
                    TrainCoursePage(
                        subjectName: subject.name,
                        chapter: chapter,
                        programYear: programYear ?? 1,
                        onCourseStatus: { courseStatus.set(chapter.id, status: $0) },
                        onClose: { refreshCourseMarkers(for: chapter.id) }
                    )
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                } else {
                    chapterBody(chapter)
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        .padding(.bottom, 40)
                }
            }
        }
        .background(Theme.background)
        .task(id: chapter.id) {
            if activeMode == .cours {
                refreshCourseMarkers(for: chapter.id)
            } else {
                await loadExercisesIfNeeded(for: chapter)
            }
        }
        .onDisappear { refreshCourseMarkers(for: chapter.id) }
    }

    /// En-tête du chapitre : barre de retour (`Revenir à la liste des
    /// chapitres`) puis menus de filtre, montés quand la banque servie et des
    /// sujets sont présents (`showChapterHeaderFilters`).
    private func chapterDetailHeader(_ chapter: TrackChapter) -> some View {
        let loaded = loadedExercises[chapter.id] ?? []
        return HStack(alignment: .bottom, spacing: 4) {
            chapterBackButton
            if showsChapterHeaderFilters(chapter) && canFilterByBadge(chapter) && !loaded.isEmpty {
                filterRow(chapter)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(Theme.background)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Theme.border).frame(height: 1)
        }
    }

    /// Retour à la liste des chapitres (`closeChapterToList`) : carré de 40
    /// points bordé, chevron vers le programme de la matière.
    private var chapterBackButton: some View {
        Button {
            closeChapterDetail()
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
        .accessibilityLabel("Revenir à la liste des chapitres")
    }

    // MARK: Corps du chapitre

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
                chapterSummaryLine(chapter)
                if visible.isEmpty {
                    emptyExercises(chapter, hasLoadedItems: !loaded.isEmpty)
                } else {
                    exerciseList(visible, chapter: chapter)
                }
            }
            .padding(.top, 2)
            .padding(.bottom, 6)
        }
    }

    /// Récapitulatif du chapitre (`ListHeaderComponent`). La source le masque
    /// dès que la banque servie filtre (`canFilterByBadge`) : rien ne s'affiche
    /// alors dans les maths Exercices et Colles.
    @ViewBuilder
    private func chapterSummaryLine(_ chapter: TrackChapter) -> some View {
        if !canFilterByBadge(chapter) {
            let loaded = loadedExercises[chapter.id] ?? []
            if !loaded.isEmpty {
                detailSummary(loaded: loaded)
            }
        }
    }

    /// « 12 exercices disponibles · 3 avec corrigé » (branche
    /// `!canFilterByBadge` de `SubjectsScreen`).
    private func detailSummary(loaded: [TrainExercise]) -> some View {
        let solutions = loaded.filter { $0.hasSolution }.count
        var text = TrainCopy.availability(.exercise, count: loaded.count)
        if solutions > 0 {
            text += " · \(solutions) avec corrigé"
        }
        return Text(text)
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(Theme.inkSoft)
            .padding(.bottom, 4)
    }

    // Le filtre du chapitre ouvert (menus « Prérequis » et « Difficulté ») vit
    // dans `TrainIntFilters.swift` (`filterRow(_:)`).

    @ViewBuilder
    private func emptyExercises(_ chapter: TrackChapter, hasLoadedItems: Bool) -> some View {
        if hasLoadedItems {
            // Des sujets existent, mais le filtre les masque tous.
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
