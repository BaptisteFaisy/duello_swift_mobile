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
//  Écarts assumés (2026-09-29) — fenêtre de contexte v2 (contrat 2) :
//    - `ProfStudent` / `ProfDocuments` / `ProfTutorContext` v2 et
//      `profTutorContext` sont portés ici ; en revanche `profStudentContext`
//      (construction de `student` à partir du profil et du catalogue), le
//      catalogue `officialMathsPrograms` et l'action relais `read-course-text`
//      demandent des fichiers neufs (`ProfStudentContext.swift`,
//      `OfficialMathsPrograms.swift`) : décrits en « À raccorder » du lot
//      IMPL-09, hors périmètre de ce fichier (ratchet ≤ 10 fonctions).
//    - `PROF_RELAY_CONTRACT_VERSION = 2` : le champ `program` a disparu du
//      contexte ; `ProfTutorViews` doit lire `student?.program` (raccord
//      IMPL-11).
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

/// `ProfStudent` : identité de l'élève et programme qu'il suit. C'est le socle
/// de la fenêtre de contexte v2 : présent sur toutes les pages, il permet au
/// prof de s'adresser à l'élève par son pseudo et de ne jamais sortir du
/// programme de sa filière et de son année (`profTutor.ts:18-29`).
struct ProfStudent: Codable, Equatable {
    /// Pseudo de l'élève.
    var displayName: String
    /// Année de classe préparatoire, ou classe du lycée.
    var year: String
    /// Filière réellement suivie, parcours de maths compris en ECG.
    var track: String
    /// Intitulé du programme officiel de cette filière et de cette année.
    var program: String
    /// Adresse du texte officiel, quand elle est connue.
    var programUrl: String?
}

/// `ProfDocuments` : documents que l'élève a mis sous les yeux du prof. Ils ne
/// partent que lorsqu'ils existent (`profTutor.ts:37-46`).
struct ProfDocuments: Codable, Equatable {
    /// Énoncé retranscrit de l'exercice, de la colle ou de l'annale.
    var statement: String?
    /// Corrigé du même sujet.
    var solution: String?
    /// Texte extrait du cours uploadé par l'élève.
    var course: String?
    /// Nom du fichier de cours, pour que le prof sache ce qu'il lit.
    var courseName: String?

    /// Vrai quand aucun document n'est transmis (bloc omis du relais).
    var isEmpty: Bool {
        statement == nil && solution == nil && course == nil && courseName == nil
    }
}

/// `ProfTutorContext` : repères transmis au relais (jamais affichés en clair).
///
/// Contrat **v2** : le champ libre `program` a disparu au profit de
/// `student.program`, qui porte la même information avec la filière et l'année
/// de l'élève ; `documents` transporte l'énoncé, le corrigé et le cours
/// (`profTutor.ts:48-59`).
struct ProfTutorContext: Codable, Equatable {
    var source: ProfTutorSource
    var subject: String?
    var chapter: String?
    var exercise: String?
    var question: String?
    var page: Int?
    /// Identité de l'élève et programme qu'il suit : jamais omis.
    var student: ProfStudent?
    /// Énoncé, corrigé et cours : omis quand l'écran n'a rien à transmettre.
    var documents: ProfDocuments?

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
    /// Photo de cours expliquée (base64 sans préfixe) : `quote` est vide alors.
    var image: String?
    /// Type MIME de `image` (`image/jpeg`, `image/png`, `image/gif`, `image/webp`).
    var mimeType: String?
    var context: ProfTutorContext

    init(
        id: UUID = UUID(),
        quote: String,
        image: String? = nil,
        mimeType: String? = nil,
        context: ProfTutorContext
    ) {
        self.id = id
        self.quote = quote
        self.image = image
        self.mimeType = mimeType
        self.context = context
    }

    /// `data:<mime>;base64,<…>` de la vignette (`ProfTutorPanel.imageUri`).
    var imageUri: String? {
        guard let image, let mimeType else { return nil }
        return "data:\(mimeType);base64,\(image)"
    }
}

// MARK: - Plafonds anti-abus

/// Passage maximal envoyé au relais : un chapitre entier ne part jamais.
let PROF_QUOTE_MAX_CHARS = 2000
/// Question maximale : une demande reste une demande, pas un devoir.
let PROF_QUESTION_MAX_CHARS = 1000
/// Historique maximal rejoué : les quatre derniers échanges suffisent.
let PROF_HISTORY_MAX_MESSAGES = 8
/// Énoncé transmis au prof : un sujet de concours tient largement dedans
/// (`PROF_STATEMENT_MAX_CHARS`, miroir de `profStudentContext.ts:33`).
let PROF_STATEMENT_MAX_CHARS = 6000
/// Corrigé transmis au prof, même ordre de grandeur que l'énoncé.
let PROF_SOLUTION_MAX_CHARS = 6000
/// Cours uploadé : le texte entier d'un chapitre, page après page.
let PROF_COURSE_MAX_CHARS = 60_000
/// Version du contrat relais, pour faire évoluer le format sans casser.
///
/// La version 2 ajoute la fenêtre de contexte de l'élève (identité, programme,
/// documents) et retire le champ libre `program` (`profTutor.ts:77-82`).
let PROF_RELAY_CONTRACT_VERSION = 2

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

// MARK: - Fenêtre de contexte (v2)

/// Ce qu'un écran sait de la page où le prof est sollicité (`ProfContextInput`,
/// `profStudentContext.ts:49-66`). `student` est construit une fois par l'écran
/// (via `profStudentContext`, à raccorder — voir « Écarts assumés »).
struct ProfContextInput {
    var source: ProfTutorSource
    var student: ProfStudent
    var subject: String?
    var chapter: String?
    var exercise: String?
    var question: String?
    var page: Int?
    /// Énoncé et corrigé retranscrits du sujet ouvert.
    var item: (statement: String?, solution: String?)?
    /// Cours uploadé du chapitre, texte déjà extrait.
    var course: (name: String, text: String?)?
}

/// `profTutorContext` : contexte transmis au relais. Les champs inconnus de
/// l'écran sont omis plutôt qu'envoyés vides (`profStudentContext.ts:154-165`).
func profTutorContext(_ input: ProfContextInput) -> ProfTutorContext {
    let tronquer: (String?, Int) -> String? = { valeur, max in
        guard let texte = valeur?.trimmingCharacters(in: .whitespacesAndNewlines),
              !texte.isEmpty else { return nil }
        return texte.count > max ? String(texte.prefix(max)) : texte
    }
    let cours = tronquer(input.course?.text, PROF_COURSE_MAX_CHARS)
    let documents = ProfDocuments(
        statement: tronquer(input.item?.statement, PROF_STATEMENT_MAX_CHARS),
        solution: tronquer(input.item?.solution, PROF_SOLUTION_MAX_CHARS),
        course: cours,
        courseName: cours != nil ? input.course?.name : nil
    )
    return ProfTutorContext(
        source: input.source,
        subject: input.subject,
        chapter: input.chapter,
        exercise: input.exercise,
        question: input.question,
        page: input.page,
        student: input.student,
        documents: documents.isEmpty ? nil : documents
    )
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

/// Corps `prof-explain` en variante photo : le relais vision lit l'image elle-même.
struct ProfExplainImageBody: Encodable {
    var action = "prof-explain"
    var contractVersion = PROF_RELAY_CONTRACT_VERSION
    var stream = true
    var image: String
    var mimeType: String
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

/// `buildProfExplainImageBody` : JSON de l'explication d'une photo ou d'une page
/// scannée (le relais vision lit l'image, aucun passage n'est rogné).
func buildProfExplainImageBody(
    image: String,
    mimeType: String,
    context: ProfTutorContext
) throws -> String {
    let body = ProfExplainImageBody(image: image, mimeType: mimeType, context: context)
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
