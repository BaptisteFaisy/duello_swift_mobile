//
//  SubjChapterPrerequisites+Expansion.swift
//  Duello
//
//  Port de src/utils/chapterPrerequisites.ts (RN) — dépliage récursif des
//  connaissances qu'un sujet mobilise, sans encore les comparer à l'avancement
//  du cours.
//
//  Découpage (24/09/2026) : section extraite de `SubjChapterPrerequisites.swift`
//  (porté du même fichier source).
//
//  Cible : iOS 16, aucune dépendance externe.
//
import Foundation

extension SubjChapterPrerequisites {

    /// `chapterCompletionKey` : clé d'un chapitre à travers les deux années.
    static func chapterCompletionKey(_ year: SubjProgramYear, _ chapterId: String) -> String {
        "\(year.rawValue):\(chapterId)"
    }

    /// `expandedChapterRequirements` : déplie récursivement les connaissances
    /// qu'un sujet mobilise, sans encore les comparer à l'avancement du cours.
    ///
    /// Le chapitre qui porte le sujet demande par défaut d'être entamé. Les
    /// dépendances transitives du programme restent des chapitres à terminer.
    static func expandedChapterRequirements(
        chapter: SubjPrerequisiteChapterRef?,
        requiredChapters: [SubjChapterPrerequisite]?,
        programYear: SubjProgramYear,
        chaptersByKey: [String: SubjPrerequisiteChapter],
        includeCurrentChapter: Bool = true
    ) -> SubjExpandedChapterRequirements {
        var result = SubjExpandedChapterRequirements()
        var pending: [SubjResolvedChapterPrerequisite] = []
        if includeCurrentChapter, let chapter {
            pending.append(carrier(chapterId: chapter.id, year: programYear))
        }
        pending += (chapter?.prerequisites ?? []).map { resolved($0, default: .completed) }
        pending += (requiredChapters ?? []).map { resolved($0, default: .completed) }

        while let prerequisite = pending.popLast() {
            let key = chapterCompletionKey(prerequisite.year, prerequisite.chapterId)
            if let existing = result[key],
               existing.requiredStatus == .completed
                   || existing.requiredStatus == prerequisite.requiredStatus {
                continue
            }
            result.set(key, prerequisite)
            pending += (chaptersByKey[key]?.prerequisites ?? []).map { resolved($0, default: .completed) }
        }
        return result
    }

    /// Exigence dépliée à partir d'un prérequis déclaré.
    private static func resolved(
        _ prerequisite: SubjChapterPrerequisite,
        default defaultStatus: SubjRequiredCourseStatus
    ) -> SubjResolvedChapterPrerequisite {
        SubjResolvedChapterPrerequisite(
            year: prerequisite.year,
            chapterId: prerequisite.chapterId,
            requiredStatus: prerequisite.requiredStatus ?? defaultStatus,
            reason: prerequisite.reason
        )
    }

    /// Exigence dépliée du chapitre porteur : à avoir entamé.
    private static func carrier(
        chapterId: String,
        year: SubjProgramYear
    ) -> SubjResolvedChapterPrerequisite {
        SubjResolvedChapterPrerequisite(
            year: year, chapterId: chapterId, requiredStatus: .inProgress, reason: nil
        )
    }
}
