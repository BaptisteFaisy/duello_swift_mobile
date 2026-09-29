import SwiftUI

// NOTE — découpage de l'ancien `AnnReaderView.swift` (607 lignes, au-delà de la
// limite « 500 lignes par fichier » des règles Duello). Le type `AnnReaderView`
// reste déclaré ici, inchangé ; les autres fichiers `AnnReader<X>.swift` portent
// ses extensions, regroupées par responsabilité :
//   • `AnnReaderHeader.swift`  — en-tête, onglets de document, verrouillage ;
//   • `AnnReaderContent.swift` — navigation entre questions et corps du document ;
//   • `AnnReaderFooter.swift`  — pied de lecteur (épreuves écrites) et aides.
// Les membres partagés entre plusieurs fichiers passent de `private` à
// `internal` : aucun type, propriété, méthode ni signature n'est renommé.

// MARK: - Lecteur d'annale

/// Lecteur d'annale : onglets de document, navigation entre les questions,
/// atelier de réponse (champ de réponse, tableau blanc, console Python) et
/// panneau de correction de copie des épreuves écrites.
///
/// Portage d'`AnnaleViewer.tsx` : les onglets Énoncé / Barème / Commentaires /
/// Corrigé, les messages de verrouillage du corrigé, le séparateur déplaçable
/// entre l'énoncé et l'atelier, le panneau « Annale en cours » et l'ouverture de
/// la fenêtre de correction de copie. L'atelier monte le tableau blanc
/// (`WhiteboardView`) et la console Python (`PythonConsoleView`) portés par
/// l'unité 18 ; la dictée, la photo et le clavier mathématique relèvent d'autres
/// unités (voir rapport).
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

    /// Vrai lorsque toutes les réponses de l'annale ont été envoyées : le
    /// barème et les commentaires ne s'ouvrent qu'à ce moment-là
    /// (`attemptComplete` du lecteur Expo). L'hôte qui câble un parcours de
    /// réponse passe `true` ici.
    var attemptComplete: Bool = false
    /// Verdicts déjà connus, indexés par identifiant de question.
    var verdicts: [String: AnnVerdict] = [:]
    /// Questions classiques, marquées d'une étoile (`classicQuestionIds`).
    var classicQuestionIds: Set<String> = []
    /// Questions conseillées pour plus tard : consultables, pastillées rouge.
    var unavailableQuestionIds: Set<String> = []
    /// Questions en cours de correction (`gradingQuestionIds`) : leur puce
    /// affiche un indicateur d'activité.
    var gradingQuestionIds: Set<String> = []
    /// Erreurs de correction par question (`gradingErrors`) : leur puce passe
    /// au `refresh-circle` « à relancer ».
    var gradingErrors: [String: String] = [:]

    @EnvironmentObject private var session: SessionStore

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
    /// Hauteur relative de l'énoncé au-dessus de l'atelier (`useAnnaleSplit`).
    @State var splitRatio: Double = AnnaleSplit.DEFAULT_ANNALE_SPLIT
    /// Demande du prof IA ouverte par « ✦ Expliquer » sur un corrigé.
    @State var profRequest: ProfTutorRequest?
    /// Suit la vitesse du balayage horizontal sur l'énoncé (SwiftUI ne la
    /// fournit pas) sans provoquer de rendu à chaque point.
    @State var swipeTracker = AnnSwipeTracker()

    init(
        entry: AnnEntry,
        subject: String,
        track: String,
        specialty: String,
        monitor: AnnCorrectionMonitor,
        siblings: [AnnEntry] = [],
        onClose: @escaping () -> Void,
        attemptComplete: Bool = false,
        verdicts: [String: AnnVerdict] = [:],
        classicQuestionIds: Set<String> = [],
        unavailableQuestionIds: Set<String> = [],
        gradingQuestionIds: Set<String> = [],
        gradingErrors: [String: String] = [:]
    ) {
        _entry = State(initialValue: entry)
        self.subject = subject
        self.track = track
        self.specialty = specialty
        _monitor = ObservedObject(wrappedValue: monitor)
        self.siblings = siblings
        self.onClose = onClose
        self.attemptComplete = attemptComplete
        self.verdicts = verdicts
        self.classicQuestionIds = classicQuestionIds
        self.unavailableQuestionIds = unavailableQuestionIds
        self.gradingQuestionIds = gradingQuestionIds
        self.gradingErrors = gradingErrors
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            tabs
            Divider().overlay(Theme.border)
            splitArea
            footer
        }
        .background(Theme.background)
        .onAppear {
            activeQuestionId = entry.questions.first?.id
            splitRatio = AnnaleSplit.loadAnnaleSplit(itemId: entry.id)
            reloadCopyJob()
        }
        .onChange(of: entry.id) { _ in
            mode = .statement
            activeQuestionId = entry.questions.first?.id
            dsUnlocked = false
            copySheetOpen = false
            draft = ""
            answerMode = .text
            whiteboardStrokes = []
            splitRatio = AnnaleSplit.loadAnnaleSplit(itemId: entry.id)
            reloadCopyJob()
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

    /// Ouvre le prof IA sur le corrigé d'une question (`openProfForCorrection`,
    /// `AnnaleViewer.tsx:3558-3569`) : le passage expliqué est le corrigé affiché.
    func explainCorrection(_ text: String, question: String) {
        profRequest = ProfTutorRequest(
            quote: text,
            context: ProfTutorContext(
                source: .corrige,
                subject: subject,
                exercise: entry.title,
                question: "Question \(question)",
                student: profStudent
            )
        )
    }
}
