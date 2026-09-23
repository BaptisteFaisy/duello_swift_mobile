//
//  DictEngine.swift
//  Duello
//
//  Portage de `src/utils/realtimeAsr.ts` et du volet moteur de
//  `src/hooks/useDictation.ts` : abstraction du moteur de reconnaissance
//  (`DictEngine`), sélection du moteur (`DictEngineKind`) et fabrique par défaut.
//
//  Le moteur réellement branché est le moteur natif de l'appareil
//  (`DictSpeechEngine`, Speech/AVFoundation) ; le relais temps réel premium est
//  le client WebSocket `DictAsrRelay`. `DictSimulatedEngine` ne sert plus que de
//  repli documenté là où aucun moteur n'existe (cibles sans Speech/AVFoundation),
//  afin de ne jamais laisser la dictée muette sans le dire.
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

    /// Moteur déduit du modèle annoncé par le relais — `useDictation.ts`
    /// (`ready.model.startsWith('qwen')`, `'scribe_v2'`, sinon Fun-ASR).
    static func fromModel(_ model: String) -> DictEngineKind {
        if model.hasPrefix("qwen") { return .qwenAsr }
        if model.hasPrefix("scribe_v2") { return .scribeV2 }
        return .funAsr
    }
}

/// Fabrique du moteur par défaut — `useDictation` démarre toujours sur un moteur
/// réel (relais premium, sinon reconnaissance du téléphone).
enum DictEngineFactory {
    /// Moteur réel de l'appareil (`DictSpeechEngine`), ou repli simulé documenté.
    ///
    /// Sur les cibles sans `Speech`/`AVFoundation` (machine de portage), aucun
    /// moteur natif n'existe : `DictSimulatedEngine` rejoue alors la
    /// transcription fournie pour ne pas casser l'interface, limite assumée et
    /// signalée par son nom.
    static func moteurParDefaut() -> DictEngine {
        #if canImport(Speech) && canImport(AVFoundation)
        if #available(iOS 16.0, *) { return DictSpeechEngine() }
        #endif
        return DictSimulatedEngine()
    }
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
