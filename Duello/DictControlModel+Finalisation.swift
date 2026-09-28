//
//  DictControlModel+Finalisation.swift
//  Duello
//
//  Seconde passe de la dictée (`formatFinalTranscript`) et repli `device` en
//  cours de flux (`fallbackToDevice`), extraits de `DictControlModel`
//  (`DictControlView.swift`) pour tenir les limites de complexité.
//
//  Fichiers source Expo portés : `src/hooks/useDictation.ts`
//  (`formatFinalTranscript`, `fallbackToDevice`).
//
//  Cible : iOS 16. Aucune dépendance externe.
//

import Foundation

extension DictControlModel {
    /// Message d'ambiguïté de la seconde passe — `useDictation.ts` (l.384-388).
    static func noticeAmbiguite(_ count: Int) -> String {
        guard count > 0 else { return "" }
        return count > 1
            ? "\(count) passages réellement ambigus ont été conservés tels qu’entendus."
            : "1 passage réellement ambigu a été conservé tel qu’entendu."
    }

    /// Seconde passe [OI] : le relais repère les passages mathématiques et rend
    /// la phrase complète, sans remplacer les hypothèses mot après mot.
    func finaliser(brut: String, prefixe: String, apply: @escaping (String) -> Void) async {
        guard let relais = relaisConfigure, !brut.isEmpty else {
            isFormatting = false
            stage = nil
            notice = ""
            return
        }
        isFormatting = true
        stage = .openai
        notice = ""
        do {
            let resultat = try await DictMathFormatter.format(
                relayEndpoint: relais.endpoint,
                token: relais.token,
                rawText: brut,
                context: contexteTranscription
            )
            guard !Task.isCancelled else { return }
            let rendu = LatexToUnicode.toUnicodeMath(resultat.text)
            apply(DictPolicy.appendTranscript(prefixe, rendu))
            notice = Self.noticeAmbiguite(resultat.ambiguities.count)
        } catch {
            notice = "La mise en forme est indisponible : la transcription a été conservée."
        }
        isFormatting = false
        stage = nil
    }

    /// Repli `device` en cours de flux : le relais est abandonné et la
    /// reconnaissance du téléphone reprend (`fallbackToDevice`).
    func basculerSurAppareil(notice message: String) async {
        guard isListening else { return }
        moteurActif?.cancel()
        moteurActif = nil
        let moteur = fabriquerMoteur()
        brancher(moteur)
        engine = .device
        notice = message.isEmpty ? DictRelayText.serviceIndisponible : message
        do {
            try await moteur.start()
        } catch {
            self.error = (error as? LocalizedError)?.errorDescription
                ?? DictError.engineUnavailable.errorDescription ?? ""
            moteurActif = nil
            isListening = false
            engine = nil
        }
    }
}
