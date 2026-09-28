//
//  DictSpeechEngine.swift
//  Duello
//
//  Adaptateur du moteur natif de dictée (Speech + AVFoundation), porté de la
//  partie « device » de `src/hooks/useDictation.ts`.
//
//  Porté aussi : l'activation de la session audio (`setAudioModeAsync` de
//  `startFunAsr`, l.662-666), la demande d'accès au micro
//  (`requestRecordingPermissionsAsync`, l.653) et la reconnaissance continue —
//  la source relance `startDeviceRecognition` 250 ms après la fin d'un moteur
//  qui s'arrête sur un silence (l.203-214).
//
//  LIMITE ASSUMÉE : `Speech`/`AVFoundation` n'existent pas sur la machine de
//  portage et ce fichier n'y est donc ni parsé ni typé. Il est isolé derrière
//  `#if canImport(Speech) && canImport(AVFoundation)` pour ne jamais peser sur
//  les cibles qui ne les embarquent pas ; il doit être relu et compilé sur le Mac.
//
//  Cible : iOS 16. Aucune dépendance externe.
//

#if canImport(Speech) && canImport(AVFoundation)
import Foundation
import Speech
import AVFoundation

/// Moteur natif : reconnaissance sur l'appareil via `SFSpeechRecognizer`.
@available(iOS 16.0, *)
final class DictSpeechEngine: DictEngine {
    var onEvent: ((DictAsrEvent) -> Void)?

    /// Délai de relance de la reconnaissance après une fin (`restartTimer` 250 ms).
    static let restartDelayMs: UInt64 = 250

    private let locale: Locale
    private let audioEngine = AVAudioEngine()
    private var recognizer: SFSpeechRecognizer?
    private var requete: SFSpeechAudioBufferRecognitionRequest?
    private var tache: SFSpeechRecognitionTask?
    private var phraseId = 0
    private var enCours = false
    /// L'arrêt est voulu : une fin de reconnaissance ne doit plus relancer.
    private var arretDemande = false

    init(locale: Locale = Locale(identifier: "fr-FR")) {
        self.locale = locale
    }

    func start() async throws {
        let statut = await DictSpeechEngine.demanderAutorisation()
        guard statut == .authorized else { throw DictError.permissionDenied }
        guard await DictSpeechEngine.demanderMicro() else { throw DictError.permissionDenied }
        guard let recognizer = SFSpeechRecognizer(locale: locale), recognizer.isAvailable else {
            throw DictError.engineUnavailable
        }
        self.recognizer = recognizer
        activerSessionAudio()

        let requete = SFSpeechAudioBufferRecognitionRequest()
        requete.shouldReportPartialResults = true
        self.requete = requete
        onEvent?(.authorized)

        let entree = audioEngine.inputNode
        entree.installTap(onBus: 0, bufferSize: 1024, format: entree.outputFormat(forBus: 0)) { [weak self] buffer, _ in
            self?.requete?.append(buffer)
        }
        audioEngine.prepare()
        try audioEngine.start()
        enCours = true
        arretDemande = false

        tache = recognizer.recognitionTask(with: requete) { [weak self] resultat, erreur in
            self?.recevoir(resultat, erreur)
        }
    }

    func stop() {
        arreter(signal: true)
    }

    func cancel() {
        arreter(signal: false)
    }

    /// Applique un résultat de reconnaissance ; relance l'écoute si le moteur
    /// s'est arrêté sur un silence alors que la dictée est toujours voulue.
    private func recevoir(_ resultat: SFSpeechRecognitionResult?, _ erreur: Error?) {
        if let resultat {
            onEvent?(.transcript(
                text: resultat.bestTranscription.formattedString,
                isFinal: resultat.isFinal, sentenceId: phraseId,
                beginTime: 0, endTime: 0
            ))
            if resultat.isFinal {
                phraseId += 1
                redemarrerReconnaissance()
            }
        }
        if erreur != nil, !arretDemande { arreter(signal: false) }
    }

    /// Relance une reconnaissance neuve après une fin, sans couper la capture —
    /// `startDeviceRecognition` (`continuous: true`).
    private func redemarrerReconnaissance() {
        guard enCours, !arretDemande, let recognizer else { return }
        tache?.cancel()
        requete?.endAudio()
        let nouvelle = SFSpeechAudioBufferRecognitionRequest()
        nouvelle.shouldReportPartialResults = true
        requete = nouvelle
        tache = recognizer.recognitionTask(with: nouvelle) { [weak self] resultat, erreur in
            self?.recevoir(resultat, erreur)
        }
    }

    /// Arrête la capture et la reconnaissance, en signalant la fin si demandé.
    private func arreter(signal: Bool) {
        guard enCours else { return }
        enCours = false
        arretDemande = true
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        requete?.endAudio()
        tache?.finish()
        requete = nil
        tache = nil
        desactiverSessionAudio()
        if signal { onEvent?(.done(refined: false, model: nil)) }
    }

    /// Active la session audio avant capture — `setAudioModeAsync`.
    private func activerSessionAudio() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.record, mode: .measurement, options: [.duckOthers])
        try? session.setActive(true)
    }

    /// Rend la session audio au système.
    private func desactiverSessionAudio() {
        try? AVAudioSession.sharedInstance().setActive(
            false, options: .notifyOthersOnDeactivation
        )
    }

    /// Demande l'autorisation de reconnaissance vocale — `requestAuthorization`.
    static func demanderAutorisation() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { statut in
                continuation.resume(returning: statut)
            }
        }
    }

    /// Demande l'accès au micro — `requestRecordingPermissionsAsync`.
    static func demanderMicro() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { accordee in
                continuation.resume(returning: accordee)
            }
        }
    }
}
#endif
