//
//  ProfTutorSession.swift
//  Duello
//
//  Port de `src/hooks/useProfTutor.ts` (RN) — session de prof IA : une
//  explication streamée puis des questions.
//
//  Le relais reste sans état : chaque tour de questions rejoue le passage
//  expliqué en tête d'historique, pour que le modèle ne le perde jamais. Une
//  exécution tardive (fermeture puis réouverture rapide) est ignorée : le
//  numéro de course (`runId`) joue le rôle du `runId` de la source, et
//  l'annulation de `Task` celui de l'`AbortController`.
//
//  Approché (24/09/2026) :
//    - le jeton vient de l'écran (`token`, posé depuis `SessionStore`) au lieu
//      d'être lu dans `AccountStorage` à chaque tour ; une session révoquée est
//      tout de même détectée par le `401` du relais (`ProfAuthenticationError`).
//
//  Cible : iOS 16. Aucune dépendance externe.
//

import Combine
import Foundation

/// `PROF_BLANK_GREETING` : accueil de la discussion libre, sans passage ni
/// photo (`profTutor.ts:71`).
let PROF_BLANK_GREETING = "Salut ! Pose-moi ta question de maths, je t’explique."

/// `ProfTutorStatus` : état de la session.
enum ProfTutorStatus: Equatable {
    case idle
    case streaming
    case ready
    case error
}

/// Session de prof IA (`useProfTutor`), observée par le panneau.
@MainActor
final class ProfTutorSession: ObservableObject {
    @Published private(set) var request: ProfTutorRequest?
    @Published private(set) var messages: [ProfTutorMessage] = []
    @Published private(set) var streamingText = ""
    @Published private(set) var status: ProfTutorStatus = .idle
    @Published private(set) var error = ""

    /// Jeton de session Duello, posé par l'écran (miroir de `useAccountStorage`).
    var token: String?

    private var runId = 0
    private var streamTask: Task<Void, Never>?

    /// `suggestions` : relances de la source, seulement quand une demande est posée.
    var suggestions: [String] {
        guard let request else { return [] }
        return profFollowUpSuggestions(request.context.source)
    }

    /// `open` : pose la demande et lance la première explication streamée.
    func open(quote: String, context: ProfTutorContext) {
        stopStream()
        runId += 1
        let run = runId
        request = ProfTutorRequest(quote: quote, context: context)
        messages = []
        streamingText = ""
        error = ""
        status = .streaming
        let token = self.token ?? ""
        streamTask = Task { [weak self] in
            do {
                let text = try await ProfTutorApi.streamExplain(
                    token: token,
                    quote: quote,
                    context: context
                ) { [weak self] chunk in
                    Task { @MainActor in
                        guard let self, self.runId == run else { return }
                        self.streamingText += chunk
                    }
                }
                guard let self, self.runId == run else { return }
                self.messages = [ProfTutorMessage(role: .assistant, text: text)]
                self.streamingText = ""
                self.status = .ready
            } catch {
                self?.fail(error, run: run)
            }
        }
    }

    /// `openBlank` : discussion libre, sans passage ni photo. La session
    /// s'ouvre sur un message d'accueil et la saisie tout de suite, sans
    /// relais (`useProfTutor.ts:59-68`).
    func openBlank(context: ProfTutorContext) {
        stopStream()
        runId += 1
        request = ProfTutorRequest(quote: "", context: context)
        messages = [ProfTutorMessage(role: .assistant, text: PROF_BLANK_GREETING)]
        streamingText = ""
        error = ""
        status = .ready
    }

    /// `openImage` : pose une photo expliquée (page scannée, photo de cours) et
    /// lance son explication streamée par le relais vision.
    func openImage(image: String, mimeType: String, context: ProfTutorContext) {
        stopStream()
        runId += 1
        let run = runId
        request = ProfTutorRequest(quote: "", image: image, mimeType: mimeType, context: context)
        messages = []
        streamingText = ""
        error = ""
        status = .streaming
        let token = self.token ?? ""
        streamTask = Task { [weak self] in
            do {
                let text = try await ProfTutorApi.streamExplainImage(
                    token: token,
                    image: image,
                    mimeType: mimeType,
                    context: context
                ) { [weak self] chunk in
                    Task { @MainActor in
                        guard let self, self.runId == run else { return }
                        self.streamingText += chunk
                    }
                }
                guard let self, self.runId == run else { return }
                self.messages = [ProfTutorMessage(role: .assistant, text: text)]
                self.streamingText = ""
                self.status = .ready
            } catch {
                self?.fail(error, run: run)
            }
        }
    }

    /// `send` : ajoute la question et rejoue le passage en tête d'historique.
    func send(_ input: String) {
        let text = clampProfQuestion(input)
        guard !text.isEmpty, let request, status != .streaming else { return }
        stopStream()
        runId += 1
        let run = runId
        let userMessage = ProfTutorMessage(role: .user, text: text)
        let nextMessages = messages + [userMessage]
        messages = nextMessages
        streamingText = ""
        error = ""
        status = .streaming
        // Après une photo, l'explication reçue porte le contexte ; sans photo
        // ni passage (question libre), l'historique commence à la question
        // (`useProfTutor.ts:152-157`).
        let history = profReplayPassage(request) + nextMessages
        let token = self.token ?? ""
        let context = request.context
        streamTask = Task { [weak self] in
            do {
                let answer = try await ProfTutorApi.streamChat(
                    token: token,
                    messages: history,
                    context: context
                ) { [weak self] chunk in
                    Task { @MainActor in
                        guard let self, self.runId == run else { return }
                        self.streamingText += chunk
                    }
                }
                guard let self, self.runId == run else { return }
                self.messages = nextMessages + [ProfTutorMessage(role: .assistant, text: answer)]
                self.streamingText = ""
                self.status = .ready
            } catch {
                self?.fail(error, run: run)
            }
        }
    }

    /// `close` : interrompt le flux et remet la session à zéro.
    func close() {
        stopStream()
        request = nil
        messages = []
        streamingText = ""
        status = .idle
        error = ""
    }

    // MARK: Interne

    /// `stopStream` : invalide la course en cours et annule le transport.
    private func stopStream() {
        runId += 1
        streamTask?.cancel()
        streamTask = nil
    }

    /// Une exécution tardive (course dépassée ou annulée) n'écrit jamais.
    private func fail(_ error: Error, run: Int) {
        guard runId == run, !Task.isCancelled else { return }
        status = .error
        self.error = profErrorMessage(error)
    }
}

/// `failure.message` de la source, avec le repli « Le prof IA est indisponible. ».
func profErrorMessage(_ error: Error) -> String {
    if let localized = error as? LocalizedError,
       let description = localized.errorDescription,
       !description.isEmpty {
        return description
    }
    let text = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
    return text.isEmpty ? "Le prof IA est indisponible." : text
}

/// `passage` du rejeu de `send` (`useProfTutor.ts:152-157`) : la photo
/// expliquée, le passage cité, ou rien pour une question libre.
func profReplayPassage(_ request: ProfTutorRequest) -> [ProfTutorMessage] {
    if request.image != nil {
        return [
            ProfTutorMessage(role: .user, text: "Photo de cours expliquée, en appui de la réponse."),
        ]
    }
    guard !request.quote.isEmpty else { return [] }
    return [ProfTutorMessage(role: .user, text: "Passage expliqué : \(request.quote)")]
}
