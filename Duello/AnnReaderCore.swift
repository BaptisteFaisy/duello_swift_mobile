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

/// Lecteur d'annale : onglets de document, navigation entre les questions et
/// panneau de correction de copie des épreuves écrites.
///
/// Portage de la partie lecture d'`AnnaleViewer.tsx` : les onglets Énoncé /
/// Barème / Commentaires / Corrigé, les messages de verrouillage du corrigé, le
/// panneau « Annale en cours » et l'ouverture de la fenêtre de correction de
/// copie. L'atelier de réponse (champ de réponse, dictée, tableau blanc,
/// clavier mathématique, console Python) n'est pas porté ici.
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

    @EnvironmentObject private var session: SessionStore

    @State var mode: AnnDocumentMode = .statement
    @State var activeQuestionId: String?
    @State var copySheetOpen = false
    @State var copyJob: AnnCopyJob?
    @State var dsUnlocked = false

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
        unavailableQuestionIds: Set<String> = []
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
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            tabs
            Divider().overlay(Theme.border)
            content
            footer
        }
        .background(Theme.background)
        .onAppear {
            activeQuestionId = entry.questions.first?.id
            reloadCopyJob()
        }
        .onChange(of: entry.id) { _ in
            mode = .statement
            activeQuestionId = entry.questions.first?.id
            dsUnlocked = false
            copySheetOpen = false
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
    }
}
