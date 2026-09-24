import SwiftUI
import UniformTypeIdentifiers

/// Panneau « Mon TD » d'un chapitre : import de la feuille, analyse IA,
/// indexation concours (théorèmes et hypothèses) et rendu du document.
///
/// Porté de `src/components/CourseTdPanel.tsx`, monté par `SubjectsScreen.tsx`
/// (page d'outil « td » du chapitre) avec le document de cours du chapitre.
/// Le lecteur de document vient de `CourseDocumentViewer.native.tsx` et
/// `HtmlDocumentView.native.tsx`. Le panneau Expo n'a ni bouton plein écran
/// ni modale : seul le lecteur est monté, avec le style `viewer`
/// (330 pt de haut, rayon moyen).
///
/// Le panneau ne possède pas le cours du chapitre : il le reçoit, et se
/// verrouille tant qu'il manque (`CtdLockedCard`). Comme côté Expo, il est
/// destiné à vivre dans une vue défilante.
struct CourseTdView: View {
    let chapterId: String
    let chapterName: String
    /// Document de cours du chapitre (`storedCourseDocument`) : c'est lui qui
    /// fournit à l'IA les théorèmes et les hypothèses du TD.
    let courseDocument: CtdStoredCourseDocument?

    @EnvironmentObject private var session: SessionStore
    @StateObject private var store = CtdDocumentStore()

    @State private var loaded = false
    @State private var importing = false
    @State private var analyzing = false
    @State private var errorMessage = ""
    @State private var pickerVisible = false
    @State private var pendingAnalysis: CtdPendingAnalysis?
    /// Numéro du dernier lancement d'analyse : le résultat d'un lancement
    /// remplacé est ignoré (`analysisRun` de `CourseTdPanel.tsx`).
    @State private var analysisRun = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            if !loaded {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(Theme.ink)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else if let course = courseDocument {
                panel(course: course)
            } else {
                CtdLockedCard()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .task(id: chapterId) { reload() }
        // `DocumentPicker.getDocumentAsync` : PDF, JPEG et PNG.
        .fileImporter(
            isPresented: $pickerVisible,
            allowedContentTypes: [.pdf, .jpeg, .png],
            allowsMultipleSelection: false,
            onCompletion: handlePickedFile
        )
    }

    // MARK: - Corps du panneau

    /// Panneau complet : le cours du chapitre est disponible.
    private func panel(course: CtdStoredCourseDocument) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            CtdPanelHeading()
            if let source = store.document.source {
                document(source: source)
            } else {
                CtdIntroCard(importing: importing, onImport: presentPicker)
            }
            if analyzing {
                CtdAnalysisProgressCard()
            }
            messages(course: course)
            if let analysis = store.document.analysis {
                CtdResultsSection(
                    analysis: analysis,
                    questionCount: store.document.questionCount
                )
            }
        }
    }

    /// Feuille importée : ligne de document puis lecteur.
    ///
    /// Le panneau Expo (`CourseTdPanel.tsx`, lignes 287-312) n'affiche ni
    /// bouton plein écran ni modale : le lecteur (330 pt) est le seul élément
    /// sous la ligne de fichier. `CtdFullscreenButton` et `CtdDocumentSheet`
    /// appartiennent à la section « Mon cours » de `SubjectsScreen.tsx`
    /// (lignes 8292-8410) : ils ont été retirés de ce panneau.
    @ViewBuilder
    private func document(source: CtdSource) -> some View {
        CtdFileRow(
            name: source.name,
            sizeLabel: CtdFormatters.fileSize(source.size),
            busy: importing || analyzing,
            onReplace: presentPicker
        )
        CtdDocumentViewer(
            uri: source.uri,
            mimeType: source.mimeType,
            revision: source.importedAt
        )
    }

    /// Cartes de message : erreur d'analyse et analyse périmée.
    @ViewBuilder
    private func messages(course: CtdStoredCourseDocument) -> some View {
        if !errorMessage.isEmpty {
            CtdMessageCard(
                message: errorMessage,
                actionTitle: store.document.source == nil ? nil : "Réessayer l’analyse",
                action: {
                    if let source = store.document.source {
                        runAnalysis(source, course: course)
                    }
                }
            )
        }
        if store.document.isStale(comparedTo: course),
           let source = store.document.source,
           !analyzing {
            CtdMessageCard(
                message: "Le cours a été remplacé depuis cette analyse. Relance l’indexation pour actualiser les théorèmes.",
                actionTitle: "Actualiser l’analyse",
                action: { runAnalysis(source, course: course) }
            )
        }
    }

    // MARK: - Chargement

    /// `useEffect([chapterId])` : la feuille est relue à chaque chapitre, et
    /// toute analyse en vol devient périmée.
    private func reload() {
        loaded = false
        errorMessage = ""
        analysisRun += 1
        store.load(chapterId: chapterId)
        loaded = true
    }

    // MARK: - Import

    /// `importTd` : ouvre le sélecteur de documents.
    private func presentPicker() {
        analysisRun += 1
        importing = true
        pickerVisible = true
    }

    /// Feuille choisie, copiée puis analysée. L'annulation du sélecteur reste
    /// silencieuse : seuls l'échec de copie et le format refusé préviennent
    /// l'élève, comme côté Expo.
    private func handlePickedFile(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(_):
            importing = false
        case .success(let urls):
            guard let url = urls.first else {
                importing = false
                return
            }
            importTd(from: url)
        }
    }

    /// `importTd` : copie le fichier sous `duello-td`, enregistre la feuille,
    /// puis lance l'analyse. La taille est contrôlée par le relais
    /// (`assertDocumentSize`), pas ici.
    private func importTd(from url: URL) {
        defer { importing = false }
        let name = url.lastPathComponent
        guard let mimeType = CtdMimeType(declared: nil, fileName: name) else {
            presentImportFailedAlert()
            return
        }
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else {
            presentImportFailedAlert()
            return
        }
        let directory = CtdStorage.importsDirectory()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let accountId = session.session?.publicId ?? "local"
        let destination = directory
            .appendingPathComponent("\(accountId)-\(chapterId).\(mimeType.fileExtension)")
        try? FileManager.default.removeItem(at: destination)
        do {
            try data.write(to: destination)
        } catch {
            presentImportFailedAlert()
            return
        }
        let source = CtdSource(
            uri: destination.absoluteString,
            name: name,
            mimeType: mimeType,
            size: Double(data.count),
            importedAt: Date().timeIntervalSince1970 * 1000
        )
        store.store(source: source, analysis: nil)
        guard let course = courseDocument else { return }
        runAnalysis(source, course: course)
    }

    // MARK: - Analyse

    /// `runAnalysis` : contrôle l'autorisation IA, puis interroge le relais.
    private func runAnalysis(_ source: CtdSource, course: CtdStoredCourseDocument) {
        guard CtdAiConsent.isGranted else {
            pendingAnalysis = CtdPendingAnalysis(source: source, course: course)
            presentConsentAlert()
            return
        }
        Task { await performAnalysis(source, course: course) }
    }

    /// `requireAiDataSharingConsent` : l'analyse transmet la feuille et le cours
    /// au relais, donc l'accord de l'élève est demandé d'abord. L'alerte passe par
    /// le composant partagé du kit (`AppAlert.alert`), jamais `.alert` natif —
    /// `showAiConsentPrompt` de `aiDataSharingConsent.ts` : deux boutons, refus
    /// (`cancel`) puis autorisation (primaire).
    private func presentConsentAlert() {
        AppAlert.alert(
            CtdAiConsent.title,
            CtdAiConsent.message,
            [
                AppAlertButton(CtdAiConsent.denyLabel, style: .cancel) {
                    resolveConsent(granted: false)
                },
                AppAlertButton(CtdAiConsent.allowLabel) {
                    resolveConsent(granted: true)
                },
            ]
        )
    }

    /// `Alert.alert('TD non importé', …)` : sans bouton, le kit pose le bouton
    /// unique « Compris » (défaut d'`AppAlert.alert`), comme côté Expo.
    private func presentImportFailedAlert() {
        AppAlert.alert(
            "TD non importé",
            "Choisis un PDF, une photo JPEG ou PNG de moins de 8 Mo, puis réessaie."
        )
    }

    /// Réponse à la demande d'autorisation IA : accordée, l'analyse attendue
    /// démarre (`requireAiDataSharingConsent`) ; refusée, elle n'est pas
    /// lancée et le refus est affiché (`declinedLabel`).
    private func resolveConsent(granted: Bool) {
        guard granted else {
            pendingAnalysis = nil
            errorMessage = CtdAiConsent.declinedLabel
            return
        }
        CtdAiConsent.grant()
        guard let pending = pendingAnalysis else { return }
        pendingAnalysis = nil
        Task { await performAnalysis(pending.source, course: pending.course) }
    }

    /// `analyzeCourseTd` : envoie la feuille au relais. Un lancement plus
    /// récent annule le résultat de celui-ci.
    @MainActor
    private func performAnalysis(_ source: CtdSource, course: CtdStoredCourseDocument) async {
        analysisRun += 1
        let run = analysisRun
        analyzing = true
        errorMessage = ""
        defer { if analysisRun == run { analyzing = false } }
        do {
            let analysis = try await CtdAnalysisService.analyze(
                source: source,
                course: course,
                chapterName: chapterName,
                token: session.token
            )
            guard analysisRun == run else { return }
            store.store(analysis: analysis)
        } catch {
            guard analysisRun == run else { return }
            errorMessage = CtdAnalysisService.message(for: error)
        }
    }
}

/// Demande d'analyse mise en attente de l'autorisation IA.
struct CtdPendingAnalysis {
    let source: CtdSource
    let course: CtdStoredCourseDocument
}
