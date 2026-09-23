//
//  DictAsrRelay+Capture.swift
//  Duello
//
//  Capture audio du relais ASR : tap PCM16 mono 16 kHz
//  (`useAudioStream({sampleRate:16_000, channels:1, encoding:'int16'})`) et
//  conversion depuis le format de l'entrée. Sans `AVFoundation`, aucune capture
//  n'est possible : le modèle bascule sur le repli `device` (`fallbackToDevice`).
//
//  Cible : iOS 16. Aucune dépendance externe.
//

import Foundation
#if canImport(AVFoundation)
import AVFoundation
#endif

#if canImport(AVFoundation)
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
