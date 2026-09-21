//
//  ConsentCorrectionSeconds.swift
//  Duello
//
//  Durée annoncée pour corriger une réponse, estimée à partir des corrections
//  déjà mesurées sur ce compte.
//
//  Fichiers source Expo portés :
//    - `src/hooks/useQuestionCorrectionSeconds.ts` (`useQuestionCorrectionSeconds`) ;
//    - `src/utils/correctionDurationStats.ts` (fonctions pures utilisées par le
//      hook : `PRIOR_CORRECTION_DURATION_STATS`, `plannedQuestionSeconds`,
//      `parseCorrectionDurationStats`, `loadCorrectionDurationStats`).
//
//  Le relais ne fournit pas d'ETA pour `grade-answer` : l'estimation suit une
//  moyenne mobile des corrections terminées et leur dispersion (principe de
//  l'estimation du RTT de TCP, RFC 6298). Sans mesure, l'a priori reprend
//  l'ancienne estimation prudente (moyenne 35 s, écart 10 s).
//
//  La source relit l'estimation après chaque correction mesurée ; le portage
//  expose la lecture pure, la réactivité restant à la charge de la vue hôte.
//
//  Cible : iOS 16.
//
import Foundation

/// Durée annoncée pour corriger une réponse (`useQuestionCorrectionSeconds`).
enum ConsentCorrectionSeconds {

    /// `CorrectionDurationStats` : durées réellement mesurées.
    struct Stats: Equatable {
        var meanSeconds: Double
        /// Écart absolu moyen des mesures autour de la moyenne.
        var deviationSeconds: Double
        /// Corrections mesurées ; seules les premières pèsent plus qu'un quart.
        var samples: Int
    }

    /// `PRIOR_CORRECTION_DURATION_STATS` : sans mesure, l'annonce prudente
    /// héritée (45 s par réponse, soit 35 s + 10 s).
    static let prior = Stats(meanSeconds: 35, deviationSeconds: 10, samples: 0)

    /// `QUESTION_CORRECTION_REQUEST_TIMEOUT_MS` (`correctionPerformance.ts`).
    static let requestTimeoutMilliseconds: Double = 95_000

    /// `MAX_CORRECTION_SECONDS` : une correction réussie ne peut pas dépasser le
    /// délai d'attente de l'app.
    static let maxSeconds: Double = requestTimeoutMilliseconds / 1000

    /// `ACCOUNT_STORAGE_KEYS.correctionDurationStats`. La source range la valeur
    /// par compte ; le portage conserve la clé logique, comme les autres stores.
    static let storageKey = "prepapp-correction-duration-stats:v1"

    /// `boundedSeconds` : ramène une durée mesurée dans `[0, maxSeconds]`.
    static func bounded(_ seconds: Double) -> Double {
        min(maxSeconds, max(0, seconds))
    }

    /// `plannedQuestionSeconds` : durée prudente annoncée pour une réponse — la
    /// moyenne plus un écart habituel.
    static func plannedSeconds(_ stats: Stats) -> Double {
        bounded(stats.meanSeconds + stats.deviationSeconds)
    }

    /// `parseCorrectionDurationStats` : lecture tolérante ; une valeur illisible
    /// ne doit pas empêcher d'annoncer une estimation.
    static func parse(_ raw: String?) -> Stats {
        guard let raw,
              let data = raw.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return prior }
        guard let mean = measure(object["meanSeconds"]),
              let deviation = measure(object["deviationSeconds"]),
              let samples = measure(object["samples"])
        else { return prior }
        return Stats(
            meanSeconds: bounded(mean),
            deviationSeconds: bounded(deviation),
            samples: Int(samples.rounded(.down))
        )
    }

    /// `loadCorrectionDurationStats` : relit les mesures enregistrées.
    static func load() -> Stats {
        parse(UserDefaults.standard.string(forKey: storageKey))
    }

    /// Durée annoncée pour la prochaine correction, en secondes.
    static func seconds() -> Double {
        plannedSeconds(load())
    }

    /// `isMeasure` : nombre fini et positif ou nul.
    private static func measure(_ value: Any?) -> Double? {
        guard let number = value as? Double, number.isFinite, number >= 0 else { return nil }
        return number
    }
}
