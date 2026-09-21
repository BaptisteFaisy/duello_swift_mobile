//
//  DictEngine.swift
//  Duello
//
//  Portage de `src/utils/realtimeAsr.ts` et du volet moteur de
//  `src/hooks/useDictation.ts` : abstraction du moteur de reconnaissance
//  (`DictEngine`) et son repli simulé.
//
//  Le moteur réel (Speech/AVFoundation, relais temps réel) n'est pas vérifiable
//  sur la machine de portage : il vit derrière `#if canImport` dans
//  `DictSpeechEngine.swift`. Le protocole et `DictSimulatedEngine` sont, eux,
//  portables et testables.
//
//  Cible : iOS 16. Aucune dépendance externe.
//

import Foundation

/// Moteur de reconnaissance vocale — contrat commun au moteur natif et au relais.
protocol DictEngine: AnyObject {
    /// Reçoit chaque événement du moteur (autorisation, prêt, transcription, fin).
    var onEvent: ((DictAsrEvent) -> Void)? { get set }
    /// Démarre la capture et la reconnaissance.
    func start() async throws
    /// Arrête proprement et rend la transcription finale.
    func stop()
    /// Annule sans attendre de transcription finale.
    func cancel()
}

/// Moteur réellement utilisé — `DictationEngine` de la source.
enum DictEngineKind: String {
    case qwenAsr = "qwen-asr"
    case funAsr = "fun-asr"
    case scribeV2 = "scribe-v2"
    case device
}

/// Moteur simulé, utilisé hors appareil : émet un événement par étape.
///
/// Il remplace le moteur natif (indisponible ici) et documente la limite : la
/// transcription livrée est celle fournie à l'initialisation.
final class DictSimulatedEngine: DictEngine {
    var onEvent: ((DictAsrEvent) -> Void)?

    private let transcription: String
    private var enCours = false

    init(transcription: String = "") {
        self.transcription = transcription
    }

    func start() async throws {
        enCours = true
        onEvent?(.authorized)
        onEvent?(.ready(model: "simule", sampleRate: 16_000))
        onEvent?(.transcript(
            text: transcription, isFinal: true, sentenceId: 0, beginTime: 0, endTime: 0
        ))
    }

    func stop() {
        if enCours { onEvent?(.done(refined: false, model: "simule")) }
        enCours = false
    }

    func cancel() {
        enCours = false
    }
}
