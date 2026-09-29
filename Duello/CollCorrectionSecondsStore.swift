//
//  CollCorrectionSecondsStore.swift
//  Duello
//
//  Durée annoncée pour corriger une réponse, réactive (`useQuestionCorrectionSeconds.ts`).
//
//  Fichier source Expo porté (libellés repris mot pour mot) :
//    - src/hooks/useQuestionCorrectionSeconds.ts (`useQuestionCorrectionSeconds`).
//
//  La source relit l'estimation après chaque correction mesurée
//  (`subscribeToAccountStorage`) : une soumission encore en cours profite déjà
//  des réponses corrigées avant elle. Sans abonnement de stockage en Swift, la
//  relecture est déclenchée par `record` — la vue hôte observe `seconds`.
//
//  Cible : iOS 16.
//
import SwiftUI

/// Durée annoncée pour corriger une réponse (`useQuestionCorrectionSeconds`).
final class CollCorrectionSecondsStore: ObservableObject {
    /// `plannedQuestionSeconds(stats)` : moyenne plus un écart habituel.
    @Published private(set) var seconds: Double

    init() {
        seconds = ConsentCorrectionSeconds.seconds()
    }

    /// `useQuestionCorrectionSeconds` : relit l'estimation courante.
    func reload() {
        seconds = ConsentCorrectionSeconds.seconds()
    }

    /// Enregistre une correction mesurée puis relit l'estimation, comme la
    /// source qui relit après chaque `recordCorrectionDuration`.
    func record(seconds measured: Double) {
        ConsentCorrectionSeconds.record(seconds: measured)
        reload()
    }
}
