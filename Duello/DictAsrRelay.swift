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

import Foundation
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
    private var connectTimeoutTask: Task<Void, Never>?
    private var finishTimeoutTask: Task<Void, Never>?

    private var enCours = false
    private var providerReady = false
    private var startSent = false
    private var stopSent = false
    private var doneEmis = false
    private var pendingPcm: [Data] = []
    private var pendingPcmBytes = 0

    private var connexionContinuation: CheckedContinuation<Void, Error>?
    private var finContinuation: CheckedContinuation<Void, Never>?
    private var finAtteinte = false

    #if canImport(AVFoundation)
    private let audioEngine = AVAudioEngine()
    private var format16k: AVAudioFormat?
    private var convertisseur: AVAudioConverter?
    #endif

    init(config: DictRelayConfig, session: URLSession = .shared) {
        self.config = config
        self.session = session
    }

    // MARK: Endpoint par moteur

    /// Route WebSocket du relais pour un moteur voulu — `realtimeAsrWebSocketUrl`.
    ///
    /// La source ne sert qu'une seule route vocale (`<endpoint>/asr`) : le relais
    /// y choisit lui-même Fun-ASR, Qwen-ASR puis Scribe v2. `kind` désigne donc
    /// le moteur *préféré* du client ; `DictEngineKind.device` n'emprunte pas le
    /// relais et rend `nil` (repli sur le moteur natif de l'appareil).
    static func endpoint(for kind: DictEngineKind, relayEndpoint: String) throws -> URL? {
        guard kind != .device else { return nil }
        guard let url = URL(string: try DictPolicy.realtimeAsrUrl(relayEndpoint)) else {
            throw DictError.invalidRelay
        }
        return url
    }

    /// Route WebSocket effective de la configuration.
    static func webSocketURL(for config: DictRelayConfig) throws -> URL {
        guard let url = try endpoint(for: config.kind, relayEndpoint: config.endpoint) else {
            throw DictError.invalidRelay
        }
        return url
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

    /// Attend la fin du relais (`done` ou délai de finalisation) — `stop()` async.
    func attendreFin() async {
        if finAtteinte { return }
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            if finAtteinte { continuation.resume(); return }
            finContinuation = continuation
        }
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
    private func envoyer(_ pcm: Data) {
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

    // MARK: Connexion / fin (continuations)

    private func attendreConnexion() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connexionContinuation = continuation
            connectTimeoutTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(Self.connectTimeout * 1_000_000_000))
                guard !Task.isCancelled else { return }
                self?.signalerConnexion(erreur: DictError.engineUnavailable)
            }
        }
    }

    private func signalerConnexion(erreur: Error?) {
        guard let continuation = connexionContinuation else { return }
        connexionContinuation = nil
        connectTimeoutTask?.cancel()
        connectTimeoutTask = nil
        if let erreur { continuation.resume(throwing: erreur) } else { continuation.resume() }
    }

    private func signalerFin() {
        finAtteinte = true
        if let continuation = finContinuation {
            finContinuation = nil
            continuation.resume()
        }
    }
}

#if canImport(AVFoundation)
import AVFoundation

extension DictAsrRelay {
    /// Démarre la capture PCM16 mono 16 kHz
    /// (`useAudioStream({sampleRate:16_000, channels:1, encoding:'int16'})`).
    func demarrerCapture() {
        let entree = audioEngine.inputNode
        let formatEntree = entree.outputFormat(forBus: 0)
        let cible = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: Self.sampleRate,
            channels: 1,
            interleaved: true
        )
        format16k = cible
        convertisseur = cible.flatMap { AVAudioConverter(from: formatEntree, to: $0) }
        entree.installTap(onBus: 0, bufferSize: 1024, format: formatEntree) { [weak self] buffer, _ in
            guard let self, let data = self.pcm16(from: buffer) else { return }
            self.envoyer(data)
        }
        audioEngine.prepare()
        try? audioEngine.start()
    }

    /// Arrête la capture et retire le tap.
    func arreterCapture() {
        guard audioEngine.isRunning else { return }
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
    }

    /// Convertit un buffer capté en PCM16 mono, moyenné sans écrêtage.
    private func pcm16(from buffer: AVAudioPCMBuffer) -> Data? {
        guard let format16k, let convertisseur else { return nil }
        let ratio = format16k.sampleRate / buffer.format.sampleRate
        let capacite = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 1
        guard let sortie = AVAudioPCMBuffer(pcmFormat: format16k, frameCapacity: capacite) else {
            return nil
        }
        var erreur: NSError?
        var fourni = false
        let statut = convertisseur.convert(to: sortie, error: &erreur) { _, etatSortie in
            if fourni {
                etatSortie.pointee = .noDataNow
                return nil
            }
            fourni = true
            etatSortie.pointee = .haveData
            return buffer
        }
        guard statut != .error, let canal = sortie.int16ChannelData else { return nil }
        let trames = Int(sortie.frameLength)
        let brut = Data(bytes: canal[0], count: trames * MemoryLayout<Int16>.size)
        return DictPolicy.monoPcm16(brut, channels: Int(format16k.channelCount))
    }
}
#else
extension DictAsrRelay {
    /// Sans `AVFoundation`, aucune capture audio n'est possible : le relais ne
    /// peut pas alimenter le relais et le modèle bascule sur le repli `device`.
    func demarrerCapture() {}
    /// Sans `AVFoundation`, il n'y a aucun tap à retirer.
    func arreterCapture() {}
}
#endif
