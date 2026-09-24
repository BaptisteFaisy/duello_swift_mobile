//
//  ProfTutorCore.swift
//  Duello
//
//  Port de `src/utils/profTutor.ts` (RN) — types partagés, plafonds anti-abus
//  et préparation des demandes au relais « Prof IA ».
//
//  Le client ne parle jamais au fournisseur d'IA : il prépare la demande pour
//  le relais (`ProfTutorApi`), qui applique le contrat décrit dans
//  `docs/PROF-TUTOR-RELAY-CONTRACT.md`. Ce fichier reste pur et synchrone, pour
//  être vérifiable sans réseau — même partage que la source TS.
//
//  Réduit / approché (24/09/2026) :
//    - `buildProfExplainBody` / `buildProfChatBody` rendent une **chaîne JSON**
//      comme la source ; `ProfTutorApi` la convertit en `Data` au moment de
//      l'envoi (une seule frontière, pas de double encodage).
//    - `PROF_HISTORY_MAX_MESSAGES` vaut 8 côté source ; la valeur est reprise
//      telle quelle (l'historique rejoué reste court).
//
//  Cible : iOS 16. Aucune dépendance externe.
//

import Foundation

// MARK: - Types partagés

/// `ProfTutorSource` : origine du passage expliqué.
enum ProfTutorSource: String, Codable, Equatable {
    case cours
    case corrige
}

/// `ProfTutorContext` : repères transmis au relais (jamais affichés en clair).
struct ProfTutorContext: Codable, Equatable {
    var source: ProfTutorSource
    var subject: String?
    var program: String?
    var chapter: String?
    var exercise: String?
    var question: String?
    var page: Int?

    /// Repli de la source : `{ source: 'cours' }` quand aucune demande n'est posée.
    static let fallback = ProfTutorContext(source: .cours)
}

/// `ProfTutorMessage` : un tour de la conversation (élève ou prof).
struct ProfTutorMessage: Codable, Equatable {
    enum Role: String, Codable, Equatable {
        case user
        case assistant
    }

    var role: Role
    var text: String
}

/// `ProfTutorRequest` : demande posée par l'écran parent (passage + contexte).
///
/// `id` n'existe pas côté source ; il sert d'identité stable pour `sheet(item:)`
/// et pour n'ouvrir la session qu'une fois par demande (miroir du `openedFor`
/// de `ProfTutorSheet.tsx`).
struct ProfTutorRequest: Equatable, Identifiable {
    let id: UUID
    var quote: String
    var context: ProfTutorContext

    init(id: UUID = UUID(), quote: String, context: ProfTutorContext) {
        self.id = id
        self.quote = quote
        self.context = context
    }
}

// MARK: - Plafonds anti-abus

/// Passage maximal envoyé au relais : un chapitre entier ne part jamais.
let PROF_QUOTE_MAX_CHARS = 2000
/// Question maximale : une demande reste une demande, pas un devoir.
let PROF_QUESTION_MAX_CHARS = 1000
/// Historique maximal rejoué : les quatre derniers échanges suffisent.
let PROF_HISTORY_MAX_MESSAGES = 8
/// Version du contrat relais, pour faire évoluer le format sans casser.
let PROF_RELAY_CONTRACT_VERSION = 1

// MARK: - Erreurs

/// `ProfAuthenticationError` : session Duello expirée, message de la source.
struct ProfAuthenticationError: LocalizedError {
    var errorDescription: String? {
        "Ta session Duello a expiré. Reconnecte-toi pour utiliser le prof IA."
    }
}

/// Erreurs du prof IA, alignées sur les `Error` levées par `profTutor.ts`.
enum ProfTutorError: LocalizedError, Equatable {
    /// `429` : trop de questions d'affilée.
    case rateLimited
    /// Panne du relais, code HTTP conservé dans le libellé.
    case unavailable(Int)
    /// Refus ou message déjà rédigé par le serveur.
    case relay(String)
    /// Corps de réponse inexploitable (`parseProfJsonResponse`).
    case unexpectedResponse
    /// Silence trop long entre deux morceaux (`PROF_STREAM_IDLE_TIMEOUT_MS`).
    case streamTimeout
    /// Aucun transport de streaming disponible.
    case streamingUnavailable
    /// Accord de partage avec les prestataires d'IA non donné.
    case consentRequired

    var errorDescription: String? {
        switch self {
        case .rateLimited:
            return "Tu as posé beaucoup de questions. Fais une pause, puis réessaie."
        case .unavailable(let status):
            return "Prof IA indisponible (\(status)). Réessaie dans un instant."
        case .relay(let message):
            return message
        case .unexpectedResponse:
            return "Réponse inattendue du prof IA"
        case .streamTimeout:
            return "Le prof IA met trop de temps à répondre"
        case .streamingUnavailable:
            return "Streaming indisponible sur cet appareil"
        case .consentRequired:
            return "La fonction IA n’a pas été lancée."
        }
    }
}

// MARK: - Rognage

/// `clampProfQuote` : rogne le passage au plafond anti-abus.
func clampProfQuote(_ quote: String) -> String {
    String(quote.trimmingCharacters(in: .whitespacesAndNewlines).prefix(PROF_QUOTE_MAX_CHARS))
}

/// `clampProfQuestion` : rogne la question au plafond anti-abus.
func clampProfQuestion(_ question: String) -> String {
    String(question.trimmingCharacters(in: .whitespacesAndNewlines).prefix(PROF_QUESTION_MAX_CHARS))
}

/// `clampProfHistory` : ne garde que les derniers tours non vides, rognés.
func clampProfHistory(_ messages: [ProfTutorMessage]) -> [ProfTutorMessage] {
    let nonEmpty = messages.filter {
        !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    return nonEmpty.suffix(PROF_HISTORY_MAX_MESSAGES).map { message in
        let text = message.text.trimmingCharacters(in: .whitespacesAndNewlines)
        return ProfTutorMessage(
            role: message.role,
            text: String(text.prefix(PROF_QUESTION_MAX_CHARS))
        )
    }
}

// MARK: - Relances

/// `profFollowUpSuggestions` : relances proposées après la première explication.
func profFollowUpSuggestions(_ source: ProfTutorSource) -> [String] {
    switch source {
    case .corrige:
        return [
            "Pourquoi cette étape est-elle légitime ?",
            "Quelle est l’idée principale du corrigé ?",
            "Un exemple similaire pour vérifier ?",
        ]
    case .cours:
        return [
            "C’est quoi l’idée de ce théorème ?",
            "Un exemple d’application ?",
            "Le lien avec les exercices ?",
        ]
    }
}

// MARK: - Corps des demandes

/// Corps `prof-explain` : action, version de contrat, streaming, passage, contexte.
struct ProfExplainBody: Encodable {
    var action = "prof-explain"
    var contractVersion = PROF_RELAY_CONTRACT_VERSION
    var stream = true
    var quote: String
    var context: ProfTutorContext
}

/// Corps `prof-chat` : action, version de contrat, streaming, historique, contexte.
struct ProfChatBody: Encodable {
    var action = "prof-chat"
    var contractVersion = PROF_RELAY_CONTRACT_VERSION
    var stream = true
    var messages: [ProfTutorMessage]
    var context: ProfTutorContext
}

/// `buildProfExplainBody` : JSON de la demande d'explication, passage rogné.
func buildProfExplainBody(quote: String, context: ProfTutorContext) throws -> String {
    let body = ProfExplainBody(quote: clampProfQuote(quote), context: context)
    return try profEncode(body)
}

/// `buildProfChatBody` : JSON de la question, historique plafonné.
func buildProfChatBody(messages: [ProfTutorMessage], context: ProfTutorContext) throws -> String {
    let body = ProfChatBody(messages: clampProfHistory(messages), context: context)
    return try profEncode(body)
}

/// Encodage JSON commun aux deux corps ; l'échec est une erreur parlante.
private func profEncode<T: Encodable>(_ value: T) throws -> String {
    do {
        let data = try JSONEncoder().encode(value)
        return String(decoding: data, as: UTF8.self)
    } catch {
        throw ProfTutorError.unexpectedResponse
    }
}
