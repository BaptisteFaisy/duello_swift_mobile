//
//  CollCorrectionGradeStore.swift
//  Duello
//
//  Persistance du journal des notes (`utils/correctionGradeHistory.ts`) :
//  relecture, enregistrement idempotent et frise affichée dans Mon compte.
//
//  Fichiers source Expo portés (libellés repris mot pour mot) :
//    - src/utils/correctionGradeHistory.ts
//        `loadCorrectionGradeHistory`, `recordCorrectionGrade`,
//        `legacyCorrectionGradeEntries`, `loadCorrectionGradeTimeline`.
//
//  Adaptations assumées :
//    - pas d'`AccountStorage` en Swift : le journal vit dans `UserDefaults`
//      standard sous la clé logique `prepapp-correction-grade-history:v1`,
//      comme `ConsentCorrectionSeconds` ;
//    - la file d'écritures sérialisées par compte de la source n'est pas
//      reprise : le portage n'a qu'un compte à la fois (cf. `CollTrainingTimeStore`).
//  Cible : iOS 16, aucune dépendance externe.
//
import Foundation

/// Journal des notes persisté (`correctionGradeHistory.ts`).
enum CollCorrectionGradeStore {
    /// `ACCOUNT_STORAGE_KEYS.correctionGradeHistory`.
    static let storageKey = "prepapp-correction-grade-history:v1"

    /// `loadCorrectionGradeHistory` : un journal illisible repart à vide.
    static func load() -> [CollCorrectionGradeEntry] {
        CollCorrectionGradeParsing.parse(UserDefaults.standard.string(forKey: storageKey))
    }

    /// `recordCorrectionGrade` : ajoute une note sans limite de rétention. Deux
    /// reprises du même résultat ne créent jamais deux points (idempotence par
    /// `id`).
    @discardableResult
    static func record(_ input: CollCorrectionGradeInput) -> [CollCorrectionGradeEntry] {
        let candidate = CollCorrectionGradeEntry(
            id: input.id,
            activity: input.activity,
            score: input.score,
            submittedAt: input.submittedAt,
            subject: input.subject,
            title: input.title,
            itemIds: input.itemIds
        )
        guard let entry = CollCorrectionGradeParsing.normalizeEntry(candidate) else {
            return load()
        }
        let saved = CollCorrectionGrades.merge([load(), [entry]])
        persist(saved)
        return saved
    }

    /// `loadCorrectionGradeTimeline` : le journal précis prévaut, les bilans
    /// d'exercices, de colles et d'annales plus anciens restent visibles.
    static func timeline(accountId: String) -> [CollCorrectionGradeEntry] {
        let attempts = AnnAttemptStore.loadAnnaleAttempts(accountId: accountId)
        return CollCorrectionGrades.merge([legacyEntries(attempts: attempts, copyJobs: AnnCopyStore.load()), load()])
    }

    /// `legacyCorrectionGradeEntries` : bilans enregistrés avant le journal
    /// unifié — d'anciennes tentatives ne mémorisaient pas la distinction
    /// exercice/colle, le libellé reste donc neutre (`entrainement`).
    static func legacyEntries(
        attempts: AnnAttemptMap,
        copyJobs: [AnnCopyJob]
    ) -> [CollCorrectionGradeEntry] {
        var entries: [CollCorrectionGradeEntry] = []
        for attempt in attempts.values {
            for metric in attempt.metricHistory ?? [] {
                guard let at = isoMilliseconds(metric.submittedAt) else { continue }
                entries.append(CollCorrectionGradeEntry(
                    id: CollCorrectionGradeIds.training(metric.submissionId),
                    activity: .entrainement,
                    score: metric.score,
                    submittedAt: at,
                    subject: nil,
                    title: nil,
                    itemIds: [attempt.itemId]
                ))
            }
        }
        for job in copyJobs where job.status == .ready {
            guard let result = job.result else { continue }
            entries.append(CollCorrectionGradeEntry(
                id: CollCorrectionGradeIds.annaleCopy(job.jobId),
                activity: .annale,
                score: result.score,
                submittedAt: job.updatedAt,
                subject: nil,
                title: "\(job.title) — \(job.partLabel)",
                itemIds: [job.itemId]
            ))
        }
        return CollCorrectionGrades.merge([entries])
    }

    /// Écrit le journal sous forme de chaîne JSON dans les préférences.
    private static func persist(_ entries: [CollCorrectionGradeEntry]) {
        guard let data = try? JSONEncoder().encode(entries),
              let raw = String(data: data, encoding: .utf8)
        else { return }
        UserDefaults.standard.set(raw, forKey: storageKey)
    }

    /// `Date.parse` d'une date ISO 8601, en millisecondes.
    private static func isoMilliseconds(_ raw: String) -> Double? {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: raw) { return date.timeIntervalSince1970 * 1000 }
        iso.formatOptions = [.withInternetDateTime]
        return iso.date(from: raw).map { $0.timeIntervalSince1970 * 1000 }
    }
}
