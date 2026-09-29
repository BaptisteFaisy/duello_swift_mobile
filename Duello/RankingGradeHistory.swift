//
//  RankingGradeHistory.swift
//  Duello
//
//  Historique des notes du profil (les cinq dernières rendues par les
//  corrections).
//
//  Fichier source Expo porté (libellés et seuils repris mot pour mot) :
//    - src/utils/gradeHistoryTimeline.ts
//        `GRADE_HISTORY_LIMIT`, `ACTIVITY_LABELS`, `GradeHistoryRow`,
//        `chronological`, `rowTitle`, `buildGradeHistory`.
//    - src/utils/accountMetricEvolution.ts
//        `relativeEvolutionPercentage` (déjà porté :
//        `ChartMetricEvolution.relativeEvolution`, `ChartMetricEvolution.swift:25`).
//
//  Dépend du journal des notes (`CorrectionGradeEntry`,
//  `CorrectionGradeHistory.swift`).
//
//  Cible : iOS 16, aucune dépendance externe.
//
import Foundation

/// `GradeHistoryRow` : une ligne de l'historique des notes du profil.
struct GradeHistoryRow: Identifiable, Equatable {
    var id: String
    /// Intitulé de la catégorie, mis en majuscules à l'affichage.
    var category: String
    var title: String
    /// Note sur 20.
    var score: Double
    /// Taux d'évolution face à la note immédiatement antérieure, `nil` pour la
    /// plus ancienne.
    var evolutionPercentage: Double?
    /// Vrai lorsque la note bat toutes celles qui la précèdent.
    var record: Bool
}

/// `utils/gradeHistoryTimeline.ts` : historique des notes du profil.
enum RankingGradeHistory {

    /// `GRADE_HISTORY_LIMIT` : nombre de notes listées dans l'historique.
    static let gradeHistoryLimit = 5

    /// `ACTIVITY_LABELS` de `gradeHistoryTimeline.ts` (distinct de
    /// `ChartCorrectionActivity.label`, qui dit « Exercice ou colle » pour
    /// « entrainement »).
    static func categoryLabel(_ activity: CorrectionGradeActivity) -> String {
        switch activity {
        case .exercice: return "Exercice"
        case .colle: return "Colle"
        case .annale: return "Annale"
        case .defi: return "Défi"
        case .entrainement: return "Entraînement"
        }
    }

    /// `rowTitle` : titre de la note, replié sur la matière puis la catégorie.
    static func rowTitle(_ entry: CorrectionGradeEntry, category: String) -> String {
        let title = entry.title?.trimmingCharacters(in: .whitespacesAndNewlines)
        let subject = entry.subject?.trimmingCharacters(in: .whitespacesAndNewlines)
        let label = (title?.isEmpty == false ? title : nil)
            ?? (subject?.isEmpty == false ? subject : nil)
        return label ?? category
    }

    /// `buildGradeHistory` : les dernières notes rendues, de la plus récente à
    /// la plus ancienne. Une note est un record lorsqu'elle dépasse toutes
    /// celles qui la précèdent ; faute d'antécédent, la toute première en est
    /// un. L'évolution se compare à la note réellement antérieure, même si
    /// celle-ci est trop ancienne pour figurer dans la fenêtre affichée.
    static func buildGradeHistory(
        _ entries: [CorrectionGradeEntry],
        limit: Int = gradeHistoryLimit
    ) -> [GradeHistoryRow] {
        var best = -Double.infinity
        var rows: [GradeHistoryRow] = []
        for entry in CorrectionGradeHistory.chronological(entries) {
            let category = categoryLabel(entry.activity)
            let isRecord = entry.score > best
            best = max(best, entry.score)
            rows.append(
                GradeHistoryRow(
                    id: entry.id,
                    category: category,
                    title: rowTitle(entry, category: category),
                    score: entry.score,
                    evolutionPercentage: nil,
                    record: isRecord
                )
            )
        }

        var withEvolution: [GradeHistoryRow] = []
        for (index, row) in rows.enumerated() {
            guard index > 0 else {
                withEvolution.append(row)
                continue
            }
            var copy = row
            copy.evolutionPercentage = ChartMetricEvolution.relativeEvolution(
                current: row.score,
                previous: rows[index - 1].score
            )
            withEvolution.append(copy)
        }

        return Array(withEvolution.reversed().prefix(max(0, limit)))
    }
}
