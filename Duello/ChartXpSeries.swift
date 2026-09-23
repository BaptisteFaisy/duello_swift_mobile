//
//  ChartXpSeries.swift
//  Duello
//
//  Séries d'XP des graphiques du compte (lot D « Graphiques », préfixe `Chart`).
//
//  Fichiers source Expo portés (noms et libellés repris) :
//    - src/utils/xpSeries.ts        (`XpSeriesPoint`, `buildXpSeries`,
//                                    `groupXpSeriesByPeriod`)
//    - src/utils/xpLevelProgress.ts (`XpProgressSnapshot`, `crossedXpLevels`)
//
//  La courbe de niveaux (`utils/xp.ts`) est déjà portée par `ExGXp`
//  (`ExGXpFoundation.swift`) et réutilisée ici : aucun type n'est redéfini.
//  Cible iOS 16 ; aucune dépendance externe.
//
import Foundation

/// `XpEntry` de `types.ts` réduit aux champs consommés par la série.
struct ChartXpEntry: Hashable {
    var xp: Double
    var at: Double
}

/// `XpSeriesPoint` de `utils/xpSeries.ts` : total d'XP atteint à un instant (ms).
struct ChartXpSeriesPoint: Identifiable, Hashable {
    let id = UUID()
    var xp: Double
    var at: Double
}

/// `XpProgressSnapshot` de `utils/xpLevelProgress.ts` : totaux encadrant les
/// gains présentés dans un bilan.
struct ChartXpProgressSnapshot: Hashable {
    var totalBefore: Double
    var totalAfter: Double
}

/// `buildXpSeries`/`groupXpSeriesByPeriod` de `utils/xpSeries.ts`.
enum ChartXpSeries {
    /// `safeXp` : arrondi au dixième, non fini ou négatif ramené à 0.
    private static func safeXp(_ value: Double) -> Double {
        value.isFinite && value > 0 ? (value * 10).rounded() / 10 : 0
    }

    /// Reconstitue le total d'XP après chaque gain conservé dans l'activité.
    ///
    /// L'historique est borné : quand ses entrées ne remontent pas jusqu'à
    /// l'inscription, le premier point reprend le total déjà acquis avant.
    ///
    /// Le pipeline `filter` + `sorted` + `reduce` était rejoué à chaque rendu du
    /// graphe (`AcctIntShowcase.xpSeriesPoints`) : il est mémoïsé par
    /// `(history, total, registeredAt)`.
    static func build(
        history: [ChartXpEntry],
        total: Double,
        registeredAt: Double = 0
    ) -> [ChartXpSeriesPoint] {
        let key = BuildKey(history: history, total: total, registeredAt: registeredAt)
        cacheLock.lock()
        let cached = cache[key]
        cacheLock.unlock()
        if let cached { return cached }

        let result = compute(history: history, total: total, registeredAt: registeredAt)

        cacheLock.lock()
        if cache.count >= cacheLimit { cache.removeAll(keepingCapacity: true) }
        cache[key] = result
        cacheLock.unlock()
        return result
    }

    /// Clé de mémoïsation : tout ce qui détermine la série produite.
    private struct BuildKey: Hashable {
        var history: [ChartXpEntry]
        var total: Double
        var registeredAt: Double
    }

    private static let cacheLimit = 8
    private static let cacheLock = NSLock()
    private static var cache: [BuildKey: [ChartXpSeriesPoint]] = [:]

    private static func compute(
        history: [ChartXpEntry],
        total: Double,
        registeredAt: Double
    ) -> [ChartXpSeriesPoint] {
        let gains = history
            .filter { $0.at.isFinite && $0.at > 0 && $0.xp.isFinite && $0.xp > 0 }
            .sorted { $0.at < $1.at }
        if gains.isEmpty { return [] }

        let currentTotal = safeXp(total)
        let retainedTotal = gains.reduce(0) { $0 + safeXp($1.xp) }
        var cumulative = max(0, currentTotal - retainedTotal)
        let startAt = registeredAt.isFinite && registeredAt > 0
            ? min(registeredAt, gains[0].at)
            : 0
        var points = [ChartXpSeriesPoint(xp: safeXp(cumulative), at: startAt)]

        for entry in gains {
            cumulative = min(currentTotal, safeXp(cumulative + entry.xp))
            points.append(ChartXpSeriesPoint(xp: cumulative, at: entry.at))
        }
        // Le total calculé depuis l'état courant reste l'autorité.
        points[points.count - 1].xp = currentTotal
        return points
    }

    /// Garde le total de clôture de chaque jour, semaine ou mois.
    static func groupByPeriod(
        _ points: [ChartXpSeriesPoint],
        granularity: ChartTimeGranularity
    ) -> [ChartXpSeriesPoint] {
        let chronological = points.sorted { $0.at < $1.at }
        let undatedStart = chronological.first { $0.at <= 0 }
        var closingByPeriod: [Double: ChartXpSeriesPoint] = [:]
        for point in chronological where point.at > 0 {
            let start = ChartTimeSeries.bucketStart(point.at, granularity)
            closingByPeriod[start] = ChartXpSeriesPoint(xp: point.xp, at: start)
        }
        var result: [ChartXpSeriesPoint] = []
        if let undatedStart { result.append(undatedStart) }
        result.append(contentsOf: closingByPeriod.values.sorted { $0.at < $1.at })
        return result
    }
}

/// `crossedXpLevels` de `utils/xpLevelProgress.ts`.
enum ChartXpLevelProgress {
    /// Retourne chaque niveau franchi, dans l'ordre, entre deux totaux d'XP.
    static func crossedLevels(previousXp: Double, currentXp: Double) -> [Int] {
        let previousLevel = ExGXp.levelForXp(previousXp)
        let currentLevel = ExGXp.levelForXp(currentXp)
        if currentLevel <= previousLevel { return [] }
        return Array((previousLevel + 1)...currentLevel)
    }
}
