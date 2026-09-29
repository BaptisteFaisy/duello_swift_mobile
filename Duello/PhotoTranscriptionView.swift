import SwiftUI
import UIKit

/// Transcription d'une photo d'énoncé ou de copie — port de `PhotoTranscriptionModal.tsx`
/// et du dossier `src/components/photo-transcription/` (capture, lecture, relecture, libellés,
/// contrôleur), plus `src/utils/mathOcr.ts` (`transcribePhoto`).
///
/// La photo part vers le relais premium (`POST relay/transcribe-photo`), qui seul détient la clé :
/// une panne est remontée telle quelle, sans lecture locale de secours. L'étape `remote` (photo
/// prise depuis un téléphone connecté) est web uniquement, donc non portée. La présentation
/// (feuille, modale, plein écran) reste à la charge de l'appelant ; le **consentement au partage
/// avec l'IA** est désormais demandé par le contrôleur (`photoTranscriptionAllowed`,
/// `usePhotoTranscriptionController.ts:226-233`) avant tout envoi au relais.
///
/// Découpage (ratchet de complexité, sans changement de comportement) : libellés et types d'état
/// dans `PhotoTranscriptionModels.swift`, relais premium idem, contrôleur dans
/// `PhotoTxController.swift`, sélecteur photo dans `PhotoTxCameraPicker.swift`, étapes dans
/// `PhotoTxCaptureStage.swift` et `PhotoTxReviewStages.swift`.

// MARK: - Vue principale

/// Contenu de la feuille de transcription (`PhotoTranscriptionModal.tsx`). La
/// présentation — feuille, modale, plein écran — reste au parent. La poignée et la
/// fermeture suivent `handleArea`/`closeButton` (poignée 42×4, bouton 34×34).
struct PhotoTranscriptionView: View {
    let subject: String
    var exercisePrompt: String? = nil
    var onClose: () -> Void
    var onInsert: (String) -> Void
    @EnvironmentObject private var session: SessionStore
    @StateObject private var controller: PhotoTxController
    init(subject: String, exercisePrompt: String? = nil, exerciseQuestions: [PhotoExerciseQuestion] = [], onInsertExercise: (([String: String]) -> Void)? = nil, onClose: @escaping () -> Void, onInsert: @escaping (String) -> Void) {
        self.subject = subject
        self.exercisePrompt = exercisePrompt
        self.onClose = onClose
        self.onInsert = onInsert
        let controller = PhotoTxController(subject: subject, exercise: exercisePrompt, onInsert: onInsert, onClose: onClose)
        controller.exerciseWiring = PhotoTxExerciseWiring(questions: exerciseQuestions, onInsert: onInsertExercise)
        _controller = StateObject(wrappedValue: controller)
    }
    var body: some View {
        VStack(spacing: 0) {
            // Poignée de feuille : le geste de fermeture reste au parent, seule
            // l'étiquette « Faire descendre pour fermer » est portée ici.
            Capsule().fill(Theme.border).frame(width: 42, height: 4)
                .frame(maxWidth: .infinity, minHeight: 32, alignment: .top)
                .padding(.top, 3)
                .accessibilityLabel(PhotoTxText.dismissHandle)
            stage
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 22)
        .padding(.top, 8)
        .background(Theme.surface)
        .overlay(alignment: .topTrailing) {
            Button { onClose() } label: {
                IonIcon(name: "close", size: 22, color: Theme.ink)
                    .frame(width: 34, height: 34)
                    .background(Theme.surfaceMuted)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(PhotoTxText.close)
            .padding(.top, 8)
            .padding(.trailing, 12)
        }
        .onAppear { controller.token = session.token }
        // `photoTranscriptionAllowed` : l'accord de partage avec l'IA est demandé
        // avant tout envoi (`requestAiDataSharingConsent`).
        .alert(CtdAiConsent.title, isPresented: $controller.consentVisible) {
            Button(CtdAiConsent.denyLabel, role: .cancel) { controller.resolveConsent(granted: false) }
            Button(CtdAiConsent.allowLabel) { controller.resolveConsent(granted: true) }
        } message: {
            Text(CtdAiConsent.message)
        }
    }
    @ViewBuilder
    private var stage: some View {
        switch controller.state.stage {
        case .capture:
            PhotoTxCaptureStage(controller: controller)
        case .reading:
            PhotoTxReadingStage(imageUris: controller.state.imageUris, progress: controller.state.readingProgress)
        case .review:
            PhotoTxReviewStage(controller: controller)
        }
    }
}
