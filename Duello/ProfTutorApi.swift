//
//  ProfTutorApi.swift
//  Duello
//
//  Port de `src/utils/profTutorApi.ts` (RN) — Prof IA côté relais.
//
//  Même pont que le correcteur et la transcription : `${DUELLO_API_URL}/relay`,
//  jeton de session Duello, consentement IA, avec les actions `prof-explain` et
//  `prof-chat` en streaming SSE. L'application n'appelle jamais le fournisseur
//  d'IA directement : le relais détient la clé et applique le quota.
//
//  Approché / limite assumée (24/09/2026) :
//    - `resolveRelayEndpoint` de la source accepte une adresse de relais
//      surchargée (réglages OCR) ; le portage utilise l'origine du build
//      (`DuelloAPI.baseURL`) comme `AnnRelay`/`CtdAnalysisService`, faute de
//      réglage d'adresse porté côté iOS. Le jeton ne quitte donc jamais l'origine
//      de l'API.
//    - `requireAiDataSharingConsent` ouvre une alerte si l'accord manque ; ici
//      l'appel **refuse explicitement** (`ProfTutorError.consentRequired`) et
//      laisse l'écran présenter l'alerte de consentement (cf. `wiring/U1.md`).
//
//  Cible : iOS 16. Aucune dépendance externe.
//

import Foundation

/// `streamProfExplain` / `streamProfChat` : appels du prof IA au relais.
enum ProfTutorApi {
    /// Chemin du relais, comme `DuelloAPI`/`AnnRelay`.
    static let relayPath = "relay"

    /// `resolveRelayEndpoint(settings)` : origine de l'API suivie par le build.
    static func relayEndpoint() -> URL {
        DuelloAPI.baseURL.appendingPathComponent(relayPath)
    }

    /// `streamProfExplain` : explique un passage, jeton par jeton.
    static func streamExplain(
        token: String,
        quote: String,
        context: ProfTutorContext,
        onToken: @escaping ProfTokenHandler
    ) async throws -> String {
        try requireConsent()
        let body = try buildProfExplainBody(quote: quote, context: context)
        return try await ProfTutorStream.post(
            endpoint: relayEndpoint(),
            token: token,
            body: Data(body.utf8),
            onToken: onToken
        )
    }

    /// `streamProfChat` : répond à une question, jeton par jeton.
    static func streamChat(
        token: String,
        messages: [ProfTutorMessage],
        context: ProfTutorContext,
        onToken: @escaping ProfTokenHandler
    ) async throws -> String {
        try requireConsent()
        let body = try buildProfChatBody(messages: messages, context: context)
        return try await ProfTutorStream.post(
            endpoint: relayEndpoint(),
            token: token,
            body: Data(body.utf8),
            onToken: onToken
        )
    }

    /// `requireAiDataSharingConsent` : refuse sans accord explicite de l'élève.
    static func requireConsent() throws {
        guard CtdAiConsent.isGranted else { throw ProfTutorError.consentRequired }
    }
}
