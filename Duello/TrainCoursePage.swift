import SwiftUI
import UniformTypeIdentifiers

// V1 2026-09-26 (U06#3) : fichier neuf. Page « Mon cours » d'un chapitre
// (`selectedMode === 'cours'`, `SubjectsScreen.tsx:7942-8502`) : bouton de
// repère (`placeCourseProgress` `6069`), lecteur (`CourseDocumentViewer`),
// import/remplacement (`uploadCourseDocument` `5828`), suppression
// (`deleteCourseDocument` + `confirmCourseDocumentDeletion`).

/// Page « Mon cours » d'un chapitre : repère de progression, lecteur du
/// document importé, import/remplacement/suppression.
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

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            if !loaded {
                SubjDeferredInlineFallback(label: "Ouverture du cours…")
            } else if let document {
                positionBlock(document: document)
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

    // MARK: - Chargement

    /// Relecture du document à l'ouverture du chapitre.
    private func reload() {
        loaded = false
        positioning = false
        document = TrainCourseDocument.load(year: programYear, chapterId: chapter.id)
        positionDraft = document?.classProgress?.position ?? 0
        loaded = true
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
                Image(systemName: positioning ? "checkmark" : "location")
                    .font(.system(size: 18))
                    .foregroundStyle(positioning ? Theme.surface : Theme.ink)
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
            positionHint
        } else if let progress = document.classProgress {
            Text("Progression du cours enregistrée à \(Int((progress.position * 100).rounded())) %.")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var positionHint: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Fais défiler le cours jusqu’au dernier point vu en classe et place-le face au repère rouge. Le bouton ou le retour enregistrera cette position.")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
            Slider(value: $positionDraft, in: 0...1)
                .tint(Theme.ink)
                .accessibilityLabel("Position atteinte dans le cours")
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
                Image(systemName: "icloud.and.arrow.up")
                    .font(.system(size: 20))
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
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 17))
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
                Image(systemName: "trash")
                    .font(.system(size: 17))
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
        document = nil
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
                    Image(systemName: "arrow.down.right.and.arrow.up.left")
                        .font(.system(size: 24))
                        .foregroundStyle(Theme.ink)
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
