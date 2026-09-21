//
//  ChalTimer.swift
//  Duello
//
//  Lot « Extras de défi » — chronomètre d'un défi : décompte pur et testable.
//
//  Fichier source Expo porté (bornes et comportements repris mot pour mot) :
//    - src/utils/challengeTimer.ts   (challengeTimerSnapshot)
//
//  `challengeTimerSnapshot` lit le chrono entre son départ et sa durée maximale.
//  L'horloge est injectable (`now`) ; elle est ignorée dès que la copie est
//  rendue (`stoppedAt`). Toutes les bornes de la source sont conservées :
//  `totalSeconds` borné à un entier ≥ 0, instants non finis repliés sur l'instant
//  mesuré puis sur le départ, écart borné à `[0, totalSeconds]`.
//
//  Cible : iOS 16, aucune API iOS 17.
//
import Foundation

/// Chronomètre du défi (`challengeTimer.ts`).
enum ChalTimer {
    /// Entrée de `challengeTimerSnapshot` (`ChallengeTimerOptions`).
    struct Options {
        /// Instant de départ, en millisecondes depuis l'époque Unix.
        var startedAt: Double
        /// Durée maximale du défi, en secondes.
        var totalSeconds: Double
        /// Instant de remise : lorsqu'il existe, le temps n'avance plus après lui.
        var stoppedAt: Double? = nil
        /// Horloge injectable pour les tests ; ignorée une fois la copie rendue.
        var now: Double = Date().timeIntervalSince1970 * 1000
    }

    /// Instantané du chrono (`ChallengeTimerSnapshot`).
    struct Snapshot: Equatable {
        var elapsedSeconds: Int
        var remainingSeconds: Int
    }

    /// Lit le chrono du défi, en le bornant entre son départ et sa durée maximale.
    static func snapshot(_ options: Options) -> Snapshot {
        let safeTotalSeconds = options.totalSeconds.isFinite
            ? max(0, Int(options.totalSeconds.rounded(.down)))
            : 0
        let measuredAt = options.stoppedAt ?? options.now
        let safeStartedAt = options.startedAt.isFinite ? options.startedAt : measuredAt
        let safeMeasuredAt = measuredAt.isFinite ? measuredAt : safeStartedAt
        let elapsedSeconds = min(
            safeTotalSeconds,
            max(0, Int(((safeMeasuredAt - safeStartedAt) / 1000).rounded(.down)))
        )
        return Snapshot(
            elapsedSeconds: elapsedSeconds,
            remainingSeconds: safeTotalSeconds - elapsedSeconds
        )
    }

    /// Décompte affiché « m:ss » (le `formatClock` du joueur de défi).
    static func clock(_ seconds: Int) -> String {
        let safe = max(0, seconds)
        return String(format: "%d:%02d", safe / 60, safe % 60)
    }
}
