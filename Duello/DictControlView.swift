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
    @Published var isListening = false
    @Published var isFormatting = false
    @Published var stage: DictProcessingStage?
    @Published var engine: DictEngineKind?
    @Published var error = ""
    @Published var notice = ""

    /// Invite affichée pendant l'écoute (`useDictation`).
    static let noticeEcoute =
        "Écoute en cours : parle jusqu’au bout, puis appuie sur Arrêter. La phrase complète apparaîtra ensuite."

    /// Énoncé visible, fourni à [OI] comme aide de désambiguïsation
    /// (`transcriptionContext`), figé avec la phrase.
    var contexteTranscription: DictMathContext?

    var moteurActif: DictEngine?
    var transcription = ""
    var phrases = DictTranscriptState.empty
    var texteComplet = ""
    /// Relais retenu pour la dictée en cours (`relayEndpoint` / `relayToken`).
    var relaisConfigure: DictRelayConfig?
    /// Génération de la demande courante (`dictationRequest`).
    var dictationRequest = 0
    /// Observateurs d'activité de l'application (`useDictationAppState`).
    var observateurs: [NSObjectProtocol] = []
    let portail: DictAppStateGate
    let permission: () async -> Bool
    let fabriquerMoteur: () -> DictEngine
    let configurationRelais: () -> DictRelayConfig?
    let consentementPartage: () async -> Bool

    init(
        permission: @escaping () async -> Bool = { true },
        fabriquerMoteur: @escaping () -> DictEngine = { DictEngineFactory.moteurParDefaut() },
        configurationRelais: @escaping () -> DictRelayConfig? = { DictRelayConfig.resolve() },
        consentementPartage: @escaping () async -> Bool = { CtdAiConsent.isGranted }
    ) {
        self.permission = permission
        self.fabriquerMoteur = fabriquerMoteur
        self.configurationRelais = configurationRelais
        self.consentementPartage = consentementPartage
        self.observateurs = []
        self.portail = DictAppStateGate(estActif: { DictAppStateGate.applicationIsActive })
        portail.onCancel = { [weak self] in self?.annuler() }
        observateurs = portail.demarrerObservation()
    }

    deinit {
        for observateur in observateurs {
            NotificationCenter.default.removeObserver(observateur)
        }
    }

    /// Démarre la dictée, ou l'arrête si elle est déjà en cours — `toggle`.
    func toggle(currentText: String, math: Bool, permissionMessage: String, apply: @escaping (String) -> Void) async {
        dictationRequest += 1
        if isFormatting { return }
        if isListening {
            await arreter(currentText: currentText, math: math, apply: apply)
            return
        }
        await demarrer(permissionMessage: permissionMessage)
    }

    /// Lie un démarrage différé à la cible courante et l'invalide à l'annulation
    /// (`createToggleRequest`) : une seconde demande périme la première.
    func createToggleRequest(
        currentText: String,
        math: Bool,
        permissionMessage: String,
        apply: @escaping (String) -> Void
    ) -> () -> Void {
        dictationRequest += 1
        let request = dictationRequest
        return { [weak self] in
            guard let self, request == self.dictationRequest else { return }
            Task { @MainActor in
                await self.toggle(
                    currentText: currentText, math: math,
                    permissionMessage: permissionMessage, apply: apply
                )
            }
        }
    }

    /// Résout l'accès puis lance le moteur (relais premium, sinon appareil).
    func demarrer(permissionMessage: String) async {
        error = ""
        notice = ""

        guard await resoudreAcces(permissionMessage: permissionMessage) else { return }

        transcription = ""
        phrases = .empty
        texteComplet = ""

        // Mode premium : consentement au partage, puis relais temps réel.
        relaisConfigure = configurationRelais()
        if let relais = relaisConfigure {
            if await consentementPartage() {
                if await demarrerMoteurRelais(relais) { return }
            } else {
                // `fallbackToDevice` sans transmission : reconnaissance du téléphone.
                notice = DictRelayText.sansPartage
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

    /// Résout l'accès micro/reconnaissance. Renvoie vrai si l'accès est accordé ;
    /// sinon pose `error` (message de permission ou d'indisponibilité) et renvoie faux.
    func resoudreAcces(permissionMessage: String) async -> Bool {
        let acces = await DictPolicy.resolveAccess(
            isWeb: false,
            recognitionAvailable: { true },
            requestWebMicrophonePermission: { await portail.requestPermission { await permission() } },
            requestNativeSpeechPermission: { await portail.requestPermission { await permission() } }
        )
        switch acces {
        case .granted:
            return true
        case .denied:
            error = permissionMessage
            return false
        case .unavailable:
            error = "La reconnaissance vocale n’est pas disponible sur cet appareil. Autorise la dictée dans les réglages iOS, puis réessaie."
            return false
        }
    }

    /// Tente le relais premium. Renvoie vrai s'il a démarré (dictée lancée) ;
    /// sinon laisse le repli `device` s'appliquer au retour dans `demarrer`.
    func demarrerMoteurRelais(_ relais: DictRelayConfig) async -> Bool {
        let moteur = DictAsrRelay(config: relais)
        brancher(moteur)
        engine = relais.kind
        do {
            try await moteur.start()
            isListening = true
            notice = Self.noticeEcoute
            return true
        } catch {
            // Repli `device` : reconnaissance du téléphone (`fallbackToDevice`).
            notice = DictError.engineUnavailable.errorDescription ?? ""
            moteurActif = nil
            return false
        }
    }

    /// Branche un moteur sur le fil des événements de l'interface.
    func brancher(_ moteur: DictEngine) {
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
            if code == "unauthorized" || code == "premium-required" {
                error = DictRelayText.messageErreur(code: code, message: message)
            } else if isListening {
                Task { await basculerSurAppareil(notice: message) }
            } else if !code.isEmpty {
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
        phrases = .empty
        texteComplet = ""
        guard !brut.isEmpty else {
            error = "Aucune parole exploitable n’a été reconnue. Tu peux réessayer ou écrire directement."
            notice = ""
            isFormatting = false
            stage = nil
            return
        }

        // La phrase est posée avant la seconde passe ; celle-ci la corrigera
        // sans remplacer les hypothèses mot après mot.
        let apercu = DictPolicy.appendTranscript(currentText, DictPolicy.renderTranscript(brut, math: math))
        apply(apercu)
        await finaliser(brut: brut, prefixe: currentText, apply: apply)
    }

    /// Annule la dictée sans transcription — `cancel`.
    func annuler() {
        dictationRequest += 1
        moteurActif?.cancel()
        moteurActif = nil
        portail.cancelPending()
        isListening = false
        isFormatting = false
        stage = nil
        engine = nil
        error = ""
        notice = ""
        transcription = ""
        phrases = .empty
        texteComplet = ""
        relaisConfigure = nil
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
