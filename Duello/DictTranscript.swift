//
//  DictTranscript.swift
//  Duello
//
//  Portage de `src/utils/realtimeAsr.ts` (`applyRealtimeTranscript`,
//  `realtimeTranscriptText`, `selectCompletedTranscript`,
//  `compareFullTranscript`) et de `src/hooks/webDictationPresentation.ts`
//  (`renderWebTranscript`, `appendWebTranscript`).
//
//  Conserve les phrases finalisées lorsqu'une révision arrive : l'aperçu
//  n'efface donc jamais une partie déjà validée de la dictée.
//
//  Cible : iOS 16. Aucune dépendance externe.
//

import Foundation

/// Issue de la seconde passe — `TranscriptRefinementResult`.
enum DictRefinement: String {
    case changed
    case confirmed
}

/// Phrase encore provisoire — `RealtimeTranscriptState.partial`.
struct DictPartial: Equatable {
    let sentenceId: Int
    let text: String
}

/// État d'une transcription temps réel — `RealtimeTranscriptState`.
struct DictTranscriptState {
    var finalized: [Int: String]
    var partial: DictPartial?

    /// État vide — `EMPTY_REALTIME_TRANSCRIPT`.
    static let empty = DictTranscriptState(finalized: [:], partial: nil)
}

/// Transcription retenue après l'arrêt du micro — `CompletedTranscript`.
struct DictCompletedTranscript {
    /// Texte assemblé par le moteur temps réel, utilisé comme repli.
    let realtimeText: String
    /// Texte de la phrase entière affiché après le bouton stop.
    let text: String
    /// Indique si la seconde passe a corrigé ou confirmé le temps réel.
    let refinement: DictRefinement?
}

extension DictPolicy {
    /// Applique un événement `transcript` à l'état — `applyRealtimeTranscript`.
    static func applyTranscript(_ state: DictTranscriptState, _ event: DictAsrEvent) -> DictTranscriptState {
        guard case let .transcript(text, isFinal, sentenceId, _, _) = event else { return state }
        let propre = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if propre.isEmpty { return state }

        if isFinal {
            var finalized = state.finalized
            finalized[sentenceId] = propre
            let partial = state.partial?.sentenceId == sentenceId ? nil : state.partial
            return DictTranscriptState(finalized: finalized, partial: partial)
        }
        // Une phrase finalisée est stable : un résultat tardif ne la fait pas régresser.
        if state.finalized[sentenceId] != nil { return state }
        return DictTranscriptState(finalized: state.finalized, partial: DictPartial(sentenceId: sentenceId, text: propre))
    }

    /// Texte assemblé des phrases finalisées puis de l'aperçu — `realtimeTranscriptText`.
    static func transcriptText(_ state: DictTranscriptState) -> String {
        let finalisees = state.finalized
            .map { (id: $0.key, text: $0.value) }
            .sorted { $0.id < $1.id }
            .map { $0.text }
        var morceaux = finalisees
        if let partial = state.partial, state.finalized[partial.sentenceId] == nil {
            morceaux.append(partial.text)
        }
        return morceaux.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Choisit une seule transcription après l'arrêt du micro — `selectCompletedTranscript`.
    ///
    /// La réécoute complète est prioritaire parce qu'elle reçoit l'enregistrement
    /// entier ; les fragments temps réel ne servent que de repli.
    static func selectCompletedTranscript(_ state: DictTranscriptState, fullText: String) -> DictCompletedTranscript {
        let realtimeText = transcriptText(state)
        let complet = fullText.trimmingCharacters(in: .whitespacesAndNewlines)
        if complet.isEmpty {
            return DictCompletedTranscript(realtimeText: realtimeText, text: realtimeText, refinement: nil)
        }
        return DictCompletedTranscript(
            realtimeText: realtimeText, text: complet,
            refinement: compareFullTranscript(realtimeText, complet)
        )
    }

    /// Indique si la réécoute complète a remplacé l'aperçu — `compareFullTranscript`.
    static func compareFullTranscript(_ realtimeText: String, _ fullText: String) -> DictRefinement {
        realtimeText.trimmingCharacters(in: .whitespacesAndNewlines)
            == fullText.trimmingCharacters(in: .whitespacesAndNewlines) ? .confirmed : .changed
    }

    /// Rend une transcription en notation lisible — `renderWebTranscript`.
    static func renderTranscript(_ rawText: String, math: Bool) -> String {
        math ? LatexToUnicode.toUnicodeMath(DictMathParser.spokenToLatex(rawText)) : rawText
    }

    /// Ajoute une transcription au texte du champ — `appendWebTranscript`.
    static func appendTranscript(_ prefix: String, _ transcript: String) -> String {
        let propre = prefix.trimmingCharacters(in: .whitespacesAndNewlines)
        return propre.isEmpty ? transcript : "\(propre)\n\(transcript)"
    }
}
