//
//  DictAsrRelay.swift
//  Duello
//
//  Port de `src/hooks/useDictation.ts` (mode premium temps réel : `socketRef`,
//  `startFunAsr`, `handleAudioBuffer`, `maybeSendCloudStop`,
//  `fallbackToDevice`) et de `src/utils/realtimeAsr.ts` : client WebSocket du
//  relais ASR temps réel.
//
//  Le relais permanent Duello reçoit le PCM16 mono capturé par l'appareil et
//  renvoie les événements `DictAsrEvent` (autorisation, prêt, transcription,
//  affinage, fin). L'app ne détient aucune clé de fournisseur : le relais appelle
//  Alibaba `fun-asr-realtime` en français, puis Qwen-ASR et ElevenLabs
//  `scribe_v2_realtime` en secours. Le moteur réellement employé est confirmé par
//  l'événement `ready` (`DictEngineKind.fromModel`).
//
//  Repli `device` : la source ne sert qu'une route vocale (`<endpoint>/asr`) ;
//  `DictEngineKind.device` n'emprunte donc pas le relais, et si la socket ne
//  s'ouvre pas (délai, fermeture, erreur), le modèle bascule sur le moteur natif
//  de l'appareil (`DictSpeechEngine`) — `fallbackToDevice`.
//
//  Cible : iOS 16. Aucune dépendance externe.
//
//  Découpage (limites de complexité) : la résolution de la route WebSocket et
//  les attentes de connexion / de fin vivent dans `DictAsrRelay+Connexion.swift` ;
//  la capture PCM16 dans `DictAsrRelay+Capture.swift`. Les quelques membres
//  partagés entre fichiers sont `internal` (commentés ci-dessous).
//

import Foundation
#if canImport(AVFoundation)
import AVFoundation
#endif
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Configuration du relais ASR (`resolveRelayEndpoint` + jeton de session).
struct DictRelayConfig {
    /// Adresse du relais HTTP : la route vocale `/asr` en est déduite.
    let endpoint: String
    /// Jeton de session Duello, jamais une clé de fournisseur.
    let token: String
    /// Moteur préféré du client ; le relais peut en retenir un autre (`ready`).
    let kind: DictEngineKind

    init(endpoint: String, token: String, kind: DictEngineKind = .funAsr) {
        self.endpoint = endpoint
        self.token = token
        self.kind = kind
    }
}

/// Client WebSocket du relais ASR temps réel — `DictEngine` premium.
final class DictAsrRelay: DictEngine {
    var onEvent: ((DictAsrEvent) -> Void)?

    /// Délais de la source (`useDictation.ts`).
    static let sampleRate: Double = 16_000
    static let connectTimeout: TimeInterval = 8
    static let finishTimeout: TimeInterval = 75
    static let maxQueuedPcmBytes = 1024 * 1024

    private let config: DictRelayConfig
    private let session: URLSession
    private var socket: URLSessionWebSocketTask?
    private var receiveTask: Task<Void, Never>?
    /// `internal` : annulé/posé aussi par `DictAsrRelay+Connexion.swift`.
    var connectTimeoutTask: Task<Void, Never>?
    private var finishTimeoutTask: Task<Void, Never>?

    private var enCours = false
    private var providerReady = false
    private var startSent = false
    private var stopSent = false
    private var doneEmis = false
    private var pendingPcm: [Data] = []
    private var pendingPcmBytes = 0

    /// `internal` : continuations résolues dans `DictAsrRelay+Connexion.swift`.
    var connexionContinuation: CheckedContinuation<Void, Error>?
    var finContinuation: CheckedContinuation<Void, Never>?
    var finAtteinte = false

    #if canImport(AVFoundation)
    /// `internal` : lus/écrits par la capture (`DictAsrRelay+Capture.swift`).
    let audioEngine = AVAudioEngine()
    var format16k: AVAudioFormat?
    var convertisseur: AVAudioConverter?
    #endif

    init(config: DictRelayConfig, session: URLSession = .shared) {
        self.config = config
        self.session = session
    }

    // MARK: Cycle de vie

    func start() async throws {
        let url = try Self.webSocketURL(for: config)
        let task = session.webSocketTask(with: url)
        socket = task
        task.resume()
        enCours = true
        receiveTask = Task { [weak self] in await self?.receiveLoop(task) }
        do {
            // La source attend l'ouverture de la socket avec un délai de connexion.
            try await attendreConnexion()
        } catch {
            cancel()
            throw error
        }
        envoyerStart()
        demarrerCapture()
    }

    func stop() {
        guard enCours else { return }
        // La capture s'arrête après le dernier buffer utile, puis le relais
        // réécoute l'audio entier et rend la phrase complète (`maybeSendCloudStop`).
        #if canImport(AVFoundation)
        arreterCapture()
        #endif
        if startSent, !stopSent, let socket {
            stopSent = true
            socket.send(.string(#"{"type":"stop"}"#)) { _ in }
            finishTimeoutTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(Self.finishTimeout * 1_000_000_000))
                guard !Task.isCancelled else { return }
                self?.fermer(fin: true)
            }
        } else {
            fermer(fin: false)
        }
    }

    func cancel() {
        fermer(fin: false)
    }

    // MARK: Boucle de réception

    private func receiveLoop(_ task: URLSessionWebSocketTask) async {
        while !Task.isCancelled && socket === task {
            do {
                let message = try await task.receive()
                guard socket === task else { return }
                signalerConnexion(erreur: nil)
                switch message {
                case let .string(raw):
                    traiter(raw, task: task)
                case let .data(data):
                    if let raw = String(data: data, encoding: .utf8) { traiter(raw, task: task) }
                @unknown default:
                    break
                }
            } catch {
                signalerConnexion(erreur: DictError.engineUnavailable)
                fermer(fin: true)
                return
            }
        }
    }

    /// Décode un message du relais et applique l'événement (`parseRealtimeAsrEvent`).
    private func traiter(_ raw: String, task: URLSessionWebSocketTask) {
        guard let evenement = DictPolicy.parseEvent(raw) else { return }
        switch evenement {
        case .ready:
            providerReady = true
            for pcm in pendingPcm { task.send(.data(pcm)) { _ in } }
            pendingPcm = []
            pendingPcmBytes = 0
        case .done:
            doneEmis = true
            onEvent?(evenement)
            signalerFin()
            fermer(fin: false)
            return
        default:
            break
        }
        onEvent?(evenement)
    }

    // MARK: Envoi

    private func envoyerStart() {
        guard !startSent, let socket else { return }
        startSent = true
        socket.send(.string(#"{"type":"start","sampleRate":16000}"#)) { _ in }
    }

    /// Envoie un fragment PCM16 mono, ou le met en file pendant l'initialisation.
    ///
    /// `internal` : appelé aussi par la capture (`DictAsrRelay+Capture.swift`).
    func envoyer(_ pcm: Data) {
        guard let socket, !stopSent else { return }
        if providerReady {
            socket.send(.data(pcm)) { _ in }
            return
        }
        // Le premier son ne doit pas disparaître pendant l'initialisation du relais.
        pendingPcm.append(pcm)
        pendingPcmBytes += pcm.count
        if pendingPcmBytes > Self.maxQueuedPcmBytes {
            onEvent?(.error(
                code: "queue-overflow",
                message: "La dictée IA a mis trop de temps à démarrer : reconnaissance du téléphone utilisée."
            ))
        }
    }

    // MARK: Fermeture

    /// Ferme la socket et signale la fin, en émettant `done` une seule fois.
    private func fermer(fin: Bool) {
        connectTimeoutTask?.cancel()
        connectTimeoutTask = nil
        finishTimeoutTask?.cancel()
        finishTimeoutTask = nil
        receiveTask?.cancel()
        receiveTask = nil
        let task = socket
        socket = nil
        task?.cancel(with: .goingAway, reason: nil)
        if enCours {
            enCours = false
            #if canImport(AVFoundation)
            arreterCapture()
            #endif
        }
        if fin, !doneEmis {
            doneEmis = true
            onEvent?(.done(refined: false, model: nil))
        }
        signalerFin()
    }
}
