//
//  ChartTimeSeries+Exercise.swift
//  Duello
//
//  Découpage du temps par matière — fenêtres groupées et exercices par période
//  (vague I7, préfixe `Chart`).
//
//  Fichier source Expo porté (noms repris mot pour mot) :
//    - src/utils/subjectTimeSeries.ts (`BUCKET_COUNTS`, `bucketsByMonth`,
//      `windowGroupedPoints`, `ExerciseCountBucket`, `buildExerciseCountSeries`)
//
//  Séparé de `ChartTimeSeries.swift` (ratchet : ≤ 10 fonctions par fichier).
//  Cible iOS 16 ; aucune dépendance externe.
//
import Foundation

extension ChartTimeSeries {

    /// `BUCKET_COUNTS[granularity]` : sept colonnes pour le jour, la semaine et
    /// le mois, douze pour l'année, cent vingt pour le maximum.
    static func bucketCount(_ granularity: ChartTimeGranularity) -> Int {
        switch granularity {
        case .day, .week, .month: return 7
        case .year: return 12
        case .max: return 120
        }
    }

    /// `bucketsByMonth` : le mois, l'année et le maximum se lisent au mois.
    static func bucketsByMonth(_ granularity: ChartTimeGranularity) -> Bool {
        granularity == .month || granularity == .year || granularity == .max
    }

    /// `windowGroupedPoints` : l'année ne garde que ses douze derniers mois
    /// côté courbes groupées ; les autres fenêtres montrent tout l'historique à
    /// leur résolution.
    static func windowGroupedPoints<T>(_ points: [T], _ granularity: ChartTimeGranularity) -> [T] {
        granularity == .year ? Array(points.suffix(bucketCount(.year))) : Array(points)
    }

    /// `buildExerciseCountSeries` : exercices terminés par période, même fenêtre
    /// que le temps : les périodes sans entraînement restent à zéro pour garder
    /// un axe régulier.
    static func buildExerciseCountSeries(
        sessions: [ChartActivitySession],
        granularity: ChartTimeGranularity,
        at: Double? = nil,
        count: Int? = nil,
        registeredAt: Double? = nil
    ) -> [ChartExerciseBucket] {
        let columns = max(1, count ?? bucketCount(granularity))
        let reference = at ?? milliseconds(Date())
        let current = bucketStart(reference, granularity)
        let registered = registeredAt ?? 0
        let hasRegistration = registered.isFinite && registered > 0
        var start = startBucket(
            sessions: sessions,
            granularity: granularity,
            current: current,
            columns: columns,
            hasRegistration: hasRegistration,
            registered: registered,
            weight: { $0.exercises }
        )

        var buckets: [ChartExerciseBucket] = []
        var byStart: [Double: Int] = [:]
        while start <= current {
            buckets.append(ChartExerciseBucket(start: start, exercises: 0))
            byStart[start] = buckets.count - 1
            let next = shift(start, granularity, 1)
            if next <= start { break }
            start = next
        }
        if granularity == .max && buckets.count > columns {
            capToColumns(&buckets, &byStart, columns, startOf: { $0.start })
        }

        for session in sessions {
            if session.exercises <= 0 { continue }
            if hasRegistration && session.at < registered { continue }
            guard let index = byStart[bucketStart(session.at, granularity)] else { continue }
            buckets[index].exercises += session.exercises
        }
        return buckets
    }

    // MARK: - Fenêtre commune (partagée avec `build` de `ChartTimeSeries.swift`)

    /// Borne de départ d'une fenêtre glissante : inscription, année en douze mois
    /// glissants, ou historique borné pour le maximum. `weight` lit la grandeur
    /// suivie (minutes ou exercices) pour écarter les séances vides.
    ///
    /// Vit ici (et non dans `ChartTimeSeries.swift`, plafonné à dix fonctions par
    /// le ratchet) et reste `internal` : `build` l'appelle depuis l'autre fichier.
    static func startBucket(
        sessions: [ChartActivitySession],
        granularity: ChartTimeGranularity,
        current: Double,
        columns: Int,
        hasRegistration: Bool,
        registered: Double,
        weight: (ChartActivitySession) -> Double
    ) -> Double {
        let defaultStart = shift(current, granularity, -(columns - 1))
        var start = hasRegistration
            ? min(bucketStart(registered, granularity), defaultStart)
            : defaultStart
        if granularity == .year {
            // L'année se lit en douze mois glissants, même pour un compte ancien.
            start = defaultStart
        } else if granularity == .max {
            if hasRegistration {
                // Le maximum part du mois d'inscription, jamais dans le futur.
                start = min(bucketStart(registered, granularity), current)
            } else {
                // Sans inscription connue, le maximum part de la première séance utile.
                var first: Double?
                for session in sessions {
                    if weight(session) <= 0 { continue }
                    let bucket = bucketStart(session.at, granularity)
                    first = first.map { min($0, bucket) } ?? bucket
                }
                start = first ?? current
            }
            // Fenêtre minimale : un point seul ne se lit pas comme une courbe.
            start = min(start, shift(current, granularity, -(minMaxBuckets - 1)))
        }
        return start
    }

    /// Garde-fou : même un compte très ancien tient dans la fenêtre plafonnée.
    /// Tronque les colonnes et reconstruit leur index `start → rang`.
    static func capToColumns<B>(
        _ buckets: inout [B],
        _ byStart: inout [Double: Int],
        _ columns: Int,
        startOf: (B) -> Double
    ) {
        buckets = Array(buckets.suffix(columns))
        byStart.removeAll()
        for (index, bucket) in buckets.enumerated() {
            byStart[startOf(bucket)] = index
        }
    }
}
