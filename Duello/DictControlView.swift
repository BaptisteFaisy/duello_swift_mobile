//
//  DictControlView.swift
//  Duello
//
//  Portage de `src/hooks/useDictation.ts` (états `isListening`/`isFormatting`/
//  `processingStage`/`engine`/`error`/`notice`, `toggle`/`stop`/`cancel`) et des
//  libellés du bouton micro de `src/components/event/EventAnswerFields.tsx`.
//
//  Le bouton réutilise `MathKbActionKey` (MathKbControls.swift) pour son chrome
//  et ses états. Le moteur branché par défaut est le moteur réel : le relais
//  temps réel `DictAsrRelay` quand une configuration premium est fournie
//  (`configurationRelais`), sinon le moteur natif de l'appareil
//  (`DictEngineFactory.moteurParDefaut`). `DictSimulatedEngine` ne reste que
//  comme repli documenté des cibles sans Speech/AVFoundation.
//
//  Cible : iOS 16. Aucune dépendance externe.
//

import SwiftUI
import Combine

/// Étape de finalisation visible — `DictationProcessingStage` de la source.
enum DictProcessingStage: String {
    case alibaba
    case openai
}

/// Modèle du contrôle de dictée — états de `useDictation`.
@MainActor
final class DictControlModel: ObservableObject {
    @Published private(set) var isListening = false
    @Published private(set) var isFormatting = false
    @Published private(set) var stage: DictProcessingStage?
    @Published private(set) var engine: DictEngineKind?
    @Published private(set) var error = ""
    @Published private(set) var notice = ""

    /// Invite affichée pendant l'écoute (`useDictation`).
    static let noticeEcoute =
        "Écoute en cours : parle jusqu’au bout, puis appuie sur Arrêter. La phrase complète apparaîtra ensuite."

    private var moteurActif: DictEngine?
    private var transcription = ""
    private var phrases = DictTranscriptState.empty
    private var texteComplet = ""
    private let permission: () async -> Bool
    private let fabriquerMoteur: () -> DictEngine
    private let configurationRelais: () -> DictRelayConfig?

    init(
        permission: @escaping () async -> Bool = { true },
        fabriquerMoteur: @escaping () -> DictEngine = { DictEngineFactory.moteurParDefaut() },
        configurationRelais: @escaping () -> DictRelayConfig? = { nil }
    ) {
        self.permission = permission
        self.fabriquerMoteur = fabriquerMoteur
        self.configurationRelais = configurationRelais
    }

    /// Démarre la dictée, ou l'arrête si elle est déjà en cours — `toggle`.
    func toggle(currentText: String, math: Bool, permissionMessage: String, apply: @escaping (String) -> Void) async {
        if isListening {
            await arreter(currentText: currentText, math: math, apply: apply)
            return
        }
        await demarrer(permissionMessage: permissionMessage)
    }

    /// Résout l'accès puis lance le moteur (relais premium, sinon appareil).
    func demarrer(permissionMessage: String) async {
        error = ""
        notice = ""

        let acces = await DictPolicy.resolveAccess(
            isWeb: false,
            recognitionAvailable: { true },
            requestWebMicrophonePermission: { await permission() },
            requestNativeSpeechPermission: { await permission() }
        )
        switch acces {
        case .granted:
            break
        case .denied:
            error = permissionMessage
            return
        case .unavailable:
            error = "La reconnaissance vocale n’est pas disponible sur cet appareil. Autorise la dictée dans les réglages iOS, puis réessaie."
            return
        }

        transcription = ""
        phrases = .empty
        texteComplet = ""

        // Mode premium : le relais temps réel d'abord, s'il est configuré.
        if let relais = configurationRelais() {
            let moteur = DictAsrRelay(config: relais)
            brancher(moteur)
            engine = relais.kind
            do {
                try await moteur.start()
                isListening = true
                notice = Self.noticeEcoute
                return
            } catch {
                // Repli `device` : reconnaissance du téléphone (`fallbackToDevice`).
                notice = DictError.engineUnavailable.errorDescription ?? ""
                moteurActif = nil
            }
        }

        let moteur = fabriquerMoteur()
        brancher(moteur)
        engine = .device
        do {
            try await moteur.start()
        } catch {
            self.error = (error as? LocalizedError)?.errorDescription
                ?? "La dictée n’a pas abouti. Tu peux réessayer ou écrire directement."
            moteurActif = nil
            engine = nil
            return
        }
        isListening = true
        if notice.isEmpty { notice = Self.noticeEcoute }
    }

    /// Branche un moteur sur le fil des événements de l'interface.
    private func brancher(_ moteur: DictEngine) {
        moteur.onEvent = { [weak self] evenement in
            Task { @MainActor in self?.recevoir(evenement) }
        }
        moteurActif = moteur
    }

    /// Applique un événement du moteur au fil courant.
    func recevoir(_ evenement: DictAsrEvent) {
        switch evenement {
        case .authorized:
            break
        case let .ready(model, _):
            engine = DictEngineKind.fromModel(model)
        case let .transcript(text, isFinal, _, _, _):
            phrases = DictPolicy.applyTranscript(phrases, evenement)
            if isFinal { transcription = text }
        case .refining:
            isFormatting = true
            stage = .alibaba
        case let .fullTranscript(text, _):
            texteComplet = text
        case .refinementError:
            notice = "La finalisation de la transcription est indisponible."
        case let .error(code, message):
            if !code.isEmpty {
                error = message.isEmpty
                    ? "La dictée n’a pas abouti. Tu peux réessayer ou écrire directement."
                    : message
            }
        case .done:
            break
        }
    }

    /// Arrête le moteur et ajoute la transcription rendue au champ.
    func arreter(currentText: String, math: Bool, apply: @escaping (String) -> Void) async {
        let moteur = moteurActif
        moteur?.stop()
        // Le relais rend la phrase complète après la seconde passe : on attend
        // sa fin (`done` ou délai) avant de lire le résultat.
        if let relais = moteur as? DictAsrRelay { await relais.attendreFin() }
        moteurActif = nil
        isListening = false
        engine = nil

        let choisie = DictPolicy.selectCompletedTranscript(phrases, fullText: texteComplet).text
        let brut = (choisie.isEmpty ? transcription : choisie)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !brut.isEmpty else {
            error = "Aucune parole exploitable n’a été reconnue. Tu peux réessayer ou écrire directement."
            notice = ""
            return
        }

        isFormatting = true
        stage = .alibaba
        let rendu = DictPolicy.renderTranscript(brut, math: math)
        apply(DictPolicy.appendTranscript(currentText, rendu))
        isFormatting = false
        stage = nil
        notice = ""
        error = ""
        phrases = .empty
        texteComplet = ""
    }

    /// Annule la dictée sans transcription — `cancel`.
    func annuler() {
        moteurActif?.cancel()
        moteurActif = nil
        isListening = false
        engine = nil
        transcription = ""
        phrases = .empty
        texteComplet = ""
    }
}

/// Bouton micro et états de dictée — contrat `DictControlView`.
struct DictControlView: View {
    var permissionMessage = "Autorise le micro et la reconnaissance vocale pour dicter ta réponse."
    var math = true
    let text: String
    let appliquer: (String) -> Void

    @StateObject private var model = DictControlModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                MathKbActionKey(
                    accessibility: model.isListening ? "Arrêter la dictée" : "Dicter la réponse",
                    systemImage: model.isListening ? "stop.fill" : "mic",
                    highlighted: model.isListening
                ) {
                    Task {
                        await model.toggle(
                            currentText: text, math: math,
                            permissionMessage: permissionMessage, apply: appliquer
                        )
                    }
                }
                Text(model.isListening ? "Écoute…" : "Dicter")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(Theme.inkSoft)
                if model.isFormatting {
                    ProgressView()
                }
                Spacer()
            }
            if !model.error.isEmpty {
                Text(model.error)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.like)
            }
            if !model.notice.isEmpty {
                Text(model.notice)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.inkFaint)
            }
        }
        .duelloCard()
    }
}
