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

    /// `BUCKET_COUNTS[granularity]` : l'année se lit en douze mois, le maximum
    /// sur tout l'historique plafonné à 120 colonnes. Les niveaux `year` et
    /// `max` n'existent pas encore dans `ChartTimeGranularity` (cf. rapport du
    /// lot I7-06, section « Hors périmètre ») : seuls `day`/`week`/`month`
    /// répondent ici.
    static func bucketCount(_ granularity: ChartTimeGranularity) -> Int {
        switch granularity {
        case .day, .week, .month: return bucketCounts
        }
    }

    /// `bucketsByMonth` : l'année et le maximum se lisent au mois. Seul `month`
    /// est représentable aujourd'hui (cf. note ci-dessus).
    static func bucketsByMonth(_ granularity: ChartTimeGranularity) -> Bool {
        granularity == .month
    }

    /// `windowGroupedPoints` : l'année ne garde que ses douze derniers mois
    /// côté courbes groupées ; les autres fenêtres montrent tout l'historique à
    /// leur résolution. Sans niveau `year`, la copie est rendue telle quelle.
    static func windowGroupedPoints<T>(_ points: [T], _ granularity: ChartTimeGranularity) -> [T] {
        _ = granularity
        return Array(points)
    }

    /// `buildExerciseCountSeries` : exercices terminés par période, même fenêtre
    /// que le temps : les périodes sans entraînement restent à zéro pour garder
    /// un axe régulier.
    static func buildExerciseCountSeries(
        sessions: [ChartActivitySession],
        granularity: ChartTimeGranularity,
        at: Double? = nil,
        count: Int = 7,
        registeredAt: Double? = nil
    ) -> [ChartExerciseBucket] {
        let columns = max(1, count)
        let reference = at ?? milliseconds(Date())
        let current = bucketStart(reference, granularity)
        let registered = registeredAt ?? 0
        let hasRegistration = registered.isFinite && registered > 0
        let defaultStart = shift(current, granularity, -(columns - 1))
        var start = hasRegistration
            ? min(bucketStart(registered, granularity), defaultStart)
            : defaultStart

        var buckets: [ChartExerciseBucket] = []
        var byStart: [Double: Int] = [:]
        while start <= current {
            buckets.append(ChartExerciseBucket(start: start, exercises: 0))
            byStart[start] = buckets.count - 1
            let next = shift(start, granularity, 1)
            if next <= start { break }
            start = next
        }

        for session in sessions {
            if session.exercises <= 0 { continue }
            if hasRegistration && session.at < registered { continue }
            guard let index = byStart[bucketStart(session.at, granularity)] else { continue }
            buckets[index].exercises += session.exercises
        }
        return buckets
    }
}
