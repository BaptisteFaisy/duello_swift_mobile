//
//  ReportLocalSnapshot+TimeSeries.swift
//  Duello
//
//  Séries temporelles de l'instantané public (lot S04, vague 6).
//
//  Fichier source Expo porté (libellés repris mot pour mot) :
//    - src/utils/publicProfileSnapshot.ts, l. 266-288 (`timeSeries` :
//      `buildSubjectTimeSeries(activity.sessions, granularity, at, undefined,
//      graphStartedAt)`).
//
//  Séparé de `ReportLocalSnapshot.swift` (ratchet : ≤ 10 fonctions par fichier) :
//  la fabrique garde ses fonctions d'origine, ce raccord vit dans ce fichier.
//
//  Réutilise `ChartTimeSeries` et `ChartActivitySessionStore`.
//
//  Cible : iOS 16, aucune dépendance externe.
//
import Foundation

extension ReportLocalSnapshot {

    /// `timeSeries` : colonnes jour / semaine / mois, bâties depuis les sessions
    /// d'entraînement locales (`buildSubjectTimeSeries`), bornées à l'instant le
    /// plus ancien connu (`graphStartedAt`).
    static func timeSeries(
        local: ReportLocalProgress,
        registeredAt: Double
    ) -> ReportPublicTimeSeries {
        let sessions = ChartActivitySessionStore.load()
        let dates = [registeredAt] + sessions.map(\.at) + local.eloHistory.map(\.at)
        let start = dates.filter { $0.isFinite && $0 > 0 }.min()
        return ReportPublicTimeSeries(
            day: buckets(sessions: sessions, granularity: .day, registeredAt: start),
            week: buckets(sessions: sessions, granularity: .week, registeredAt: start),
            month: buckets(sessions: sessions, granularity: .month, registeredAt: start)
        )
    }

    /// Une colonne par période, minutes par matière (`SubjectTimeBucket`).
    static func buckets(
        sessions: [ChartActivitySession],
        granularity: ChartTimeGranularity,
        registeredAt: Double?
    ) -> [ReportPublicTimeBucket] {
        ChartTimeSeries.build(sessions: sessions, granularity: granularity, registeredAt: registeredAt)
            .map { bucket in
                ReportPublicTimeBucket(
                    start: bucket.start,
                    minutesBySubject: bucket.minutesBySubject.mapValues { Int($0.rounded()) },
                    minutes: Int(bucket.minutes.rounded())
                )
            }
    }
}
