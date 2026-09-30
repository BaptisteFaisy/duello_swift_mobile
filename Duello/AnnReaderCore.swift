import SwiftUI

// NOTE — découpage de l'ancien `AnnReaderView.swift` (607 lignes, au-delà de la
// limite « 500 lignes par fichier » des règles Duello). Le type `AnnReaderView`
// reste déclaré ici, inchangé ; les autres fichiers `AnnReader<X>.swift` portent
// ses extensions, regroupées par responsabilité :
//   • `AnnReaderHeader.swift`    — en-tête, onglets de document, verrouillage ;
//   • `AnnReaderContent.swift`   — navigation entre questions et corps du document ;
//   • `AnnReaderFooter.swift`    — pied de lecteur (épreuves écrites) et aides ;
//   • `AnnReaderSwipe.swift`     — balayage du document et séparateur ;
//   • `AnnReaderSubmission.swift`— soumission d'une réponse ou de la copie (18#2) ;
//   • `AnnReaderGrading.swift`   — envoi au correcteur et suivi du lot ;
//   • `AnnReaderDerived.swift`   — état dérivé (question, verdicts, bilan) ;
//   • `AnnReaderSubmitUI.swift`  — zone de soumission.
// Les membres partagés entre plusieurs fichiers passent de `private` à
// `internal` : aucun type, propriété, méthode ni signature n'est renommé.

// MARK: - Lecteur d'annale

/// Lecteur d'annale : onglets de document, navigation entre les questions,
/// atelier de réponse (champ de réponse, tableau blanc, console Python), atelier
/// de correction (soumission, verdict, bilan) et panneau de correction de copie.
///
/// Portage d'`AnnaleViewer.tsx` : les onglets Énoncé / Barème / Commentaires /
/// Corrigé, les messages de verrouillage du corrigé, le séparateur déplaçable,
/// la soumission d'une réponse ou de la copie entière (P0 18#2) et l'ouverture de
/// la fenêtre de correction de copie.
struct AnnReaderView: View {
    /// Annale affichée. L'état est modifiable pour passer d'un sujet à l'autre
    /// depuis la même fenêtre de lecture.
    @State var entry: AnnEntry
    let subject: String
    let track: String
    let specialty: String
    @ObservedObject var monitor: AnnCorrectionMonitor
    /// Sujets de la même matière, pour passer d'une annale à la suivante.
    var siblings: [AnnEntry] = []
    var onClose: () -> Void

    /// Parcours d'entraînement (`Exercices`/`Colles`) : toute la copie part en
    /// une fois, au lieu du parcours d'annale question par question.
    var wholeExerciseSubmissionOnly: Bool = false
    /// Cours du chapitre ouvert, pour la fenêtre de contexte du prof
    /// (`source: .cours`, `SubjectsScreen.tsx:4043-4084`) : monté par
    /// `ProfCourseTextSession`, porté dans `ProfDocuments.course`.
    var courseDocument: CtdStoredCourseDocument? = nil
    /// Questions classiques, marquées d'une étoile (`classicQuestionIds`).
    var classicQuestionIds: Set<String> = []
    /// Questions conseillées pour plus tard : consultables, pastillées rouge.
    var unavailableQuestionIds: Set<String> = []

    @EnvironmentObject var session: SessionStore
    /// `AppState` : le brouillon visible est persisté dès que l'app quitte le
    /// premier plan (`persistVisibleDraft`).
    @Environment(\.scenePhase) private var scenePhase

    // Lecture
    @State var mode: AnnDocumentMode = .statement
    @State var activeQuestionId: String?
    @State var copySheetOpen = false
    @State var copyJob: AnnCopyJob?
    @State var dsUnlocked = false
    /// Brouillon de la réponse en cours (champ de réponse de l'atelier).
    @State var draft = ""
    /// Outil d'écriture affiché dans l'atelier.
    @State var answerMode: AnnAnswerMode = .text
    /// Brouillon du tableau blanc de la question ouverte.
    @State var whiteboardStrokes: [WbStroke] = []
    /// Repli du tableau blanc, remonté du champ pour que le bilan en modale et
    /// le dock de correction en tiennent compte (`whiteboardExpanded`).
    @State var whiteboardExpanded = false
    /// Champ de réponse au premier plan : c'est le clavier système ouvert
    /// (`useSystemKeyboardOpen`).
    @FocusState var answerFieldFocused: Bool
    /// Item dont le brouillon a été chargé (`loadedDraftItemId`) : garde la
    /// sauvegarde différée tant que le sujet n'a pas été restauré.
    @State var draftLoadedItemId: String?
    /// Sauvegarde différée du brouillon (`setTimeout(…, 450)`).
    @State var draftSaveTask: Task<Void, Never>?
    /// Hauteur relative de l'énoncé au-dessus de l'atelier (`useAnnaleSplit`).
    @State var splitRatio: Double = AnnaleSplit.DEFAULT_ANNALE_SPLIT
    /// Demande du prof IA ouverte par « ✦ Expliquer » sur un corrigé.
    @State var profRequest: ProfTutorRequest?
    /// Suit la vitesse du balayage horizontal sur l'énoncé (SwiftUI ne la
    /// fournit pas) sans provoquer de rendu à chaque point.
    @State var swipeTracker = AnnSwipeTracker()

    // Soumission / correction (P0 18#2) : l'état vit sur le lecteur, plus chez
    // l'hôte — la tentative persistée fait foi (`attempt`), comme `attemptRef`.
    @State var attempt: AnnAttempt?
    /// Questions en cours de correction (`gradingQuestionIds`) : leur puce
    /// affiche un indicateur d'activité.
    @State var gradingQuestionIds: Set<String> = []
    /// Erreurs de correction par question (`gradingErrors`) : leur puce passe
    /// au `refresh-circle` « à relancer ».
    @State var gradingErrors: [String: String] = [:]
    /// Copie envoyée en cours de correction (`correctionSummary`).
    @State var correction: AnnCorrectionState?
    /// Avancement du lot de corrections (`batchProgress`).
    @State var batchProgress: AnnBatchProgress?
    /// Questions du lot encore attendues (`batchPendingQuestionIds`).
    @State var batchPendingQuestionIds: Set<String> = []
    /// Programme Python en cours d'exécution avant une correction.
    @State var pythonRunning = false
    /// Question dont le programme Python retient la correction (`pythonBlocked`).
    @State var pythonBlocked: AnnPythonBlocked?
    /// Bilan refermé pour la soumission en cours (`resultCardDismissedId`).
    @State var resultCardDismissedId: String?
    /// Repère « classement vu » du compte (`ExerciseRankingSeenMap`).
    @State var rankingSeen: [String: String] = [:]
    /// Console Python partagée par l'atelier et la garde avant correction (18#5).
    @StateObject var pythonModel = PyConConsoleModel()
    /// Texte du cours du chapitre, pour le prof IA (S06).
    @StateObject var courseText = ProfCourseTextSession()
    /// Consentement IA demandé avant une correction.
    @State var correctionConsentVisible = false
    @State var pendingCorrectionAction: (@MainActor () async -> Void)?
    @State var pendingCorrectionQuestionIds: [String] = []

    init(
        entry: AnnEntry,
        subject: String,
        track: String,
        specialty: String,
        monitor: AnnCorrectionMonitor,
        siblings: [AnnEntry] = [],
        onClose: @escaping () -> Void,
        wholeExerciseSubmissionOnly: Bool = false,
        courseDocument: CtdStoredCourseDocument? = nil,
        classicQuestionIds: Set<String> = [],
        unavailableQuestionIds: Set<String> = []
    ) {
        _entry = State(initialValue: entry)
        self.subject = subject
        self.track = track
        self.specialty = specialty
        _monitor = ObservedObject(wrappedValue: monitor)
        self.siblings = siblings
        self.onClose = onClose
        self.wholeExerciseSubmissionOnly = wholeExerciseSubmissionOnly
        self.courseDocument = courseDocument
        self.classicQuestionIds = classicQuestionIds
        self.unavailableQuestionIds = unavailableQuestionIds
    }

    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 0) {
                header
                tabs
                Divider().overlay(Theme.border)
                splitArea
                footer
            }
            .background(Theme.background)
            // Fenêtre du bilan : premier plan sur téléphone, fermée par la
            // croix, par un toucher en dehors ou à la première retouche. Ni
            // tableau blanc, ni corrigé en plein écran : le bilan en page garde
            // ces parcours (`AnnaleViewer.tsx:5043-5060`).
            if resultModalVisible, let correction = correctionDockCorrection {
                AnnResultModal(
                    scoreOn20: gradingScore.scoreOn20,
                    xp: resultXp,
                    exerciseRank: resultRank,
                    correction: correction,
                    onClose: dismissResultCard
                )
            }
        }
        .onAppear {
            loadAttempt()
            loadRankingSeen()
            activeQuestionId = entry.questions.first?.id
            restoreDraft()
            splitRatio = AnnaleSplit.loadAnnaleSplit(itemId: entry.id)
            reloadCopyJob()
        }
        .onChange(of: entry.id) { _ in
            mode = .statement
            loadAttempt()
            activeQuestionId = entry.questions.first?.id
            restoreDraft()
            dsUnlocked = false
            copySheetOpen = false
            answerMode = .text
            whiteboardStrokes = []
            whiteboardExpanded = false
            splitRatio = AnnaleSplit.loadAnnaleSplit(itemId: entry.id)
            reloadCopyJob()
        }
        .onChange(of: draft) { _ in scheduleDraftSave() }
        .onChange(of: scenePhase) { phase in
            if phase != .active { persistVisibleDraft() }
        }
        .task(id: courseDocument?.id) { @MainActor in
            courseText.update(document: courseDocument, token: session.token)
        }
        // `closeViewer` : la dernière tentative est persistée à la fermeture, et
        // le brouillon visible l'est aussi (`persistVisibleDraft`).
        .onDisappear {
            persistVisibleDraft()
            flushDraftToAttempt()
            Task { @MainActor in await persistAttempt() }
        }
        .fullScreenCover(isPresented: $copySheetOpen) {
            AnnCopyCorrectionSheet(
                itemId: entry.id,
                title: entry.title,
                subject: subject,
                statement: entry.statement ?? entry.title,
                solution: entry.solution,
                durationMinutes: entry.durationHours * 60,
                monitor: monitor,
                initialJob: copyJob,
                onClose: { copySheetOpen = false },
                onNewAttempt: {
                    copyJob = nil
                    reloadCopyJob()
                },
                onJobChange: { job in
                    copyJob = job
                    monitor.upsert(job)
                }
            )
            .environmentObject(session)
        }
        .sheet(item: $profRequest) { request in
            ProfTutorSheet(
                request: request,
                token: session.token,
                // `onOpenProfile` : le chevron de l'en-tête ouvre la fiche du
                // prof IA dans l'onglet « Mon compte », via le coordinateur
                // racine — même couture que `CourseDocumentView` et le tap de
                // notification (`PushNotifRootMount`).
                onOpenProfile: { memberId in
                    Task { @MainActor in
                        PushNotifRootCoordinator.shared.pendingMember =
                            PushNotifPendingMember(id: memberId)
                    }
                }
            ) { profRequest = nil }
        }
        // `submitWithCorrectionAccess` : la correction IA exige l'accord de
        // partage avec les prestataires d'IA.
        .alert(CtdAiConsent.title, isPresented: $correctionConsentVisible) {
            Button(CtdAiConsent.denyLabel, role: .cancel) { resolveCorrectionConsent(granted: false) }
            Button(CtdAiConsent.allowLabel) { resolveCorrectionConsent(granted: true) }
        } message: {
            Text(CtdAiConsent.message)
        }
    }
}

// MARK: - Brouillon persisté

extension AnnReaderView {
    /// `systemKeyboardOpen` : le clavier système est ouvert quand le champ de
    /// réponse a le focus — le bouton « Soumettre » reste alors derrière, comme
    /// la source (`useSystemKeyboardOpen`).
    var systemKeyboardOpen: Bool { answerFieldFocused }

    /// `annaleDraftStorageKey` : brouillon de copie du sujet, dans les
    /// préférences locales (clé logique conservée à l'identique).
    private var draftStorageKey: String {
        RewStorageKeys.annaleDraftStorageKey(entry.id)
    }

    /// Restaure le brouillon visible du sujet : le texte enregistré prime sur
    /// la réponse de la question ouverte (`loadedDraftItemId`).
    func restoreDraft() {
        let stored = UserDefaults.standard.string(forKey: draftStorageKey)
        if let stored, !stored.isEmpty {
            draft = stored
        } else {
            draft = attempt?.answers[activeQuestionId ?? ""] ?? ""
        }
        draftLoadedItemId = entry.id
    }

    /// `setTimeout(…, 450)` : la sauvegarde attend que la frappe se pose.
    func scheduleDraftSave() {
        guard draftLoadedItemId == entry.id else { return }
        draftSaveTask?.cancel()
        draftSaveTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 450_000_000)
            guard !Task.isCancelled else { return }
            persistVisibleDraft()
        }
    }

    /// `persistVisibleDraft` : un brouillon vide retire la clé au lieu
    /// d'écrire une chaîne vide.
    func persistVisibleDraft() {
        guard draftLoadedItemId == entry.id else { return }
        if draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            UserDefaults.standard.removeObject(forKey: draftStorageKey)
        } else {
            UserDefaults.standard.set(draft, forKey: draftStorageKey)
        }
    }
}

extension AnnReaderView {
    /// Socle v2 de la fenêtre de contexte du prof (`profStudentContext`,
    /// `profTutor.ts:56`) : identité de l'élève et programme de sa filière et de
    /// son année, transmis au relais avec le corrigé expliqué
    /// (`AnnaleViewer.tsx:2020-2035`). L'année suit `toProgramYear` du profil.
    var profStudent: ProfStudent {
        profStudentContext(
            profile: session.profile,
            programYear: HecJourneyProfile.programYear(from: session.profile.year)
        )
    }

    /// `profContextBase` (`SubjectsScreen.tsx:4043-4084`) : socle de la page
    /// Entraînement — source `.cours`, identité de l'élève et cours du chapitre
    /// uploadé (`useProfCourseText`), monté par `ProfCourseTextSession`. Le
    /// lecteur d'annale le reprend en y ajoutant l'énoncé et le corrigé du sujet.
    var profContextBase: ProfContextInput {
        ProfContextInput(
            source: .cours,
            student: profStudent,
            subject: subject,
            chapter: nil,
            exercise: nil,
            question: nil,
            page: nil,
            item: nil,
            course: courseDocument.map { (name: $0.name, text: courseText.courseText) }
        )
    }

    /// `ProfDocuments.course` du socle de cours (`profContextBase.course`) : texte
    /// extrait du cours du chapitre et nom du fichier, rognés par
    /// `profTutorContext` (`PROF_COURSE_MAX_CHARS`). `nil` quand le lecteur n'a
    /// pas de cours (annale pure) ou qu'aucun texte exploitable n'en a été
    /// extrait (photo, scan) — le prof s'en tient alors à la page sélectionnée.
    var profCourseDocuments: ProfDocuments? {
        guard courseDocument != nil else { return nil }
        return profTutorContext(profContextBase).documents
    }

    /// Ouvre le prof IA sur le corrigé d'une question (`openProfForCorrection`,
    /// `AnnaleViewer.tsx:3558-3569`) : le passage expliqué est le corrigé affiché.
    /// Le socle du cours du chapitre est joint (`...profContext` de la source),
    /// seule autorité sur la matière affichée (`subject`).
    func explainCorrection(_ text: String, question: String) {
        let base = profContextBase
        let input = ProfContextInput(
            source: .corrige,
            student: base.student,
            subject: subject,
            chapter: nil,
            exercise: entry.title,
            question: "Question \(question)",
            page: nil,
            item: (statement: entry.statement, solution: entry.solution),
            course: base.course
        )
        profRequest = ProfTutorRequest(quote: text, context: profTutorContext(input))
    }
}
