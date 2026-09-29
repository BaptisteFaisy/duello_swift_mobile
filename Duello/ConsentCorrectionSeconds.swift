//
//  ConsentCorrectionSeconds.swift
//  Duello
//
//  Durée annoncée pour corriger une réponse, estimée à partir des corrections
//  déjà mesurées sur ce compte.
//
//  Fichiers source Expo portés :
//    - `src/hooks/useQuestionCorrectionSeconds.ts` (`useQuestionCorrectionSeconds`) ;
//    - `src/utils/correctionDurationStats.ts` (`PRIOR_CORRECTION_DURATION_STATS`,
//      `withCorrectionDuration`, `plannedQuestionSeconds`,
//      `parseCorrectionDurationStats`, `serializeCorrectionDurationStats`,
//      `loadCorrectionDurationStats`, `recordCorrectionDuration`).
//
//  Le relais ne fournit pas d'ETA pour `grade-answer` : l'estimation suit une
//  moyenne mobile des corrections terminées et leur dispersion (principe de
//  l'estimation du RTT de TCP, RFC 6298). Sans mesure, l'a priori reprend
//  l'ancienne estimation prudente (moyenne 35 s, écart 10 s).
//
//  Le chemin d'écriture (`withCorrectionDuration`, `record`) est porté ici ; la
//  réactivité de la vue (relecture après chaque correction mesurée) vit dans
//  `CollCorrectionSecondsStore.swift`.
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

    /// `STEADY_SAMPLE_WEIGHT` : poids minimal d'une nouvelle mesure une fois
    /// l'a priori dilué dans les premières.
    private static let steadySampleWeight = 0.25

    /// `withCorrectionDuration` : intègre une durée mesurée. L'a priori compte
    /// pour une mesure, puis chaque correction pèse au moins un quart.
    static func withCorrectionDuration(_ stats: Stats, seconds: Double) -> Stats {
        let weight = max(steadySampleWeight, 1 / Double(stats.samples + 2))
        let error = bounded(seconds) - stats.meanSeconds
        return Stats(
            meanSeconds: stats.meanSeconds + weight * error,
            deviationSeconds: stats.deviationSeconds
                + weight * (abs(error) - stats.deviationSeconds),
            samples: stats.samples + 1
        )
    }

    /// `serializeCorrectionDurationStats` : forme persistée de la source.
    static func serialize(_ stats: Stats) -> String? {
        let object: [String: Any] = [
            "meanSeconds": stats.meanSeconds,
            "deviationSeconds": stats.deviationSeconds,
            "samples": stats.samples,
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: object) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// `recordCorrectionDuration` : enregistre une correction terminée et
    /// publie la nouvelle estimation.
    @discardableResult
    static func record(seconds: Double) -> Stats {
        let next = withCorrectionDuration(load(), seconds: seconds)
        if let raw = serialize(next) {
            UserDefaults.standard.set(raw, forKey: storageKey)
        }
        return next
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
