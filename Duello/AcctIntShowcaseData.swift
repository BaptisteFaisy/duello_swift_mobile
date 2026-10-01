//
//  AcctIntShowcaseData.swift
//  Duello
//
//  Données de la vitrine raccordées à la vague 6 (lot S04) : journal des notes
//  de correction, historique des notes et temps d'entraînement par période.
//
//  Fichiers source Expo portés (libellés repris mot pour mot) :
//    - src/screens/AccountScreen.tsx (`correctionGrades` l. 1917-1922,
//      `correctionGradePeriods` l. 1924-1933, `gradeHistoryRows` l. 1938-1941,
//      `timeBuckets` l. 1905).
//    - src/utils/correctionGradeHistory.ts (`loadCorrectionGradeHistory`,
//      `groupCorrectionGradesByPeriod`).
//    - src/utils/gradeHistoryTimeline.ts (`buildGradeHistory`).
//    - src/utils/subjectTimeSeries.ts (`buildSubjectTimeSeries`).
//
//  Séparé de `AcctIntData.swift` (ratchet : ≤ 10 fonctions par fichier) : la
//  fabrique garde ses fonctions d'origine, ces raccords vivent dans ce fichier.
//
//  Réutilise `CorrectionGradeStore`, `RankingGradeHistory`, `ChartTimeSeries` et
//  `ChartActivitySessionStore`.
//
//  Cible : iOS 16, aucune API iOS 17 ; aucune dépendance externe.
//
import SwiftUI

extension AcctIntData {

    /// `correctionGrades` : notes rendues par les corrections, relues du journal
    /// local (`prepapp-correction-grade-history:v1`).
    static func correctionGrades() -> [CorrectionGradeEntry] {
        CorrectionGradeStore.load()
    }

    /// `correctionGradePeriods` : moyennes par période, prêtes pour la courbe
    /// `ChartCorrectionGradeChart` (« Évolution des notes »).
    static func gradePoints(
        _ entries: [CorrectionGradeEntry],
        granularity: ChartTimeGranularity
    ) -> [ChartCorrectionPeriodPoint] {
        CorrectionGradeStore.groupByPeriod(entries, granularity: granularity).map { point in
            ChartCorrectionPeriodPoint(
                at: point.at,
                score: point.score,
                entries: point.entries.map { entry in
                    ChartCorrectionEntry(
                        id: entry.id,
                        activity: ChartCorrectionActivity(rawValue: entry.activity.rawValue)
                            ?? .exercice,
                        score: entry.score,
                        submittedAt: entry.submittedAt,
                        subject: entry.subject,
                        title: entry.title
                    )
                }
            )
        }
    }

    /// `gradeHistoryRows` : lignes de la section « Historique des notes »
    /// (`buildGradeHistory`, cinq dernières corrections).
    static func gradeHistoryRows(_ entries: [CorrectionGradeEntry]) -> [GradeHistoryRow] {
        RankingGradeHistory.buildGradeHistory(entries)
    }

    /// `resolvedGradeHistoryRows` : lignes de l'historique rattachées au
    /// programme du spectateur (`resolveHistoryRow` de `historyExerciseAccess.ts`) —
    /// nom de chapitre affiché et cible de reprise dans l'entraînement.
    static func resolvedGradeHistoryRows(
        _ rows: [GradeHistoryRow],
        profile: UserProfile
    ) -> [ResolvedGradeHistoryRow] {
        rows.map {
            HistoryExerciseAccess.resolveHistoryRow(
                $0,
                viewer: profile,
                ownerTrack: profile.track
            )
        }
    }

    /// `timeBuckets` : minutes travaillées par période, bâties depuis les
    /// sessions d'entraînement locales (`buildSubjectTimeSeries`). La fenêtre
    /// démarre au premier instant connu (`graphStartedAt` de la source : plus
    /// ancien des gains d'XP et des cotes), sans quoi la courbe se limiterait aux
    /// sept dernières périodes.
    static func timeBuckets(
        _ progress: ProgressStore,
        granularity: ChartTimeGranularity
    ) -> [ChartTimeBucket] {
        let sessions = ChartActivitySessionStore.load()
        let dates = sessions.map(\.at)
            + progress.eloHistory.map(\.at)
            + progress.xpHistory.map(\.at)
        let start = dates.filter { $0.isFinite && $0 > 0 }.min()
        return ChartTimeSeries.build(
            sessions: sessions,
            granularity: granularity,
            registeredAt: start
        )
    }
}
