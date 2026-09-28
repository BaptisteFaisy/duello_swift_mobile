import SwiftUI
import UniformTypeIdentifiers

// V1 2026-09-26 (U06#3) : fichier neuf. Page « Mon cours » d'un chapitre
// (`selectedMode === 'cours'`, `SubjectsScreen.tsx:7942-8502`) : bouton de
// repère (`placeCourseProgress` `6069`), lecteur (`CourseDocumentViewer`),
// import/remplacement (`uploadCourseDocument` `5828`), suppression
// (`deleteCourseDocument` + `confirmCourseDocumentDeletion`).
//
// V2 2026-09-28 (U06#3, #12) : la page porte désormais les onglets de la
// source « Lire / Générer / Créer / Réviser » (`8044/8075/8117/8158`) ; les
// trois onglets de cartes hébergent `TrainFlashcardsPanel` — l'accès aux
// flashcards vit donc **dans le cours**, plus dans une barre de navigation.
// L'analyse des notions du cours (`indexCourseKnowledge` `4934`,
// `courseAnalysisStatus` `8244`) est montée sous le repère, avec sa reprise
// « Réessayer » (`retryCourseKnowledgeAnalysis` `5061`).

/// Page « Mon cours » d'un chapitre : onglets Lire / Générer / Créer / Réviser,
/// repère de progression, lecteur du document importé, import/remplacement/
/// suppression, analyse des notions.
struct TrainCoursePage: View {
    let subjectName: String
    let chapter: TrackChapter
    /// Année du programme (`programYear`) : le document est rangé par année.
    let programYear: Int
    /// Statut posé par le repère (`courseStatusAtPosition`).
    var onCourseStatus: ((TrainCourseStatus) -> Void)? = nil
    var onClose: (() -> Void)? = nil

    @EnvironmentObject private var session: SessionStore

    /// Document du chapitre (`storedCourseDocument`), relu à l'ouverture.
    @State private var document: CtdStoredCourseDocument?
    @State private var loaded = false
    @State private var pickerVisible = false
    @State private var fullscreenOpen = false
    @State private var uploadPending = false
    @State private var deletePending = false
    /// Mode de placement du repère (`coursePositioning`) : le lecteur suit le
    /// brouillon, « Enregistrer » le valide.
    @State private var positioning = false
    /// Brouillon de position (`coursePositionDraftRef`), 0 à 1.
    @State private var positionDraft: Double = 0
    @State private var alert: TrainCourseAlert?

    /// Onglet de la page (`coursePage` + `flashcardPanel`).
    @State private var tab: TrainCoursePageTab = .lire

    // Analyse des notions (`courseKnowledgeIndexesByKey`).
    @State private var knowledgeIndex: CollKnowledgeDocument?
    @State private var knowledgeError: String?
    @State private var knowledgeAnalyzing = false
    @State private var knowledgeProgress: CollFlashcardGenerationProgress?

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            if !loaded {
                SubjDeferredInlineFallback(label: "Ouverture du cours…")
            } else {
                tabRow
                switch tab {
                case .lire:
                    courseSection
                case .generate, .create, .review:
                    TrainFlashcardsPanel(
                        subject: subjectName,
                        chapterId: chapter.id,
                        chapterName: chapter.name,
                        programYear: programYear,
                        hasCourseDocument: document != nil,
                        coursePosition: document?.classProgress?.position ?? 0,
                        panel: tab.flashcardPanel ?? .generate
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .task(id: chapter.id) { reload() }
        .onDisappear { validateOnLeave() }
        .fileImporter(
            isPresented: $pickerVisible,
            allowedContentTypes: [.pdf, .jpeg, .png],
            allowsMultipleSelection: false,
            onCompletion: handlePickedFile
        )
        .fullScreenCover(isPresented: $fullscreenOpen) {
            if let document {
                TrainCourseFullscreen(
                    document: document,
                    onClose: { fullscreenOpen = false }
                )
            }
        }
        .alert(alertTitle, isPresented: alertBinding) {
            alertButtons
        } message: {
            if let alert { Text(alert.message) }
        }
    }

    // MARK: - Onglets

    /// Barre « Lire / Générer / Créer / Réviser » (`styles.modeTabs`).
    private var tabRow: some View {
        HStack(spacing: 5) {
            ForEach(TrainCoursePageTab.allCases) { item in
                Button {
                    tab = item
                } label: {
                    HStack(spacing: 6) {
                        IonIcon(
                            name: item.ionName,
                            size: 16,
                            color: tab == item ? Color.white : Theme.inkSoft
                        )
                        Text(item.label)
                            .font(.system(size: 13, weight: .heavy))
                            .lineLimit(1)
                            .foregroundStyle(tab == item ? Color.white : Theme.inkSoft)
                    }
                    .padding(.horizontal, 4)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(tab == item ? Theme.primary : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(item.accessibilityLabel)
                .accessibilityAddTraits(tab == item ? [.isSelected] : [])
            }
        }
        .padding(4)
        .background(Theme.surfaceMuted)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    /// Contenu de l'onglet « Lire » (`coursePage === 'course'`).
    @ViewBuilder
    private var courseSection: some View {
        if let document {
            positionBlock(document: document)
            knowledgeStatus(document: document)
            documentFrame(document: document)
            replaceButton
            deleteButton
        } else {
            uploadButton
            Text("Importe un PDF ou une photo JPEG/PNG pour générer automatiquement tes flashcards.")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Chargement

    /// Relecture du document à l'ouverture du chapitre.
    private func reload() {
        loaded = false
        positioning = false
        tab = .lire
        document = TrainCourseDocument.load(year: programYear, chapterId: chapter.id)
        positionDraft = document?.classProgress?.position ?? 0
        knowledgeIndex = TrainCourseKnowledge.load(year: programYear, chapterId: chapter.id)
        knowledgeError = nil
        knowledgeAnalyzing = false
        knowledgeProgress = nil
        loaded = true
        if let document { startKnowledgeAnalysisIfNeeded(document: document) }
    }

    /// Quitter après avoir déplacé le repère vaut validation : cela évite de
    /// perdre silencieusement la position (`leaveCoursePage`).
    private func validateOnLeave() {
        if positioning { placeProgress() }
    }

    // MARK: - Repère de progression

    /// Bouton de repère + hint d'enregistrement ou position mémorisée
    /// (`placeCourseProgress`, `SubjectsScreen.tsx:8207-8243`) :
    @ViewBuilder
    private func positionBlock(document: CtdStoredCourseDocument) -> some View {
        Button {
            placeProgress()
        } label: {
            HStack(spacing: 8) {
                IonIcon(
                    name: positioning ? "checkmark" : "locate-outline",
                    size: 18,
                    color: positioning ? Theme.surface : Theme.ink
                )
                Text(positioning ? "Enregistrer cette position" : "Indiquer où j’en suis")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(positioning ? Theme.surface : Theme.ink)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(positioning ? Theme.ink : Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusMedium)
                    .stroke(Theme.border, lineWidth: positioning ? 0 : 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(positioning
            ? "Enregistrer la position atteinte dans le cours"
            : "Indiquer où le cours en classe est arrivé")
        if positioning {
            // U06#3 : la source place le repère **en faisant défiler le cours**
            // et en le posant face à une ligne rouge (`CourseDocumentViewer`
            // `positioning` + `onPositionChange`). Le lecteur partagé
            // (`CtdDocumentViewer`, `CourseDocumentView.swift`) n'expose encore
            // ni `positioning` ni `onPositionChange` : la glissière ci-dessous
            // est le seul moyen de régler la position tant que ce raccordement
            // n'est pas fait (voir le rapport, « À raccorder »).
            VStack(alignment: .leading, spacing: 8) {
                Text("Fais défiler le cours jusqu’au dernier point vu en classe et place-le face au repère rouge. Le bouton ou le retour enregistrera cette position.")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
                Slider(value: $positionDraft, in: 0...1)
                    .tint(Theme.ink)
                    .accessibilityLabel("Position atteinte dans le cours")
            }
        } else if let progress = document.classProgress {
            Text("Progression du cours enregistrée à \(Int((progress.position * 100).rounded())) %.")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// `placeCourseProgress` : premier appui = armer le placement, second appui
    /// = enregistrer la position (bornée 0–1) et poser le statut de cours.
    private func placeProgress() {
        guard let current = document else { return }
        if !positioning {
            positionDraft = current.classProgress?.position ?? 0
            positioning = true
            return
        }
        let position = min(1, max(0, positionDraft))
        var updated = current
        updated.classProgress = CtdStoredCourseDocument.ClassProgress(
            position: position,
            updatedAt: TrainChapterFlashcards.now()
        )
        document = updated
        positioning = false
        onCourseStatus?(status(at: position))
        TrainCourseDocument.save(updated, year: programYear, chapterId: chapter.id)
    }

    /// `courseStatusAtPosition` : 0 = À venir, 1 = Vu, entre les deux = En cours.
    private func status(at position: Double) -> TrainCourseStatus {
        if position <= 0 { return .notStarted }
        if position >= 1 { return .completed }
        return .inProgress
    }

    // MARK: - Analyse des notions

    /// Démarre l'analyse du cours quand un PDF est présent et qu'aucun index
    /// n'existe pour ce document (`indexCourseKnowledge`, `SubjectsScreen.tsx:5034`).
    private func startKnowledgeAnalysisIfNeeded(document: CtdStoredCourseDocument) {
        guard document.mimeType == .pdf else { return }
        guard knowledgeIndex?.sourceUploadedAt != document.uploadedAt else { return }
        guard !knowledgeAnalyzing else { return }
        Task { await runKnowledgeAnalysis(document: document) }
    }

    /// `indexCourseKnowledge` : génère les cartes du cours puis en tire l'index
    /// de connaissances (`persistCourseKnowledgeIndex`).
    private func runKnowledgeAnalysis(document: CtdStoredCourseDocument) async {
        knowledgeAnalyzing = true
        knowledgeError = nil
        defer { knowledgeAnalyzing = false; knowledgeProgress = nil }
        let accountId = session.session?.publicId ?? ""
        let storage = CollUserDefaultsFlashcardJobStorage(accountId: accountId)
        do {
            let generated = try await CollFlashcardsApi.generateCourseFlashcardsFromPdf(
                accountId: accountId,
                document: document,
                chapterName: chapter.name,
                storage: storage,
                token: session.token,
                options: CollFlashcardGenerationOptions(
                    jobStorageKey: TrainCourseKnowledge.jobStorageKey(
                        year: programYear, chapterId: chapter.id
                    ),
                    onProgress: { progress in
                        Task { @MainActor in knowledgeProgress = progress }
                    }
                )
            )
            persistKnowledgeIndex(document: document, generated: generated)
        } catch {
            knowledgeError = CollFlashcardsApi.generationErrorMessage(error)
        }
    }

    /// `persistCourseKnowledgeIndex` : l'index des notions positionnées remplace
    /// celui du chapitre, et l'erreur éventuelle s'efface.
    private func persistKnowledgeIndex(
        document: CtdStoredCourseDocument, generated: CollFlashcardsDocument
    ) {
        let index = CollCourseIndex.fromFlashcards(generated, sourceUploadedAt: document.uploadedAt)
        guard !index.anchors.isEmpty else { return }
        TrainCourseKnowledge.save(index, year: programYear, chapterId: chapter.id)
        knowledgeIndex = index
        knowledgeError = nil
    }

    /// Reprise explicite (`retryCourseKnowledgeAnalysis`).
    private func retryKnowledgeAnalysis() {
        guard let document else { return }
        knowledgeError = nil
        Task { await runKnowledgeAnalysis(document: document) }
    }

    /// Bandeau d'analyse des notions (`courseAnalysisStatus`), montré pour un
    /// PDF seulement.
    @ViewBuilder
    private func knowledgeStatus(document: CtdStoredCourseDocument) -> some View {
        if document.mimeType == .pdf {
            let hasError = knowledgeError != nil
            HStack(alignment: .center, spacing: 8) {
                if knowledgeAnalyzing {
                    ProgressView().controlSize(.small).tint(Theme.inkSoft)
                } else {
                    IonIcon(
                        name: knowledgeIndex != nil
                            ? "checkmark-circle-outline"
                            : hasError ? "alert-circle-outline" : "time-outline",
                        size: 17,
                        color: hasError ? Color(hex: 0xA31616) : Theme.inkSoft
                    )
                }
                Text(knowledgeStatusText)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
                if hasError {
                    Button {
                        retryKnowledgeAnalysis()
                    } label: {
                        Text("Réessayer")
                            .font(.system(size: 11, weight: .black))
                            .foregroundStyle(Color(hex: 0xA31616))
                            .padding(.horizontal, 10)
                            .frame(minHeight: 30)
                            .background(Theme.surface)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Réessayer l’analyse du cours")
                }
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 9)
            .frame(minHeight: 42, alignment: .leading)
            .background(hasError ? Color(hex: 0xFFF1F1) : Theme.surfaceMuted)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall))
            .accessibilityElement(children: .contain)
        }
    }

    /// Message du bandeau d'analyse (`courseAnalysisStatusText`).
    private var knowledgeStatusText: String {
        if knowledgeAnalyzing {
            let label = knowledgeProgressLabel ?? "Analyse des notions en arrière-plan…"
            return "\(label) Tu peux déjà indiquer où tu en es."
        }
        if let index = knowledgeIndex {
            return "\(index.anchors.count) notions repérées : les badges utilisent la position exacte du curseur."
        }
        if let knowledgeError {
            return "Analyse interrompue : \(knowledgeError)"
        }
        return "L’analyse précise des notions démarrera automatiquement."
    }

    /// `activeCourseKnowledgeProgressLabel` : phase de l'analyse en cours.
    private var knowledgeProgressLabel: String? {
        guard let progress = knowledgeProgress else { return nil }
        switch progress.phase {
        case .preparing: return "Préparation du fichier…"
        case .uploading:
            let percent = Int(((progress.fraction ?? 0) * 100).rounded())
            return "Téléversement du cours : \(percent) %"
        case .queued: return "Cours téléversé · Analyse en attente…"
        case .analyzing: return "Cours téléversé · Analyse des notions…"
        }
    }

    // MARK: - Lecteur

    /// Lecteur + bouton plein écran (`CourseDocumentViewer`, `8346-8360`).
    private func documentFrame(document: CtdStoredCourseDocument) -> some View {
        ZStack(alignment: .topTrailing) {
            CtdDocumentViewer(
                uri: document.uri,
                mimeType: document.mimeType,
                revision: document.uploadedAt
            )
            CtdFullscreenButton { fullscreenOpen = true }
        }
    }

    // MARK: - Import / remplacement / suppression

    /// Bouton d'import initial (`Télécharger mon cours`).
    private var uploadButton: some View {
        Button {
            pickerVisible = true
        } label: {
            HStack(spacing: 8) {
                IonIcon(name: "cloud-upload-outline", size: 20, color: Theme.surface)
                Text(uploadPending ? "Import en cours…" : "Télécharger mon cours")
                    .font(.system(size: 15, weight: .heavy))
            }
            .frame(maxWidth: .infinity, minHeight: 52)
        }
        .buttonStyle(DuelloPrimaryButton())
        .disabled(uploadPending)
        .accessibilityLabel("Importer mon cours en PDF, JPEG ou PNG")
    }

    /// Bouton de remplacement (`Remplacer le document`, `8438`).
    private var replaceButton: some View {
        Button {
            pickerVisible = true
        } label: {
            HStack(spacing: 8) {
                IonIcon(name: "refresh-outline", size: 17, color: Theme.ink)
                Text(uploadPending ? "Import en cours…" : "Remplacer le document")
                    .font(.system(size: 14, weight: .bold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusMedium)
                    .stroke(Theme.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(uploadPending || deletePending)
        .accessibilityLabel("Remplacer le document du cours")
    }

    /// Bouton de suppression (`Supprimer le document`, `confirmCourseDocumentDeletion`).
    private var deleteButton: some View {
        Button {
            alert = .confirmDeletion
        } label: {
            HStack(spacing: 8) {
                IonIcon(name: "trash-outline", size: 17, color: Color(hex: 0xA31616))
                Text(deletePending ? "Suppression en cours…" : "Supprimer le document")
                    .font(.system(size: 14, weight: .bold))
            }
            .foregroundStyle(Color(hex: 0xA31616))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusMedium)
                    .stroke(Theme.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(uploadPending || deletePending)
        .accessibilityLabel("Supprimer le document du cours")
    }

    /// Fichier choisi : l'annulation reste silencieuse, l'échec de copie et le
    /// format refusé préviennent l'élève (`uploadCourseDocument`).
    private func handlePickedFile(_ result: Result<[URL], Error>) {
        switch result {
        case .failure:
            return
        case .success(let urls):
            guard let url = urls.first else { return }
            uploadCourseDocument(from: url)
        }
    }

    /// `uploadCourseDocument` : copie le fichier sous `duello-courses` (URI
    /// unique par import, `compte-chapitre-date`), expose le document, réarme
    /// le repère et range les métadonnées.
    private func uploadCourseDocument(from url: URL) {
        guard !uploadPending else { return }
        uploadPending = true
        defer { uploadPending = false }
        let name = url.lastPathComponent
        guard let mimeType = CtdMimeType(declared: nil, fileName: name) else {
            alert = .importFailed
            return
        }
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else {
            alert = .importFailed
            return
        }
        let directory = TrainCourseDocument.importsDirectory()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let uploadedAt = TrainChapterFlashcards.now()
        let accountId = session.session?.publicId ?? "local"
        let fileName = "\(accountId)-\(chapter.id)-\(Int(uploadedAt)).\(mimeType.fileExtension)"
        let destination = directory.appendingPathComponent(fileName)
        do {
            try data.write(to: destination)
        } catch {
            alert = .importFailed
            return
        }
        // Réinitialiser l'ancien repère avant d'exposer le nouveau document.
        positioning = false
        positionDraft = 0
        // Un nouveau document périme l'index de connaissances du précédent.
        TrainCourseKnowledge.remove(year: programYear, chapterId: chapter.id)
        knowledgeIndex = nil
        knowledgeError = nil
        let stored = CtdStoredCourseDocument(
            uri: destination.absoluteString,
            name: name,
            mimeType: mimeType,
            size: Double(data.count),
            uploadedAt: uploadedAt,
            classProgress: nil
        )
        document = stored
        TrainCourseDocument.save(stored, year: programYear, chapterId: chapter.id)
        onClose?()
    }

    /// `deleteCourseDocument` : supprime métadonnées + fichier importé.
    private func deleteCourseDocument() {
        guard let target = document, !deletePending else { return }
        deletePending = true
        defer { deletePending = false }
        TrainCourseDocument.remove(year: programYear, chapterId: chapter.id)
        TrainCourseDocument.removeFile(uri: target.uri)
        TrainCourseKnowledge.remove(year: programYear, chapterId: chapter.id)
        document = nil
        knowledgeIndex = nil
        knowledgeError = nil
        fullscreenOpen = false
        positioning = false
        positionDraft = 0
    }

    // MARK: - Alertes

    private var alertTitle: String {
        switch alert {
        case .confirmDeletion: return "Supprimer le document ?"
        case .importFailed: return "Cours non importé"
        case .deleteFailed: return "Suppression impossible"
        case nil: return ""
        }
    }

    private var alertBinding: Binding<Bool> {
        Binding(
            get: { alert != nil },
            set: { if !$0 { alert = nil } }
        )
    }

    @ViewBuilder
    private var alertButtons: some View {
        switch alert {
        case .confirmDeletion:
            Button("Annuler", role: .cancel) { alert = nil }
            Button("Supprimer", role: .destructive) {
                alert = nil
                deleteCourseDocument()
            }
        case .importFailed, .deleteFailed, nil:
            Button("OK", role: .cancel) { alert = nil }
        }
    }
}

/// Onglets de la page « Mon cours » (`coursePage` + `flashcardPanel`) :
/// « Lire », puis les trois sections de cartes.
enum TrainCoursePageTab: String, CaseIterable, Identifiable {
    case lire
    case generate
    case create
    case review

    var id: String { rawValue }

    var label: String {
        switch self {
        case .lire: return "Lire"
        case .generate: return "Générer"
        case .create: return "Créer"
        case .review: return "Réviser"
        }
    }

    var ionName: String {
        switch self {
        case .lire: return "book-outline"
        case .generate: return "sparkles-outline"
        case .create: return "add-outline"
        case .review: return "play-outline"
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .lire: return "Lire mon cours"
        case .generate: return "Générer les flashcards"
        case .create: return "Créer une flashcard"
        case .review: return "Réviser mes flashcards"
        }
    }

    /// Onglet de cartes correspondant (`nil` pour « Lire »).
    var flashcardPanel: TrainFlashcardPanelTab? {
        switch self {
        case .lire: return nil
        case .generate: return .generate
        case .create: return .create
        case .review: return .review
        }
    }
}

/// Alertes de la page « Mon cours », libellés Expo mot pour mot.
enum TrainCourseAlert: Equatable {
    case confirmDeletion
    case importFailed
    case deleteFailed

    var message: String {
        switch self {
        case .confirmDeletion:
            return "Le document et son repère seront supprimés. Tes flashcards et tes notes seront conservées."
        case .importFailed:
            return "Choisis un fichier PDF, JPEG ou PNG lisible, puis réessaie."
        case .deleteFailed:
            return "Le document n’a pas pu être supprimé. Réessaie dans un instant."
        }
    }
}

/// Lecteur plein écran de la page « Mon cours » (`courseFullscreenOpen`) :
/// en-tête blanc 54, bouton réduire, lecteur sur toute la hauteur restante.
struct TrainCourseFullscreen: View {
    let document: CtdStoredCourseDocument
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer(minLength: 0)
                Button(action: onClose) {
                    IonIcon(name: "contract-outline", size: 24, color: Theme.ink)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Réduire le cours")
            }
            .padding(.trailing, 8)
            .frame(minHeight: 54)
            .background(Theme.surface)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Theme.border).frame(height: 1)
            }
            CtdDocumentViewer(
                uri: document.uri,
                mimeType: document.mimeType,
                revision: document.uploadedAt,
                height: .infinity
            )
        }
        .background(Theme.surfaceMuted)
    }
}
