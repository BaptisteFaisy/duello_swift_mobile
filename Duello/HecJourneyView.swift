import SwiftUI

/// Écran « PARCOURS HEC » : la frise des blocs datés, du chapitre au blason
/// d'admission.
///
/// Porté de `src/components/HecJourney.tsx` — l'orchestration : en-tête, scène,
/// commandes, feuille d'ajout, détail d'un bloc ouvert et écran d'admission —
/// avec la scène de `src/components/HecJourneyScene.tsx`, transposée en 2D par
/// `HecJourneySceneView`.
///
/// Le composant Expo reçoit ses données du parent (`chapters`, `registeredAt`,
/// `programYear`, `startingProgramYear`, `admissionTrack`) et relaie des
/// rappels (`onBack`, `onOpenRanking`, `onOpenChapter`, `onSelectProgramYear`).
/// Deux points d'entrée sont proposés :
/// - l'initialiseur complet, qui reprend ces paramètres un à un ;
/// - `HecJourneyView(profile:)`, qui déduit filière, année et chapitres du
///   profil de l'élève.
///
/// Hors périmètre : `onTabSwipeStart/Move/End/Cancel` (le geste horizontal est
/// laissé au `TabView` parent, voir `HecJourneySceneView`) et `onReady`, qui
/// signalait la création du contexte OpenGL — sans moteur 3D, il n'y a plus
/// rien à attendre.
struct HecJourneyView: View {
    /// Chapitres proposés à l'ajout, par année.
    private let chaptersForYear: (Int) -> [HecJourneyChapter]
    /// Filière du profil, qui filtre les écoles d'admission.
    private let admissionTrack: String
    /// Année dans laquelle l'élève a commencé son parcours dans l'application.
    private let startingProgramYear: Int
    private let onBack: (() -> Void)?
    private let onOpenRanking: () -> Void
    private let onOpenChapter: (String, String?) -> Void

    @State private var programYear: Int
    @State private var activeIndex: Int = 0
    /// `scrollY` de la source : décalage de la frise, en points.
    @State private var scrollOffset: CGFloat = 0
    @State private var openedBlockId: String?
    @State private var admissionOpen = false
    @State private var confirmDeleteBlock = false
    @State private var shortcut: HecJourneyShortcut = .current

    @StateObject private var store: HecJourneyStore
    @StateObject private var flow: HecJourneyAddFlow
    /// Statut de cours des chapitres, partagé avec le catalogue d'entraînement.
    @StateObject private var courseStatus = TrainCourseStatusStore()

    // MARK: Initialisation

    /// Initialiseur complet, calqué sur les `HecJourneyProps` d'Expo.
    init(
        chapters: @escaping (Int) -> [HecJourneyChapter] = { _ in [] },
        admissionTrack: String = "",
        programYear: Int = 1,
        startingProgramYear: Int? = nil,
        registeredAt: Date? = nil,
        onBack: (() -> Void)? = nil,
        onOpenRanking: @escaping () -> Void = {},
        onOpenChapter: @escaping (String, String?) -> Void = { _, _ in }
    ) {
        self.chaptersForYear = chapters
        self.admissionTrack = admissionTrack
        self.startingProgramYear = startingProgramYear ?? programYear
        self.onBack = onBack
        self.onOpenRanking = onOpenRanking
        self.onOpenChapter = onOpenChapter
        _programYear = State(initialValue: programYear)

        let store = HecJourneyStore(programYear: programYear, registeredAt: registeredAt)
        _store = StateObject(wrappedValue: store)
        _flow = StateObject(wrappedValue: HecJourneyAddFlow(store: store))
    }

    /// Parcours déduit du profil : filière, année, chapitres de mathématiques.
    init(
        profile: UserProfile,
        onBack: (() -> Void)? = nil,
        onOpenRanking: @escaping () -> Void = {},
        onOpenChapter: @escaping (String, String?) -> Void = { _, _ in }
    ) {
        let year = HecJourneyProfile.programYear(from: profile.year)
        self.init(
            chapters: { HecJourneyProfile.mathsChapters(profile: profile, year: $0) },
            admissionTrack: profile.track,
            programYear: year,
            startingProgramYear: year,
            onBack: onBack,
            onOpenRanking: onOpenRanking,
            onOpenChapter: onOpenChapter
        )
    }

    // MARK: Corps

    var body: some View {
        let model = sceneModel
        return content(model: model)
            .background(Theme.background)
            .alert(HecJourneyCopy.deleteBlockQuestion, isPresented: $confirmDeleteBlock) {
                Button(HecJourneyCopy.cancelButton, role: .cancel) { }
                Button(HecJourneyCopy.deleteButton, role: .destructive) {
                    deleteOpenedBlock(model: model)
                }
            } message: {
                Text(HecJourneyCopy.deleteBlockMessage)
            }
            .onAppear {
                // `scrollY.value = nextIndex * HEC_JOURNEY_NODE_GAP` : le
                // premier cadrage se pose sans animation.
                focus(index: model.currentBlockIndex, count: model.blocks.count, animated: false)
            }
            .onChange(of: flow.focusRequest) { request in
                guard let request else { return }
                focus(
                    index: request.index,
                    count: min(request.count, model.blocks.count)
                )
            }
    }

    @ViewBuilder
    private func content(model: HecJourneySceneModel) -> some View {
        if admissionOpen || model.activeBlock(at: activeIndex)?.type == .admission {
            HecJourneyAdmissionView(
                admission: store.admission,
                admissionTrack: admissionTrack,
                onBack: {
                    admissionOpen = false
                    openedBlockId = nil
                },
                onSave: { admission in
                    store.save(admission: admission)
                    admissionOpen = false
                    openedBlockId = nil
                },
                onReset: { store.resetAdmission() }
            )
        } else {
            VStack(spacing: 0) {
                HecJourneyHeaderBar(
                    showsBackButton: onBack != nil,
                    programYear: programYear,
                    onBack: { onBack?() },
                    onSelectYear: selectYear,
                    onOpenRanking: onOpenRanking
                )
                HecJourneyStageView(
                    model: model,
                    programYear: programYear,
                    activeIndex: activeIndex,
                    scrollOffset: $scrollOffset,
                    flow: flow,
                    chapters: chaptersForYear(programYear),
                    registeredAt: store.registeredAt,
                    shortcut: shortcut,
                    onSelectNode: { selectNode($0, model: model) },
                    onActiveIndexChange: { activeIndex = $0 },
                    onAddBlock: { flow.open(neutralId: nil) },
                    onShortcut: { applyShortcut(model: model) },
                    onSelectYear: selectYear
                )
            }
            .overlay(openedBlockOverlay(model: model))
        }
    }

    /// Bouton de navigation de la frise : « bloc actuel », puis « fin », puis
    /// « début », en passant au raccourci suivant (`JOURNEY_SHORTCUTS`).
    private func applyShortcut(model: HecJourneySceneModel) {
        switch shortcut {
        case .current:
            focus(index: model.currentBlockIndex, count: model.blocks.count)
        case .end:
            focus(index: model.blocks.count - 1, count: model.blocks.count)
        case .start:
            focus(index: 0, count: model.blocks.count)
        }
        shortcut = shortcut.next
    }

    /// `openedBlockOverlay` : le détail d'un bloc reste superposé à la frise.
    @ViewBuilder
    private func openedBlockOverlay(model: HecJourneySceneModel) -> some View {
        if let block = model.blocks.first(where: { $0.id == openedBlockId }),
           block.type != .admission {
            HecJourneyBlockDetailView(
                block: block,
                canDelete: block.type != .registration
                    && block.id != HecJourneyTimelineConstants.summerBreakBlockId,
                onClose: { openedBlockId = nil },
                onOpenRanking: onOpenRanking,
                onDelete: { confirmDeleteBlock = true }
            )
        }
    }

    // MARK: Données

    private var sceneModel: HecJourneySceneModel {
        HecJourneySceneModel(
            store: store,
            programYear: programYear,
            startingProgramYear: startingProgramYear,
            courseStatus: { courseStatus.status(for: $0) }
        )
    }

    // MARK: Actions

    /// `focusBlock` : cadre la frise sur un cran, avec le ressort de la source.
    private func focus(index: Int, count: Int, animated: Bool = true) {
        guard count > 0 else { return }
        let bounded = max(0, min(count - 1, index))
        if bounded != activeIndex {
            activeIndex = bounded
        }
        let target = CGFloat(bounded) * HecJourneyGesture.nodeGap
        if animated {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
                scrollOffset = target
            }
        } else {
            scrollOffset = target
        }
    }

    /// `handleSelectNode` : un emplacement neutre ouvre la feuille d'ajout, un
    /// chapitre ouvre son cours, le blason ouvre l'admission, les autres blocs
    /// ouvrent leur détail.
    private func selectNode(_ index: Int, model: HecJourneySceneModel) {
        focus(index: index, count: model.blocks.count)
        guard let block = model.activeBlock(at: index) else { return }
        switch block.type {
        case .admission:
            admissionOpen = true
        case .registration:
            openedBlockId = block.id
        case .block(.neutral):
            flow.open(neutralId: block.id)
        case .block(.chapter):
            if let chapterId = block.chapterId {
                onOpenChapter(chapterId, block.id)
            } else {
                openedBlockId = block.id
            }
        case .block:
            openedBlockId = block.id
        }
    }

    /// `deleteOpenedBlock` : un jalon redevient neutre, un repère disparaît.
    private func deleteOpenedBlock(model: HecJourneySceneModel) {
        guard let block = model.blocks.first(where: { $0.id == openedBlockId }) else { return }
        store.delete(block)
        openedBlockId = nil
        let refreshed = sceneModel
        focus(index: refreshed.currentBlockIndex, count: refreshed.blocks.count)
    }

    /// `handleSelectJourneyYear` : la frise de l'autre année est relue, et le
    /// cadrage se porte au début de la 2e année ou à la fin de la 1re.
    private func selectYear(_ year: Int) {
        guard year != programYear else { return }
        flow.close()
        openedBlockId = nil
        admissionOpen = false
        store.switchYear(to: year)
        programYear = year
        let refreshed = sceneModel
        focus(
            index: year == 2 ? 0 : max(0, refreshed.blocks.count - 1),
            count: refreshed.blocks.count,
            animated: false
        )
    }
}
