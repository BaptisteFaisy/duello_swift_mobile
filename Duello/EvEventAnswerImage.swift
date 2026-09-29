//
//  EvEventAnswerImage.swift
//  Duello
//
//  Lot T06 (vague 4 « couche transverse ») — TR-06 : préparation d'image et
//  appel relais pour les réponses photo d'événement.
//
//  Fichier source Expo porté (contrat, budget et variantes repris mot pour mot) :
//    - src/utils/eventPhotoRelay.ts (`ANSWER_BASE64_TARGET_BYTES`,
//      `ANSWER_IMAGE_VARIANTS`, `RELAY_TIMEOUT_MS`, `prepareEventAnswerImage`,
//      `askEventAnswerRelay`).
//
//  Le module `mathOcr` garde la même mécanique pour ses propres flux
//  (`PhotoTxPremiumImage.swift`) : ici on reproduit le contrat minimal, sans
//  toucher au code existant.
//
//  Écart assumé (2026-09-29) : le relais est appelé avec un délai de 92 s
//  (`RELAY_TIMEOUT_MS`) ; `DuelloAPI.request` fixe 10 s pour tous les appels,
//  d'où un appel `URLSession` dédié ici. `EvEventPhotoRelay.transcribe`
//  (fichier voisin) garde l'appel court et devrait déléguer à ce module
//  (raccordement signalé, hors lot).
//
//  Cible : iOS 16, aucune API iOS 17.
//
import Foundation
import UIKit

/// `prepareEventAnswerImage` / `askEventAnswerRelay` de `eventPhotoRelay.ts`.
enum EvEventAnswerImage {

    /// `ANSWER_BASE64_TARGET_BYTES` : budget base64 d'une page de réponse.
    static let base64TargetBytes = 1_800_000
    /// `RELAY_TIMEOUT_MS` : temps d'attente maximal d'une lecture premium (92 s).
    static let relayTimeoutMs = 92_000
    /// Contexte annoncé au relais (`askEventAnswerRelay`).
    static let exerciseContext = "Concours blanc Duello"

    /// Variante de compression (`ANSWER_IMAGE_VARIANTS`).
    struct Variant {
        var maxEdge: CGFloat
        var compress: CGFloat
    }

    /// Variantes essayées dans l'ordre, du plus léger au plus dense.
    static let variants: [Variant] = [
        Variant(maxEdge: 1_600, compress: 0.7),
        Variant(maxEdge: 1_600, compress: 0.5),
        Variant(maxEdge: 1_200, compress: 0.4),
    ]

    /// Image prête à partir (`PreparedAnswerImage`).
    struct Prepared {
        var base64: String
        var mimeType: String
    }

    /// `prepareEventAnswerImage` : compresse la photo jusqu'à tenir dans le
    /// budget du relais, en essayant les variantes dans l'ordre.
    static func prepare(_ image: UIImage) throws -> Prepared {
        var lastBase64 = ""
        for variant in variants {
            let rendered = resize(image, maxEdge: variant.maxEdge)
            guard let data = rendered.jpegData(compressionQuality: variant.compress) else { continue }
            lastBase64 = data.base64EncodedString()
            if !lastBase64.isEmpty, lastBase64.count <= base64TargetBytes {
                return Prepared(base64: lastBase64, mimeType: "image/jpeg")
            }
        }
        guard !lastBase64.isEmpty else {
            throw DirectoryError(message: "conversion de la photo impossible")
        }
        return Prepared(base64: lastBase64, mimeType: "image/jpeg")
    }

    /// `askEventAnswerRelay` : appelle le relais avec l'action premium de lecture
    /// photo et rend le texte transcrit, déjà converti en caractères affichables.
    static func transcribe(
        imageBase64: String,
        subject: String,
        token: String?
    ) async throws -> String {
        let url = DuelloAPI.baseURL.appendingPathComponent("relay/transcribe-photo")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = TimeInterval(relayTimeoutMs) / 1000
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        let body: [String: Any] = [
            "action": "transcribe-photo",
            "image": imageBase64,
            "mimeType": "image/jpeg",
            "subject": subject,
            "exercise": exerciseContext,
            "transcriptionMode": "question",
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status == 401 || status == 403 { throw DirectoryError(message: "accès premium refusé") }
        guard (200..<300).contains(status) else {
            throw DirectoryError(message: "le relais a répondu \(status)")
        }
        let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        let text = ((object["text"] as? String) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw DirectoryError(message: "la transcription est vide, réessaie.") }
        return LatexToUnicode.toUnicodeMath(text)
    }

    /// Redimensionne l'image pour que son plus grand côté tienne sous `maxEdge`.
    private static func resize(_ image: UIImage, maxEdge: CGFloat) -> UIImage {
        let width = image.size.width
        let height = image.size.height
        guard max(width, height) > maxEdge else { return image }
        let scale = maxEdge / max(width, height)
        let target = CGSize(width: (width * scale).rounded(), height: (height * scale).rounded())
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }
}
