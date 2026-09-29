import SwiftUI
import UniformTypeIdentifiers

// V3 2026-09-29 (complexité) : extension extraite de `TrainCoursePage.swift`.
// Lecteur (`CourseDocumentViewer`, `8346-8360`) + import / remplacement /
// suppression (`uploadCourseDocument` `5828`, `deleteCourseDocument`,
// `confirmCourseDocumentDeletion`). Les membres étaient `private` dans
// `TrainCoursePage.swift` ; `private` en Swift est limité au FICHIER, ils sont
// donc élargis à `internal` (corps inchangés).

extension TrainCoursePage {
    /// Lecteur + bouton plein écran (`CourseDocumentViewer`, `8346-8360`).
    ///
    /// U06#3 (R07) : le lecteur reçoit `positioning` / `initialPosition` /
    /// `onPositionChange`, comme la source (`SubjectsScreen.tsx:8391-8405`) : le
    /// repère se pose **en faisant défiler le cours** face à la ligne rouge, et
    /// chaque mouvement alimente le brouillon (`handleCoursePositionChange`). Le
    /// repère est relu à l'ouverture du document (`initialPosition`).
    func documentFrame(document: CtdStoredCourseDocument) -> some View {
        ZStack(alignment: .topTrailing) {
            CtdDocumentViewer(
                uri: document.uri,
                mimeType: document.mimeType,
                revision: document.uploadedAt,
                positioning: positioning,
                initialPosition: document.classProgress?.position,
                onPositionChange: { positionDraft = $0 }
            )
            CtdFullscreenButton { fullscreenOpen = true }
        }
    }

    /// Fichier choisi : l'annulation reste silencieuse, l'échec de copie et le
    /// format refusé préviennent l'élève (`uploadCourseDocument`).
    func handlePickedFile(_ result: Result<[URL], Error>) {
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
    func uploadCourseDocument(from url: URL) {
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
    func deleteCourseDocument() {
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
}
