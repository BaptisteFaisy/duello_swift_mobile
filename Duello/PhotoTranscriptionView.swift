import SwiftUI
import UIKit
import PhotosUI
import Photos
import AVFoundation

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

// MARK: - Libellés

/// Chaînes exactes de `photoTranscriptionLabels.ts` et des étapes Expo.
enum PhotoTxText {
    static let close = "Fermer", dismissHandle = "Faire descendre pour fermer"
    static let questionTab = "La question", exerciseTab = "L’exercice entier"
    static let takePhoto = "Prendre une photo", chooseImages = "Choisir des images"
    static let readingSingle = "Analyse de la photo en cours…"
    static let reviewHint = "Relis et corrige : c’est ce texte que l’IA comparera."
    static let restart = "Reprendre", insert = "Insérer", transcribedLabel = "Texte transcrit"
    static let emptyText = "Rien n’a été reconnu sur cette photo."
    static let cameraPermission = "Autorise l’appareil photo pour numériser ta copie."
    static let libraryPermission = "Autorise l’accès aux photos pour importer une image."
    static let photoUnavailable = "La photo n’a pas pu être récupérée. Réessaie."
    static let reviewNotice = "Certaines formules restent incertaines. Compare-les attentivement avec la photo."
    /// `usePhotoTranscriptionController.ts:230` : refus du consentement au partage avec l'IA.
    static let photoNotSent = "La photo n’a pas été transmise."
    /// Repli littéral de `openAIModelLabel` dans la source.
    static let unknownModel = "[OI]", premiumFallback = "Transcription premium"
    /// Port fidèle de `premiumSourceLabel` : toutes les branches, chaîne de repli comprise.
    static func premiumSourceLabel(engine: String?, model: String?) -> String {
        let trimmed = model?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let openAI = model == "gpt-5.6-sol" ? "GPT-5.6 Sol" : (trimmed.isEmpty ? unknownModel : trimmed)
        switch engine ?? "" {
        case "openai-vision": return "\(openAI) · vision et LaTeX"
        case "mathpix+zai": return "Mathpix + z.ai · LaTeX"
        case "mathpix": return "Mathpix · LaTeX"
        case "mathpix+claude-vision": return "Mathpix + contrôle visuel · LaTeX"
        case "claude-vision": return "Claude Vision · LaTeX"
        default: return premiumFallback
        }
    }
}

// MARK: - Types d'état

/// Étapes portées de `PhotoTranscriptionStage`. L'étape `remote` de la source
/// (photo prise depuis un téléphone connecté) est web uniquement : non portée.
enum PhotoTxStage { case capture, reading, review }
/// Portée de la capture (`PhotoCaptureScope`).
enum PhotoTxScope { case question, exercise }
/// Sélecteur employé pour récupérer la photo.
enum PhotoTxSource { case camera, library }
/// Avancement de la lecture (`readingProgress`).
struct PhotoTxProgress { var current: Int; var total: Int }

/// État de la feuille (`PhotoTranscriptionViewState`).
struct PhotoTxState {
    var stage: PhotoTxStage = .capture
    var scope: PhotoTxScope = .question
    var imageUris: [String] = []
    var readingProgress = PhotoTxProgress(current: 0, total: 0)
    var text = ""
    var engine: String?
    var model: String?
    var notice = ""
    var error = ""
}

/// Actions de la feuille, toutes portées par un unique `dispatch`.
enum PhotoTxAction {
    /// Sélection puis envoi : `images` porte la sélection (vide si échec), `failure`
    /// le message exact à afficher le cas échéant.
    case pickPhoto(from: PhotoTxSource, scope: PhotoTxScope, images: [UIImage], failure: String?)
    case insert
    case setCaptureScope(PhotoTxScope)
    case setText(String)
    case restart
}

// MARK: - Relais premium

/// Réponse du relais (`RelayResponse` de `mathOcr.ts`).
struct PhotoTxRelayResponse: Decodable { let text: String; let source: String?; let model: String?; let needsReview: Bool }

/// Relais premium (`POST relay/transcribe-photo`). La source résout ce chemin via
/// `resolveRelayEndpoint` (`utils/relayEndpoint.ts`) : `${DUELLO_API_URL}/relay`,
/// soit `DuelloAPI.baseURL` suivi de `relay`. **Seul `DuelloAPI.request` est
/// utilisé.** L'image est relue sur disque puis réencodée en JPEG base64
/// (`UIImage.jpegData(compressionQuality:)`), comme `preparePremiumImage` côté Expo.
private enum PhotoTxRelay {
    static func transcribe(uris: [String], subject: String, exercise: String?, mode: String, pageNumber: Int?, pageCount: Int, token: String?, questionLabels: [String]? = nil) async throws -> PhotoTxRelayResponse {
        var images: [[String: Any]] = []
        for uri in uris {
            guard let data = FileManager.default.contents(atPath: uri), let image = UIImage(data: data),
                  let jpeg = image.jpegData(compressionQuality: 0.88) else {
                throw DirectoryError(message: PhotoTxText.photoUnavailable)
            }
            images.append(["image": jpeg.base64EncodedString(), "mimeType": "image/jpeg"])
        }
        var body: [String: Any] = ["action": "transcribe-photo", "subject": subject,
                                   "transcriptionMode": mode, "pageCount": pageCount]
        if let exercise, !exercise.isEmpty { body["exercise"] = exercise }
        if let pageNumber { body["pageNumber"] = pageNumber }
        if mode == "full-exercise", let questionLabels { body["questionLabels"] = questionLabels }
        if mode == "full-exercise" { body["images"] = images } else {
            body["image"] = images.first?["image"] as? String ?? ""
            body["mimeType"] = "image/jpeg"
        }
        let payload = try JSONSerialization.data(withJSONObject: body, options: [])
        do {
            return try await DuelloAPI.request(PhotoTxRelayResponse.self, "relay/transcribe-photo",
                                               method: "POST", token: token, body: payload)
        } catch let error as DirectoryError where error.status == 401 || error.status == 403 {
            throw DirectoryError(message: "accès premium refusé")
        }
    }
}

// MARK: - Contrôleur

/// Port de `usePhotoTranscriptionController` : une seule action d'entrée.
final class PhotoTxController: ObservableObject {
    @Published var state = PhotoTxState()
    /// `photoTranscriptionAllowed` : vrai tant que la fenêtre de consentement au
    /// partage avec l'IA attend une réponse. Présentée par la vue
    /// (`PhotoTranscriptionView`) via `.alert`.
    @Published var consentVisible = false
    /// Jeton de session Duello, injecté par la vue (`SessionStore`) : il authentifie
    /// l'appel au relais premium.
    var token: String?
    private let subject: String
    private let exercise: String?
    private let onInsert: (String) -> Void
    private let onClose: () -> Void
    var exerciseWiring = PhotoTxExerciseWiring()
    private var task: Task<Void, Never>?
    /// Sélection mémorisée pendant que le consentement est demandé : rejouée dès
    /// l'accord obtenu, comme la promesse `requestAiDataSharingConsent` de la source.
    private var pendingPick: (() -> Void)?
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
            // `photoTranscriptionAllowed` : l'envoi au relais exige l'accord de
            // partage avec l'IA. Sans accord enregistré, la fenêtre est présentée
            // d'abord ; la sélection est rejouée après acceptation.
            guard CtdAiConsent.isGranted else {
                pendingPick = { [weak self] in
                    self?.dispatch(.pickPhoto(from: from, scope: scope, images: images, failure: failure))
                }
                consentVisible = true
                return
            }
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

    /// Réponse à la fenêtre de consentement (`photoTranscriptionAllowed`) : accord
    /// → l'accord est enregistré puis la sélection est rejouée ; refus → la notice
    /// exacte de la source, sans transmission.
    func resolveConsent(granted: Bool) {
        consentVisible = false
        let resume = pendingPick
        pendingPick = nil
        guard granted else {
            state.error = ""
            state.notice = PhotoTxText.photoNotSent
            return
        }
        CtdAiConsent.grant()
        resume?()
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

// MARK: - Sélecteur d'appareil photo

/// Appareil photo (`ImagePicker.launchCameraAsync`) encapsulé dans
/// `UIImagePickerController`. La présentation exige la clé `NSCameraUsageDescription`
/// dans `Info.plist`. Sur un appareil sans appareil photo — le simulateur, par
/// exemple — l'appelant n'ouvre pas ce sélecteur et affiche « La photo n’a pas pu
/// être récupérée. Réessaie. ».
struct PhotoTxCameraPicker: UIViewControllerRepresentable {
    let onPick: (UIImage) -> Void
    let onCancel: () -> Void
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let controller = UIImagePickerController()
        controller.sourceType = .camera
        controller.delegate = context.coordinator
        return controller
    }
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick, onCancel: onCancel) }
    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        private let onPick: (UIImage) -> Void
        private let onCancel: () -> Void
        init(onPick: @escaping (UIImage) -> Void, onCancel: @escaping () -> Void) {
            self.onPick = onPick
            self.onCancel = onCancel
        }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            guard let image = info[.originalImage] as? UIImage else { onCancel(); return }
            onPick(image)
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { onCancel() }
    }
}

// MARK: - Étape de capture

/// Port de `PhotoCaptureStage.tsx` : portée puis prise de vue ou import. Le panneau
/// `remote` (téléphone connecté) n'est pas porté : jamais atteint sur iOS.
struct PhotoTxCaptureStage: View {
    @ObservedObject var controller: PhotoTxController
    @State private var isCameraPresented = false
    @State private var isLibraryPresented = false
    @State private var libraryItems: [PhotosPickerItem] = []
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            scopeTabs
            captureButtons
            if !controller.state.error.isEmpty {
                // `error` : 11pt gras 700, `colors.danger` (encre #0A0D0C).
                Text(controller.state.error)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.danger)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 12)
            }
            if !controller.state.notice.isEmpty {
                // `notice` : 10pt gras 700, `colors.inkSoft` (refus du consentement IA).
                Text(controller.state.notice)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Theme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 10)
            }
        }
        .sheet(isPresented: $isCameraPresented) {
            PhotoTxCameraPicker(
                onPick: { image in
                    isCameraPresented = false
                    controller.dispatch(.pickPhoto(from: .camera, scope: controller.state.scope, images: [image], failure: nil))
                },
                onCancel: { isCameraPresented = false }
            )
        }
        .photosPicker(isPresented: $isLibraryPresented, selection: $libraryItems, maxSelectionCount: 24, matching: .images)
        .onChange(of: libraryItems) { items in
            guard !items.isEmpty else { return }
            Task {
                var images: [UIImage] = []
                for item in items {
                    if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) { images.append(image) }
                }
                libraryItems = []
                controller.dispatch(.pickPhoto(from: .library, scope: controller.state.scope, images: images,
                                               failure: images.isEmpty ? PhotoTxText.photoUnavailable : nil))
            }
        }
    }

    /// Libellé de portée employé par les étiquettes d'accessibilité de la source
    /// (`PhotoCaptureStage.tsx:90,99`).
    private var scopeLabel: String {
        controller.state.scope == .question ? PhotoTxText.questionTab : PhotoTxText.exerciseTab
    }

    /// `captureTabs` + `CaptureTab` : deux onglets pleine largeur, le sélectionné
    /// souligné d'une ligne `primary` de 2pt, la rangée bordée de 1pt (`border`).
    private var scopeTabs: some View {
        HStack(spacing: 0) {
            scopeTab(PhotoTxText.questionTab, scope: .question)
            scopeTab(PhotoTxText.exerciseTab, scope: .exercise)
        }
        .background(alignment: .bottom) {
            Rectangle().fill(Theme.border).frame(height: 1)
        }
    }

    private func scopeTab(_ title: String, scope: PhotoTxScope) -> some View {
        let selected = controller.state.scope == scope
        return Button {
            controller.dispatch(.setCaptureScope(scope))
        } label: {
            VStack(spacing: 0) {
                Text(title)
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(selected ? Theme.primary : Theme.inkSoft)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 44)
                Rectangle()
                    .fill(selected ? Theme.primary : Color.clear)
                    .frame(height: 2)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }

    /// Les deux voies de capture (`captureActions` : rangée, gap 10, marginTop 12).
    /// Sans appareil photo (le simulateur, par exemple) ou sans autorisation, la
    /// source remonte le message exact plutôt que d'ouvrir un sélecteur qui ne
    /// rendrait rien.
    private var captureButtons: some View {
        HStack(spacing: 10) {
            Button { startCamera() } label: {
                HStack(spacing: 8) {
                    IonIcon(name: "camera", size: 19, color: Theme.surface)
                    Text(PhotoTxText.takePhoto)
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundStyle(Theme.surface)
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: 50)
                .background(Theme.primary)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(scopeLabel) : prendre une photo")
            Button { startLibrary() } label: {
                HStack(spacing: 8) {
                    IonIcon(name: "images-outline", size: 18, color: Theme.primary)
                    Text(PhotoTxText.chooseImages)
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundStyle(Theme.primary)
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: 50)
                .background(Theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.primary, lineWidth: 1.5))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(scopeLabel) : choisir des images")
        }
        .padding(.top, 12)
    }

    private func startCamera() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        if !UIImagePickerController.isSourceTypeAvailable(.camera) {
            controller.dispatch(.pickPhoto(from: .camera, scope: controller.state.scope, images: [], failure: PhotoTxText.photoUnavailable))
        } else if status == .denied || status == .restricted {
            controller.dispatch(.pickPhoto(from: .camera, scope: controller.state.scope, images: [], failure: PhotoTxText.cameraPermission))
        } else {
            isCameraPresented = true
        }
    }

    private func startLibrary() {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if status == .denied || status == .restricted {
            controller.dispatch(.pickPhoto(from: .library, scope: controller.state.scope, images: [], failure: PhotoTxText.libraryPermission))
        } else {
            isLibraryPresented = true
        }
    }
}

// MARK: - Étape de lecture

/// Port de `PhotoReadingStage.tsx` : aperçu de la dernière image et avancement.
/// `readingCard` : colonne centrée, gap 12, marges 22/12, **sans fond de carte** ;
/// l'aperçu fait 100 % × 160, rayon `large` (18), fond `surfaceMuted`.
struct PhotoTxReadingStage: View {
    let imageUris: [String]
    let progress: PhotoTxProgress
    private var previewSource: CachedImageSource? {
        let index = max(0, progress.current - 1)
        guard imageUris.indices.contains(index) else { return nil }
        return .file(imageUris[index])
    }
    var body: some View {
        VStack(spacing: 12) {
            if let source = previewSource {
                CachedImage(source) { image in
                    image.resizable().scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 160)
                        .background(Theme.surfaceMuted)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLarge))
                } placeholder: {
                    EmptyView()
                }
            }
            ProgressView().tint(Theme.primary)
            Text(progress.total > 1 ? "Analyse des images \(progress.current)/\(progress.total)…" : PhotoTxText.readingSingle)
                .font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 22)
        .padding(.bottom, 12)
    }
}

// MARK: - Étape de relecture

/// Port de `PhotoReviewStage.tsx` : vignette, badge de source, texte éditable,
/// puis reprise ou insertion.
struct PhotoTxReviewStage: View {
    @ObservedObject var controller: PhotoTxController
    private var state: PhotoTxState { controller.state }
    private var hasText: Bool { !state.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    /// `containsMultilineMatrix || containsCodeBlock` : bascule l'éditeur en police
    /// monospace (`matrixTextInput`, Menlo).
    private var isMonospace: Bool {
        StmtLatex.containsMultilineMatrix(state.text) || StmtAnswerSupport.containsCodeBlock(state.text)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            if !state.notice.isEmpty {
                Text(state.notice)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Theme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 10)
            }
            editor
            actions
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    /// `reviewHeader` : rangée alignée au centre, gap 12, marginTop 16 ; vignette
    /// 58×58 rayon `medium` ; badge `sparkles` 12 `primary` sur `primaryLight`.
    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            if let first = state.imageUris.first {
                CachedImage(.file(first)) { image in
                    image.resizable().scaledToFill()
                        .frame(width: 58, height: 58)
                        .background(Theme.surfaceMuted)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
                } placeholder: {
                    EmptyView()
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                sourceBadge
                if state.imageUris.count > 1 {
                    Text("\(state.imageUris.count) images analysées")
                        .font(.system(size: 10, weight: .heavy)).foregroundStyle(Theme.inkSoft)
                }
                Text(PhotoTxText.reviewHint)
                    .font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.top, 16)
    }
    /// `sourceBadge` : icône 12 + texte 9 (900) en `primary`, fond `primaryLight`,
    /// pastille. Le libellé n'est **pas** mis en capitales (contrairement à une puce).
    private var sourceBadge: some View {
        HStack(spacing: 5) {
            IonIcon(name: "sparkles", size: 12, color: Theme.primary)
            Text(PhotoTxText.premiumSourceLabel(engine: state.engine, model: state.model))
                .font(.system(size: 9, weight: .black)).foregroundStyle(Theme.primary)
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 9)
        .background(Theme.primaryLight)
        .clipShape(Capsule())
    }
    /// `textCard` : maxHeight 210, marginTop 13, bord `border` 1.5, rayon `medium`,
    /// fond `surfaceMuted` ; `textInput` : minHeight 140, padding 13, 13/500.
    private var editor: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: Binding(get: { state.text }, set: { controller.dispatch(.setText($0)) }))
                .font(isMonospace
                      ? .system(size: 13, weight: .medium, design: .monospaced)
                      : .system(size: 13, weight: .medium))
                .foregroundStyle(Theme.ink)
                .scrollContentBackground(.hidden)
                .padding(13)
                .frame(minHeight: 140)
                .accessibilityLabel(PhotoTxText.transcribedLabel)
            if state.text.isEmpty {
                Text(PhotoTxText.emptyText).font(.system(size: 13)).foregroundStyle(Theme.inkFaint)
                    .padding(.top, 21).padding(.leading, 18).allowsHitTesting(false)
            }
        }
        .frame(maxHeight: 210)
        .background(Theme.surfaceMuted)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
        .overlay(RoundedRectangle(cornerRadius: Theme.radiusMedium).stroke(Theme.border, lineWidth: 1.5))
        .padding(.top, 13)
    }
    /// `reviewActions` : rangée, gap 10, marginTop 14 ; « Reprendre » = secondaire
    /// (`refresh` 17 primary sur fond `surface`, bord `primary` 1.5) ; « Insérer » =
    /// primaire (`arrow-down` 17 blanc, fond `primary`, désactivé à 0.4).
    private var actions: some View {
        HStack(spacing: 10) {
            Button { controller.dispatch(.restart) } label: {
                HStack(spacing: 8) {
                    IonIcon(name: "refresh", size: 17, color: Theme.primary)
                    Text(PhotoTxText.restart)
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundStyle(Theme.primary)
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: 50)
                .background(Theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.primary, lineWidth: 1.5))
            }
            .buttonStyle(.plain)
            Button { controller.dispatch(.insert) } label: {
                HStack(spacing: 8) {
                    IonIcon(name: "arrow-down", size: 17, color: Theme.surface)
                    Text(PhotoTxText.insert)
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundStyle(Theme.surface)
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: 50)
                .background(Theme.primary)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)
            .disabled(!hasText).opacity(hasText ? 1 : 0.4)
        }
        .padding(.top, 14)
    }
}

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
