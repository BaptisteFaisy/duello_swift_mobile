//
//  DictControlView.swift
//  Duello
//
//  Portage de `src/hooks/useDictation.ts` (états `isListening`/`isFormatting`/
//  `processingStage`/`engine`/`error`/`notice`) et des libellés du bouton micro
//  de `src/components/event/EventAnswerFields.tsx`.
//
//  Le bouton réutilise `MathKbActionKey` (MathKbControls.swift) pour son chrome
//  et ses états. Le moteur réel n'étant pas vérifiable ici, le modèle utilise
//  `DictSimulatedEngine` par défaut ; `DictSpeechEngine` peut être injecté sur
//  l'appareil via l'initialiseur.
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

    private var moteurActif: DictEngine?
    private var transcription = ""
    private let permission: () async -> Bool
    private let fabriquerMoteur: () -> DictEngine

    init(
        permission: @escaping () async -> Bool = { true },
        fabriquerMoteur: @escaping () -> DictEngine = { DictSimulatedEngine() }
    ) {
        self.permission = permission
        self.fabriquerMoteur = fabriquerMoteur
    }

    /// Démarre la dictée, ou l'arrête si elle est déjà en cours — `toggle`.
    func toggle(currentText: String, math: Bool, permissionMessage: String, apply: @escaping (String) -> Void) async {
        if isListening {
            await arreter(currentText: currentText, math: math, apply: apply)
            return
        }
        await demarrer(permissionMessage: permissionMessage)
    }

    /// Résout l'accès puis lance le moteur.
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
            error = "La dictée vocale n’est pas disponible dans ce navigateur. Ouvre Duello avec Chrome ou Safari, puis réessaie."
            return
        }

        transcription = ""
        let moteur = fabriquerMoteur()
        moteur.onEvent = { [weak self] evenement in
            Task { @MainActor in self?.recevoir(evenement) }
        }
        moteurActif = moteur
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
        notice = "Écoute en cours : parle jusqu’au bout, puis appuie sur Arrêter. La phrase complète apparaîtra ensuite."
    }

    /// Applique un événement du moteur au fil courant.
    func recevoir(_ evenement: DictAsrEvent) {
        switch evenement {
        case let .transcript(text, isFinal, _, _, _):
            if isFinal { transcription = text }
        case let .error(code, message):
            if !code.isEmpty {
                error = message.isEmpty
                    ? "La dictée n’a pas abouti. Tu peux réessayer ou écrire directement."
                    : message
            }
        default:
            break
        }
    }

    /// Arrête le moteur et ajoute la transcription rendue au champ.
    func arreter(currentText: String, math: Bool, apply: @escaping (String) -> Void) async {
        moteurActif?.stop()
        moteurActif = nil
        isListening = false
        engine = nil

        let brut = transcription.trimmingCharacters(in: .whitespacesAndNewlines)
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
    }

    /// Annule la dictée sans transcription — `cancel`.
    func annuler() {
        moteurActif?.cancel()
        moteurActif = nil
        isListening = false
        engine = nil
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
