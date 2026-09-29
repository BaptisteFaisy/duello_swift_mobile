//
//  ProfCourseTextRelay.swift
//  Duello
//
//  Port de `src/utils/profCourseText.ts` (RN) — texte du cours uploadé, pour la
//  fenêtre de contexte du prof IA.
//
//  Un cours est un PDF ou une photo : rien d'utile n'en est stocké en clair sur
//  l'appareil. Le texte en est extrait une fois par le relais
//  (`read-course-text`, qui réutilise l'extracteur des flashcards), puis gardé en
//  mémoire pour la session (`ProfCourseTextCache`). Sans texte exploitable — un
//  cours scanné, une photo, un relais indisponible — `loadProfCourseText` rend une
//  chaîne vide et le prof s'appuie sur la page sélectionnée, comme avant.
//
//  Écart assumé : la source résout l'adresse par `resolveRelayEndpoint(settings)`
//  et lit le jeton de la session serveur ; le portage réutilise l'origine du
//  client partagé `DuelloAPI.baseURL` + `/relay` (comme `CtdAnalysisService` et
//  `CollFlashcardsApiRelay`, qui ne reprennent pas non plus une adresse dédiée) et
//  reçoit le jeton en paramètre. L'action, le corps et les messages sont ceux de
//  la source.
//
//  Cible : iOS 16. Aucune dépendance externe.
//

import Foundation

/// Erreurs de lecture du texte d'un cours (`profCourseText.ts`).
enum ProfCourseTextError: LocalizedError, Equatable {
    /// Accord de partage avec les prestataires d'IA non donné.
    case consentRequired
    /// Document au-delà de la limite du relais (`assertDocumentSize`).
    case tooLarge
    /// Le relais n'a pas rendu de texte exploitable.
    case unreadable

    var errorDescription: String? {
        switch self {
        case .consentRequired:
            return CtdAiConsent.declinedLabel
        case .tooLarge:
            return "Le cours dépasse 8 Mo. Compresse le fichier, puis réessaie."
        case .unreadable:
            return "Le cours n’a pas pu être lu."
        }
    }
}

/// Extraction du texte d'un cours uploadé par le relais (`profCourseText.ts`).
enum ProfCourseTextRelay {

    /// `MAX_DOCUMENT_BYTES` : même plafond que l'analyse de TD, au-delà duquel le
    /// relais refuse le document.
    static let maxDocumentBytes = 8 * 1024 * 1024
    /// Action du relais, mot pour mot de la valeur envoyée par Expo.
    static let readCourseTextAction = "read-course-text"

    /// `loadProfCourseText` : texte du cours, extrait une fois puis réutilisé.
    ///
    /// Le mémo est consulté ici et pas seulement dans
    /// `shareProfCourseExtraction` : sans cette sortie, la lecture du fichier
    /// démarrerait avant que le partage sache qu'il n'y a rien à envoyer.
    static func loadProfCourseText(
        _ document: CtdStoredCourseDocument?,
        token: String?
    ) async throws -> String {
        guard let document else { return "" }
        if let dejaLa = ProfCourseTextCache.cachedProfCourseText(document) { return dejaLa }
        return try await ProfCourseTextCache.shareProfCourseExtraction(document) {
            try await relayCourseText(document, token: token)
        }
    }

    /// `relayCourseText` : consentement, lecture base64, envoi et texte rendu.
    static func relayCourseText(
        _ document: CtdStoredCourseDocument,
        token: String?
    ) async throws -> String {
        guard CtdAiConsent.isGranted else { throw ProfCourseTextError.consentRequired }
        let base64 = try readBase64(document.uri)
        try assertDocumentSize(base64)
        let data = try await post(
            body: [
                "action": readCourseTextAction,
                "base64": base64,
                "mimeType": document.mimeType.rawValue,
            ],
            token: token
        )
        guard let payload = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let text = payload["text"] as? String else {
            throw ProfCourseTextError.unreadable
        }
        return text
    }

    /// `assertDocumentSize` : refuse un document au-delà du plafond du relais.
    private static func assertDocumentSize(_ base64: String) throws {
        if Int(Double((base64 as NSString).length) * 0.75) > maxDocumentBytes {
            throw ProfCourseTextError.tooLarge
        }
    }

    /// `readCourseDocumentBase64` : un import peut être une URL `data:` ou un
    /// chemin privé de l'application ; les deux sont normalisés ici.
    private static func readBase64(_ uri: String) throws -> String {
        if uri.hasPrefix("data:") {
            guard let separator = uri.firstIndex(of: ",") else {
                throw ProfCourseTextError.unreadable
            }
            return String(uri[uri.index(after: separator)...])
        }
        guard let data = FileManager.default.contents(atPath: uri) else {
            throw ProfCourseTextError.unreadable
        }
        return data.base64EncodedString()
    }

    /// `fetch(resolveRelayEndpoint(settings), …)` : requête locale au relais.
    private static func post(body: [String: Any], token: String?) async throws -> Data {
        var request = URLRequest(url: DuelloAPI.baseURL.appendingPathComponent("relay"))
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else {
            throw ProfCourseTextError.unreadable
        }
        return data
    }
}
