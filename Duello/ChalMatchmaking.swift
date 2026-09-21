//
//  ChalMatchmaking.swift
//  Duello
//
//  Lot « Extras de défi » — constantes de la file d'attente reprises de
//  `src/utils/matchmaking.ts`, utilisées par `ChalQueueController`.
//
//  Fichier source Expo porté (valeurs reprises mot pour mot) :
//    - src/utils/matchmaking.ts
//      (`CHALLENGE_DURATION_MINUTES`, `INITIAL_ELO_WINDOW`,
//       `ELO_WINDOW_PER_SECOND`, `MAX_ELO_WINDOW`, `QUEUE_POLL_INTERVAL_MS`,
//       `TRAINING_FALLBACK_MS`, `eloWindow`)
//
//  Périmètre : seules les valeurs lues par la file sont portées. La construction
//  d'un match d'entraînement (`buildTrainingMatch`, `pickChallengeExerciseSequence`,
//  `seedFrom`…) reste hors périmètre — le repli d'entraînement est signalé, non
//  fabriqué (voir `ChalQueueController`).
//
//  Cible : iOS 16, aucune API iOS 17.
//
import Foundation

/// Constantes et calculs de la file d'attente (`matchmaking.ts`).
enum ChalMatchmaking {
    /// Durée d'un défi, en minutes (`CHALLENGE_DURATION_MINUTES`).
    static let challengeDurationMinutes = 20
    /// Fenêtre de cote acceptée dès l'entrée dans la file (`INITIAL_ELO_WINDOW`).
    static let initialEloWindow = 80
    /// Élargissement de la fenêtre par seconde d'attente (`ELO_WINDOW_PER_SECOND`).
    static let eloWindowPerSecond = 40
    /// Au-delà, la fenêtre n'a plus de sens (`MAX_ELO_WINDOW`).
    static let maxEloWindow = 800
    /// Rythme d'interrogation de la file (`QUEUE_POLL_INTERVAL_MS`).
    static let queuePollIntervalNanoseconds: UInt64 = 1_200_000_000
    /// Au-delà de cette attente, l'application propose l'entraînement
    /// (`TRAINING_FALLBACK_MS`).
    static let trainingFallbackMs: Double = 20_000

    /// Fenêtre de cote en fonction de l'attente écoulée (`eloWindow`).
    static func eloWindow(waitedMs: Double) -> Int {
        let seconds = max(0, waitedMs) / 1000
        let widened = Double(initialEloWindow) + seconds * Double(eloWindowPerSecond)
        return min(maxEloWindow, Int(widened.rounded()))
    }
}
