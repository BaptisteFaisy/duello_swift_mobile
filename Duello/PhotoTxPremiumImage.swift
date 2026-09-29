//
//  PhotoTxPremiumImage.swift
//  Duello
//
//  Lot T06 (vague 4 « couche transverse ») — TR-06 : préparation d'image et test
//  du relais pour la transcription premium (`utils/mathOcr.ts`).
//
//  Fichier source Expo porté (budgets, variantes et libellés repris mot pour mot) :
//    - src/utils/mathOcr.ts (`RELAY_TIMEOUT_MS`, `MATHPIX_BASE64_TARGET_BYTES`,
//      `FULL_EXERCISE_BASE64_TARGET_BYTES`, `PREMIUM_IMAGE_VARIANTS`,
//      `preparePremiumImage`, `testMathOcrRelay`) ;
//    - src/utils/relayEndpoint.ts (`resolveConfiguredRelayEndpoint`,
//      `defaultRelayEndpoint` = `${apiUrl}/relay`).
//
//  `PhotoTxRelay` (fichier voisin) envoie la photo telle quelle (`0.9`, aucune
//  variante) : `preparePremiumImage` et les variantes manquaient. Le raccordement
//  de `PhotoTxController` à cette préparation est signalé (hors lot).
//
//  Cible : iOS 16, aucune API iOS 17.
//
import Foundation
import UIKit

/// `preparePremiumImage` / `testMathOcrRelay` de `utils/mathOcr.ts`.
enum PhotoTxPremiumImage {

    /// `RELAY_TIMEOUT_MS` : l'OCR à effort maximal peut durer deux minutes (180 s).
    static let relayTimeoutMs = 180_000
    /// `MATHPIX_BASE64_TARGET_BYTES` : garde la photo compatible Mathpix (1,8 Mo).
    static let mathpixBase64TargetBytes = 1_800_000
    /// `FULL_EXERCISE_BASE64_TARGET_BYTES` : marge sous la limite JSON (18 Mio).
    static let fullExerciseBase64TargetBytes = 18 * 1024 * 1024
    /// Délai du test de relais (`withTimeout(8000)`).
    static let testTimeoutMs = 8_000

    /// Variante de compression (`PREMIUM_IMAGE_VARIANTS`).
    struct Variant {
        var maxEdge: CGFloat
        var compress: CGFloat
    }

    /// `PREMIUM_IMAGE_VARIANTS` : essayées dans l'ordre, du plus dense au plus léger.
    static let variants: [Variant] = [
        Variant(maxEdge: 2_400, compress: 0.88),
        Variant(maxEdge: 2_000, compress: 0.82),
        Variant(maxEdge: 1_700, compress: 0.76),
        Variant(maxEdge: 1_400, compress: 0.68),
        Variant(maxEdge: 1_200, compress: 0.60),
        Variant(maxEdge: 1_000, compress: 0.52),
        Variant(maxEdge: 850, compress: 0.46),
    ]

    /// Adresse par défaut du relais (`defaultRelayEndpoint`) : `${apiUrl}/relay`.
    static var defaultEndpoint: URL {
        DuelloAPI.baseURL.appendingPathComponent("relay")
    }

    /// `preparePremiumImage` : compresse la photo sous le budget visé, en essayant
    /// les variantes dans l'ordre ; lève quand la photo reste trop lourde.
    static func preparePremiumImage(
        _ image: UIImage,
        targetBytes: Int = mathpixBase64TargetBytes
    ) throws -> String {
        var lastBase64 = ""
        for variant in variants {
            let rendered = resize(image, maxEdge: variant.maxEdge)
            guard let data = rendered.jpegData(compressionQuality: variant.compress) else { continue }
            lastBase64 = data.base64EncodedString()
            if !lastBase64.isEmpty, lastBase64.count <= targetBytes { return lastBase64 }
        }
        guard !lastBase64.isEmpty else {
            throw DirectoryError(message: "conversion de la photo impossible")
        }
        throw DirectoryError(message: "photo trop lourde pour la transcription premium")
    }

    /// Réponse du relais au test de réglages (`testMathOcrRelay`).
    struct RelayStatus: Equatable {
        var ok: Bool
        var error: String?
        var asrConfigured: Bool?
        var asr: Bool?
        var asrModel: String?
        var asrFallbackModel: String?
        var funAsrConfigured: Bool?
        var funAsr: Bool?
        var funAsrModel: String?
        var fullAudioTranscription: Bool?
        var fullAudioTranscriptionModel: String?
        var imageTranscription: Bool?
        var imageTranscriptionModel: String?
        var imageTranscriptionEffort: String?
        var mathDictationFormatting: Bool?
        var mathDictationModel: String?
    }

    /// `testMathOcrRelay` : le relais répond à un GET par `{ ok: true }` — de quoi
    /// valider les réglages. Un refus ou une panne devient un `ok: false` explicite.
    static func testRelay(endpoint: URL? = nil, token: String?) async -> RelayStatus {
        let url = endpoint ?? defaultEndpoint
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = TimeInterval(testTimeoutMs) / 1000
        if let token, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            if status == 401 || status == 403 {
                return RelayStatus(ok: false, error: "Jeton refusé par le relais.")
            }
            guard (200..<300).contains(status) else {
                return RelayStatus(ok: false, error: "Relais injoignable (\(status))")
            }
            let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
            return parseRelayStatus(object)
        } catch {
            return RelayStatus(ok: false, error: "Relais injoignable.")
        }
    }

    /// Lit la réponse de test ; un corps sans `ok` n'est pas un relais Duello.
    private static func parseRelayStatus(_ object: [String: Any]) -> RelayStatus {
        guard (object["ok"] as? Bool) == true else {
            return RelayStatus(
                ok: false,
                error: "Réponse inattendue : ce n’est pas un relais Duello."
            )
        }
        return RelayStatus(
            ok: true,
            error: nil,
            asrConfigured: bool(object, "asrConfigured") ?? bool(object, "funAsrConfigured"),
            asr: bool(object, "asr") ?? bool(object, "funAsr"),
            asrModel: string(object, "asrModel") ?? string(object, "funAsrModel"),
            asrFallbackModel: string(object, "asrFallbackModel"),
            funAsrConfigured: bool(object, "funAsrConfigured"),
            funAsr: bool(object, "funAsr"),
            funAsrModel: string(object, "funAsrModel"),
            fullAudioTranscription: bool(object, "fullAudioTranscription"),
            fullAudioTranscriptionModel: string(object, "fullAudioTranscriptionModel"),
            imageTranscription: bool(object, "imageTranscription"),
            imageTranscriptionModel: string(object, "imageTranscriptionModel"),
            imageTranscriptionEffort: string(object, "imageTranscriptionEffort"),
            mathDictationFormatting: bool(object, "mathDictationFormatting"),
            mathDictationModel: string(object, "mathDictationModel")
        )
    }

    private static func bool(_ object: [String: Any], _ key: String) -> Bool? {
        object[key] as? Bool
    }

    private static func string(_ object: [String: Any], _ key: String) -> String? {
        object[key] as? String
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
