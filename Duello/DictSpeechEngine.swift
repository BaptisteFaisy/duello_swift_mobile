//
//  DictSpeechEngine.swift
//  Duello
//
//  Adaptateur du moteur natif de dictée (Speech + AVFoundation), porté de la
//  partie « device » de `src/hooks/useDictation.ts`.
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

    private let locale: Locale
    private let audioEngine = AVAudioEngine()
    private var requete: SFSpeechAudioBufferRecognitionRequest?
    private var tache: SFSpeechRecognitionTask?
    private var phraseId = 0
    private var enCours = false

    init(locale: Locale = Locale(identifier: "fr-FR")) {
        self.locale = locale
    }

    func start() async throws {
        let statut = await DictSpeechEngine.demanderAutorisation()
        guard statut == .authorized else { throw DictError.permissionDenied }
        guard let recognizer = SFSpeechRecognizer(locale: locale), recognizer.isAvailable else {
            throw DictError.engineUnavailable
        }

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

        tache = recognizer.recognitionTask(with: requete) { [weak self] resultat, erreur in
            guard let self else { return }
            if let resultat {
                self.onEvent?(.transcript(
                    text: resultat.bestTranscription.formattedString,
                    isFinal: resultat.isFinal, sentenceId: self.phraseId,
                    beginTime: 0, endTime: 0
                ))
                if resultat.isFinal { self.phraseId += 1 }
            }
            if erreur != nil { self.arreter(signal: false) }
        }
    }

    func stop() {
        arreter(signal: true)
    }

    func cancel() {
        arreter(signal: false)
    }

    /// Arrête la capture et la reconnaissance, en signalant la fin si demandé.
    private func arreter(signal: Bool) {
        guard enCours else { return }
        enCours = false
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        requete?.endAudio()
        tache?.finish()
        requete = nil
        tache = nil
        if signal { onEvent?(.done(refined: false, model: nil)) }
    }

    /// Demande l'autorisation de reconnaissance vocale — `requestAuthorization`.
    static func demanderAutorisation() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { statut in
                continuation.resume(returning: statut)
            }
        }
    }
}
#endif
