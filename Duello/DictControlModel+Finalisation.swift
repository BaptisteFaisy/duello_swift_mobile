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

    /// Délai de la seconde passe — `OPENAI_MATH_TIMEOUT_MS` (`useDictation.ts:79`).
    static let delaiSecondePasse: UInt64 = 180

    /// Notice quand une correction manuelle prime sur un résultat tardif
    /// (`useDictation.ts:369-371`).
    static let noticeTexteModifie =
        "Le texte a été modifié pendant l’analyse : ta version a été conservée."

    /// Notice quand la seconde passe dépasse son délai (`useDictation.ts:404-408`).
    static let noticeDelai =
        "La mise en forme a pris trop de temps : la transcription a été conservée."

    /// Seconde passe [OI] : le relais repère les passages mathématiques et rend
    /// la phrase complète, sans remplacer les hypothèses mot après mot.
    ///
    /// `apercu` est le texte provisoire posé avant la passe et `lireTexte` le
    /// lecteur du texte vivant du champ : ensemble ils portent la garde « le
    /// texte a été modifié » de la source (un résultat tardif n'écrase jamais le
    /// travail manuel). À raccorder (lot IMPL-09) : `arreter` (DictControlView)
    /// doit fournir `apercu` et `lireTexte`, et l'hôte poser
    /// `contexteTranscription` avant `toggle`.
    func finaliser(
        brut: String,
        prefixe: String,
        apercu: String = "",
        lireTexte: (() -> String)? = nil,
        apply: @escaping (String) -> Void
    ) async {
        guard let relais = relaisConfigure, !brut.isEmpty else {
            isFormatting = false
            stage = nil
            notice = ""
            return
        }
        let generation = dictationRequest
        let contexte = contexteTranscription
        isFormatting = true
        stage = .openai
        notice = ""
        do {
            let resultat = try await Self.avecDelai(secondes: Self.delaiSecondePasse) {
                try await DictMathFormatter.format(
                    relayEndpoint: relais.endpoint,
                    token: relais.token,
                    rawText: brut,
                    context: contexte
                )
            }
            // Une demande remplacée n'écrit jamais (`run !== dictationRun.current`).
            guard generation == dictationRequest else { return }
            // Une correction manuelle faite pendant la seconde passe prime sur [OI].
            if !apercu.isEmpty, let lireTexte, lireTexte() != apercu {
                notice = Self.noticeTexteModifie
                isFormatting = false
                stage = nil
                return
            }
            let rendu = LatexToUnicode.toUnicodeMath(resultat.text)
            apply(DictPolicy.appendTranscript(prefixe, rendu))
            notice = Self.noticeAmbiguite(resultat.ambiguities.count)
        } catch {
            guard generation == dictationRequest else { return }
            notice = (error is DictDelaiSecondePasse)
                ? Self.noticeDelai
                : "La mise en forme est indisponible : la transcription a été conservée."
        }
        isFormatting = false
        stage = nil
    }

    /// Minuteur de la seconde passe : abandonne l'appel au bout de `secondes`
    /// (équivalent du `setTimeout(… abort)` de `useDictation.ts:351-354`).
    static func avecDelai<T>(
        secondes: UInt64,
        _ operation: @escaping () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { groupe in
            groupe.addTask { try await operation() }
            groupe.addTask {
                try await Task.sleep(nanoseconds: secondes * 1_000_000_000)
                throw DictDelaiSecondePasse()
            }
            guard let premier = try await groupe.next() else {
                throw DictDelaiSecondePasse()
            }
            groupe.cancelAll()
            return premier
        }
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

/// Délai dépassé par la seconde passe (`timedOut` de `useDictation.ts:352-354`).
struct DictDelaiSecondePasse: Error {}
