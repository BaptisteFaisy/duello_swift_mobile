//
//  CorrectionGradeStore.swift
//  Duello
//
//  Journal des notes de correction : lecture, écriture et regroupement.
//
//  Fichier source Expo porté (libellés et seuils repris mot pour mot) :
//    - src/utils/correctionGradeHistory.ts
//        `parseCorrectionGradeHistory`, `loadCorrectionGradeHistory`,
//        `recordCorrectionGrade`, `groupCorrectionGradesByPeriod`,
//        `formatCorrectionGradeScore` et l'écriture sous la clé
//        `ACCOUNT_STORAGE_KEYS.correctionGradeHistory`
//        (`prepapp-correction-grade-history:v1`).
//
//  Limite documentée : la source sérialise les écritures par compte via une
//  file (`correctionGradeWrites`) ; le store iOS est lié au fil principal et
//  n'a qu'un compte à la fois, la file n'est pas nécessaire.
//
//  Cible : iOS 16, aucune dépendance externe.
//
import Foundation

/// Journal des notes rendues par les corrections
/// (`utils/correctionGradeHistory.ts`).
enum CorrectionGradeStore {

    /// `ACCOUNT_STORAGE_KEYS.correctionGradeHistory`.
    static let storageKey = "prepapp-correction-grade-history:v1"

    /// `parseCorrectionGradeHistory` : relit le journal sérialisé ; une réponse
    /// illisible rend un journal vide, jamais une erreur.
    static func parse(_ raw: String?) -> [CorrectionGradeEntry] {
        guard let raw, let data = raw.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([CorrectionGradeEntry].self, from: data)
        else { return [] }
        return CorrectionGradeHistory.merge([decoded])
    }

    /// `loadCorrectionGradeHistory` : relit les notes enregistrées.
    static func load() -> [CorrectionGradeEntry] {
        parse(UserDefaults.standard.string(forKey: storageKey))
    }

    /// `recordCorrectionGrade` : ajoute une note sans limite de rétention. Deux
    /// reprises du même résultat ne créent jamais deux points (identifiant
    /// idempotent).
    @discardableResult
    static func record(_ input: CorrectionGradeInput) -> [CorrectionGradeEntry] {
        let activity = CorrectionGradeActivity(rawValue: input.activity.rawValue) ?? .exercice
        let entry = CorrectionGradeHistory.normalize(
            CorrectionGradeEntry(
                id: input.id,
                activity: activity,
                score: input.score,
                submittedAt: input.submittedAt,
                subject: input.subject,
                title: input.title,
                itemIds: input.itemIds
            )
        )
        guard let entry else { return load() }

        let current = load()
        let saved = CorrectionGradeHistory.merge([current, [entry]])
        persist(saved)
        return saved
    }

    /// `groupCorrectionGradesByPeriod` : agrège les corrections par période pour
    /// garder la même lecture que les autres courbes.
    static func groupByPeriod(
        _ entries: [CorrectionGradeEntry],
        granularity: ChartTimeGranularity
    ) -> [CorrectionGradePeriodPoint] {
        var byPeriod: [Double: [CorrectionGradeEntry]] = [:]
        for entry in CorrectionGradeHistory.chronological(entries) {
            let start = ChartTimeSeries.bucketStart(entry.submittedAt, granularity)
            byPeriod[start, default: []].append(entry)
        }
        return byPeriod.keys.sorted().map { at in
            let periodEntries = byPeriod[at] ?? []
            let total = periodEntries.reduce(0) { $0 + $1.score }
            let average = periodEntries.isEmpty ? 0 : total / Double(periodEntries.count)
            return CorrectionGradePeriodPoint(
                at: at,
                score: (average * 10).rounded() / 10,
                entries: periodEntries
            )
        }
    }

    /// `formatCorrectionGradeScore` : note en français, au dixième au plus.
    static func formatScore(_ score: Double) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1
        return formatter.string(from: NSNumber(value: score)) ?? "\(score)"
    }

    /// Écriture du journal dans les préférences ; l'échec laisse le journal de
    /// la session en cours intact.
    private static func persist(_ entries: [CorrectionGradeEntry]) {
        guard let data = try? JSONEncoder().encode(entries),
              let raw = String(data: data, encoding: .utf8)
        else { return }
        UserDefaults.standard.set(raw, forKey: storageKey)
    }
}
