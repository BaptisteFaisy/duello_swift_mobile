//
//  PhotoTxController.swift
//  Duello
//
//  Contrôleur de la transcription photo (`usePhotoTranscriptionController`).
//  Découpage de `PhotoTranscriptionView.swift` — aucun changement de comportement
//  (mêmes noms, mêmes corps, mêmes chaînes, mêmes visibilités EFFECTIVES).
//

import SwiftUI
import UIKit

// MARK: - Contrôleur

/// Port de `usePhotoTranscriptionController` : une seule action d'entrée.
final class PhotoTxController: ObservableObject {
    @Published var state = PhotoTxState()
    /// `photoTranscriptionAllowed` : vrai tant que la fenêtre de consentement au
    /// partage avec l'IA attend une réponse. Présentée par la vue
    /// (`PhotoTranscriptionView`) via `.alert`.
    @Published var consentVisible = false
    /// Sélecteur à ouvrir dès l'accord obtenu : `photoTranscriptionAllowed` est
    /// évalué **avant** le sélecteur (`usePhotoTranscriptionController.ts:240`),
    /// la source est donc mémorisée puis rejouée. La vue l'observe pour ouvrir
    /// la caméra ou la photothèque.
    @Published var selecteurDemande: PhotoTxSource?
    /// Source mémorisée pendant que la fenêtre de consentement attend une réponse.
    private var sourceEnAttente: PhotoTxSource?
    /// Jeton de session Duello, injecté par la vue (`SessionStore`) : il authentifie
    /// l'appel au relais premium.
    var token: String?
    private let subject: String
    private let exercise: String?
    private let onInsert: (String) -> Void
    private let onClose: () -> Void
    var exerciseWiring = PhotoTxExerciseWiring()
    private var task: Task<Void, Never>?
    init(subject: String, exercise: String?, onInsert: @escaping (String) -> Void, onClose: @escaping () -> Void) {
        self.subject = subject
        self.exercise = exercise
        self.onInsert = onInsert
        self.onClose = onClose
    }
    deinit { task?.cancel() }
    func dispatch(_ action: PhotoTxAction) {
        switch action {
        case let .pickPhoto(from, scope, images, failure):
            // `photoTranscriptionAllowed` : l'accord de partage est désormais
            // demandé **avant** d'ouvrir le sélecteur (`autoriserCapture`) ; la
            // sélection arrive donc toujours autorisée.
            task?.cancel()
            task = nil
            state.error = ""
            state.notice = ""
            if let failure {
                state.error = failure
                state.stage = .capture
                return
            }
            guard !images.isEmpty else { return }
            state.scope = scope
            state.text = ""
            var uris: [String] = []
            for image in images {
                guard let data = image.jpegData(compressionQuality: 0.9) else { continue }
                let url = FileManager.default.temporaryDirectory.appendingPathComponent("duello-photo-\(UUID().uuidString).jpg")
                guard (try? data.write(to: url)) != nil else { continue }
                uris.append(url.path)
            }
            guard !uris.isEmpty else { state.error = PhotoTxText.photoUnavailable; return }
            state.imageUris = uris
            state.readingProgress = PhotoTxProgress(current: 0, total: uris.count)
            state.stage = .reading
            task = Task { @MainActor in await self.sendPhotos(uris, scope: scope) }
        case .insert:
            let clean = state.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !clean.isEmpty else { return }
            if state.scope == .exercise, exerciseWiring.insert(clean) { onClose(); return }
            onInsert(clean)
            onClose()
        case let .setCaptureScope(scope): state.scope = scope
        case let .setText(text): state.text = text
        case .restart: state.stage = .capture
        }
    }

    /// `photoTranscriptionAllowed` : l'accord de partage avec l'IA est évalué
    /// **avant** d'ouvrir le sélecteur (`usePhotoTranscriptionController.ts:240`,
    /// `photoTranscriptionAllowed` précède `collectPhotos`). Renvoie vrai si
    /// l'envoi est déjà autorisé — l'appelant ouvre alors le sélecteur ; sinon la
    /// fenêtre est présentée et la source mémorisée, ouverte après acceptation.
    func autoriserCapture(_ source: PhotoTxSource) -> Bool {
        if CtdAiConsent.isGranted { return true }
        sourceEnAttente = source
        consentVisible = true
        return false
    }

    /// Réponse à la fenêtre de consentement (`photoTranscriptionAllowed`) : accord
    /// → l'accord est enregistré puis le sélecteur mémorisé est demandé ; refus →
    /// la notice exacte de la source, sans transmission.
    func resolveConsent(granted: Bool) {
        consentVisible = false
        guard granted else {
            sourceEnAttente = nil
            state.error = ""
            state.notice = PhotoTxText.photoNotSent
            return
        }
        CtdAiConsent.grant()
        if let source = sourceEnAttente {
            sourceEnAttente = nil
            selecteurDemande = source
        }
    }

    /// Envoie les images au relais, publie l'avancement puis le texte reconnu. Un
    /// échec remonte l'erreur : aucune lecture locale n'est tentée.
    @MainActor
    private func sendPhotos(_ uris: [String], scope: PhotoTxScope) async {
        do {
            var engine: String?
            var model: String?
            var notice = ""
            var pieces: [String] = []
            if scope == .exercise {
                state.readingProgress = PhotoTxProgress(current: 0, total: uris.count)
                let result = try await PhotoTxRelay.transcribe(uris: uris, subject: subject, exercise: exercise,
                                                               mode: "full-exercise", pageNumber: nil,
                                                               pageCount: uris.count, token: token,
                                                               questionLabels: exerciseWiring.labels)
                pieces = [LatexToUnicode.toUnicodeMath(result.text).trimmingCharacters(in: .whitespacesAndNewlines)]
                engine = result.source
                model = result.model
                if result.needsReview { notice = PhotoTxText.reviewNotice }
            } else {
                for (index, uri) in uris.enumerated() {
                    state.readingProgress = PhotoTxProgress(current: index + 1, total: uris.count)
                    let result = try await PhotoTxRelay.transcribe(uris: [uri], subject: subject, exercise: exercise,
                                                                   mode: "question", pageNumber: index + 1,
                                                                   pageCount: uris.count, token: token)
                    let piece = LatexToUnicode.toUnicodeMath(result.text).trimmingCharacters(in: .whitespacesAndNewlines)
                    if !piece.isEmpty { pieces.append(piece) }
                    if index == 0 { engine = result.source; model = result.model }
                    if result.needsReview { notice = PhotoTxText.reviewNotice }
                }
            }
            guard !Task.isCancelled else { return }
            state.text = pieces.joined(separator: "\n\n")
            state.engine = engine; state.model = model; state.notice = notice
            state.stage = .review
        } catch {
            guard !Task.isCancelled else { return }
            let reason = (error as? LocalizedError)?.errorDescription?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let detail = reason.isEmpty ? "" : " (\(reason))"
            state.error = "La transcription IA est indisponible\(detail). Aucune lecture locale n’a été effectuée. Réessaie."
            state.stage = .capture
        }
    }
}
