//
//  PhotoTranscriptionModels.swift
//  Duello
//
//  Libellés, types d'état et relais premium de la transcription photo.
//  Découpage de `PhotoTranscriptionView.swift` — aucun changement de comportement
//  (mêmes noms, mêmes corps, mêmes chaînes, mêmes visibilités EFFECTIVES).
//

import Foundation
import UIKit

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

/// Étapes portées de `PhotoTranscriptionStage`. L'étape `remote` (photo prise
/// depuis un téléphone connecté, `PhotoCaptureStage.tsx:69`) n'est atteinte que
/// sur le web côté RN (`Platform.OS === 'web'`) : sur iOS l'app est le téléphone,
/// l'étape reste donc **inerte** ici, mais elle est portée pour la parité.
enum PhotoTxStage { case capture, remote, reading, review }
/// Portée de la capture (`PhotoCaptureScope`).
enum PhotoTxScope { case question, exercise }
/// Sélecteur employé pour récupérer la photo (`Equatable` : observé par l'étape de
/// capture pour ouvrir le sélecteur après l'accord de partage IA).
enum PhotoTxSource: Equatable { case camera, library }
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
/// utilisé**, avec le délai de l'OCR (`RELAY_TIMEOUT_MS` = 180 s, `mathOcr.ts:76`).
/// L'image est relue sur disque puis réencodée en JPEG base64
/// (`UIImage.jpegData(compressionQuality:)`), comme `preparePremiumImage` côté Expo.
///
/// `private` retiré lors du déplacement dans ce fichier : `private` en Swift a la
/// portée du FICHIER, le type déplacé perdrait son accès. Visibilité élargie à
/// `internal` (visibilité EFFECTIVE inchangée pour l'app : un seul module) ; corps
/// et signature inchangés.
enum PhotoTxRelay {
    static func transcribe(uris: [String], subject: String, exercise: String?, mode: String, pageNumber: Int?, pageCount: Int, token: String?, questionLabels: [String]? = nil) async throws -> PhotoTxRelayResponse {
        // `mathOcr.ts:249,285-296` : chaque image passe par `preparePremiumImage`,
        // qui la compresse sous le budget. Une seule page vise
        // `MATHPIX_BASE64_TARGET_BYTES` (1,8 Mo) ; l'exercice entier répartit
        // `FULL_EXERCISE_BASE64_TARGET_BYTES` (18 Mio) sur ses pages, plafonné au
        // budget par image (`targetPerImage = min(1,8 Mo, 18 Mio / n)`).
        let targetPerImage = mode == "full-exercise"
            ? min(PhotoTxPremiumImage.mathpixBase64TargetBytes,
                  PhotoTxPremiumImage.fullExerciseBase64TargetBytes / max(uris.count, 1))
            : PhotoTxPremiumImage.mathpixBase64TargetBytes
        var images: [[String: Any]] = []
        for uri in uris {
            guard let data = FileManager.default.contents(atPath: uri), let image = UIImage(data: data) else {
                throw DirectoryError(message: PhotoTxText.photoUnavailable)
            }
            let base64 = try PhotoTxPremiumImage.preparePremiumImage(image, targetBytes: targetPerImage)
            images.append(["image": base64, "mimeType": "image/jpeg"])
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
            // `RELAY_TIMEOUT_MS` (`mathOcr.ts:76`) : l'OCR à effort maximal peut
            // durer deux minutes ; le délai par défaut (10 s) couperait l'appel.
            return try await DuelloAPI.request(PhotoTxRelayResponse.self, "relay/transcribe-photo",
                                               method: "POST", token: token, body: payload,
                                               timeout: TimeInterval(PhotoTxPremiumImage.relayTimeoutMs) / 1000)
        } catch let error as DirectoryError where error.status == 401 || error.status == 403 {
            throw DirectoryError(message: "accès premium refusé")
        }
    }
}
