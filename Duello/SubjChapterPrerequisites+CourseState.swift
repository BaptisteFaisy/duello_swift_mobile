//
//  SubjChapterPrerequisites+CourseState.swift
//  Duello
//
//  Port de src/utils/chapterPrerequisites.ts (RN) — comparaison des
//  connaissances qu'un sujet mobilise à l'avancement du cours.
//
//  Découpage (24/09/2026) : section extraite de `SubjChapterPrerequisites.swift`
//  (porté du même fichier source).
//
//  Cible : iOS 16, aucune dépendance externe.
//
import Foundation

extension SubjChapterPrerequisites {

    /// `chapterPrerequisiteState` : compare les connaissances qu'un sujet
    /// mobilise à l'avancement du cours.
    static func chapterPrerequisiteState(_ request: SubjPrerequisiteRequest) -> SubjPrerequisiteState {
        let required = expandedChapterRequirements(
            chapter: request.chapter,
            requiredChapters: request.requiredChapters,
            programYear: request.programYear,
            chaptersByKey: request.chaptersByKey,
            includeCurrentChapter: request.includeCurrentChapter
        )
        let contextKey = request.knowledgeContextChapterKey
            ?? (request.includeCurrentChapter
                ? request.chapter.map { chapterCompletionKey(request.programYear, $0.id) }
                : nil)

        var missingNames: [String] = []
        var startedNames: [String] = []
        for (key, prerequisite) in required.entries {
            let status = request.statuses[key]
            // Les choix explicites de l'élève sont immédiats et souverains : le
            // repère n'affine qu'un chapitre déclaré « En cours ».
            if status == .completed { continue }
            let position = requiredCoursePosition(
                request, key: key, prerequisite: prerequisite, contextKey: contextKey
            )
            if let position, let coursePosition = request.coursePositions?[key], coursePosition.isFinite {
                if coursePosition + Double.ulpOfOne >= position { continue }
                let name = name(of: key, chapterId: prerequisite.chapterId, in: request.chaptersByKey)
                if coursePosition > 0 { startedNames.append(name) } else { missingNames.append(name) }
                continue
            }
            if status == .inProgress, prerequisite.requiredStatus == .inProgress { continue }
            let name = name(of: key, chapterId: prerequisite.chapterId, in: request.chaptersByKey)
            if status == .inProgress { startedNames.append(name) } else { missingNames.append(name) }
        }
        return SubjPrerequisiteState(
            requiredCount: required.count,
            missingNames: missingNames,
            startedNames: startedNames,
            ready: missingNames.isEmpty && startedNames.isEmpty
        )
    }

    /// Repère de cours exigé par un prérequis, `nil` quand il n'affine rien.
    private static func requiredCoursePosition(
        _ request: SubjPrerequisiteRequest,
        key: String,
        prerequisite: SubjResolvedChapterPrerequisite,
        contextKey: String?
    ) -> Double? {
        guard request.statuses[key] == .inProgress,
              let index = request.courseKnowledgeIndexes?[key] else { return nil }
        let prerequisitePosition = CollCourseIndex.requiredPosition(index, reason: prerequisite.reason)
        let exercisePosition = CollCourseIndex.requiredPosition(index, reason: request.knowledgeContext)
        // Dans le chapitre actuellement travaillé, le badge reflète la notion
        // propre à l'exercice : toutes les notions reconnues doivent avoir été
        // vues, donc le dernier repère trouvé l'emporte.
        if key == contextKey {
            return [prerequisitePosition, exercisePosition].compactMap { $0 }.max()
        }
        // Ailleurs, la raison pédagogique prime ; l'énoncé n'est qu'un repli.
        return prerequisitePosition ?? exercisePosition
    }

    /// Nom affiché d'un chapitre ; repli sur son identifiant hors programme.
    private static func name(
        of key: String,
        chapterId: String,
        in chaptersByKey: [String: SubjPrerequisiteChapter]
    ) -> String {
        chaptersByKey[key]?.name ?? "Chapitre \(chapterId)"
    }
}
