//
//  SubjChapterPrerequisites+QuestionState.swift
//  Duello
//
//  Port de src/utils/chapterPrerequisites.ts (RN) — `questionPrerequisiteState` :
//  évalue chaque question sans la masquer ni la bloquer, pour la granularité des
//  pastilles du lecteur.
//
//  Découpage (24/09/2026) : section extraite de `SubjChapterPrerequisites.swift`
//  (porté du même fichier source).
//
//  Cible : iOS 16, aucune dépendance externe.
//
import Foundation

extension SubjChapterPrerequisites {

    /// `questionPrerequisiteState` : évalue chaque question sans la masquer ni
    /// la bloquer. Les noms manquants alimentent le détail du badge global, les
    /// identifiants gardent la granularité des pastilles du lecteur.
    static func questionPrerequisiteState(
        _ request: SubjQuestionPrerequisiteRequest
    ) -> SubjQuestionPrerequisiteState {
        let ids = request.questionIds.isEmpty ? ["resolution"] : request.questionIds
        let contextKey = request.chapter.map {
            chapterCompletionKey(request.programYear, $0.id)
        } ?? request.knowledgeContextChapterKey

        var unavailableQuestionIds: [String] = []
        var missing = OrderedNames()
        var started = OrderedNames()

        for questionId in ids {
            // Une fiche de question est exhaustive : sa présence remplace aussi
            // le chapitre porteur implicite.
            let hasQuestionReview = request.questionRequiredChapters?[questionId] != nil
            let state = chapterPrerequisiteState(
                chapterRequest(request, questionId: questionId,
                               hasQuestionReview: hasQuestionReview, contextKey: contextKey)
            )
            if request.reviewPending || !state.ready { unavailableQuestionIds.append(questionId) }
            state.missingNames.forEach { missing.insert($0) }
            state.startedNames.forEach { started.insert($0) }
        }

        return SubjQuestionPrerequisiteState(
            availableCount: ids.count - unavailableQuestionIds.count,
            totalCount: ids.count,
            unavailableQuestionIds: unavailableQuestionIds,
            missingNames: missing.values,
            startedNames: started.values
        )
    }

    /// Requête de chapitre d'une question, avec le remplacement de fiche propre
    /// à `questionPrerequisiteState`.
    private static func chapterRequest(
        _ request: SubjQuestionPrerequisiteRequest,
        questionId: String,
        hasQuestionReview: Bool,
        contextKey: String?
    ) -> SubjPrerequisiteRequest {
        SubjPrerequisiteRequest(
            chapter: hasQuestionReview ? nil : request.chapter,
            requiredChapters: hasQuestionReview
                ? request.questionRequiredChapters?[questionId]
                : request.requiredChapters,
            programYear: request.programYear,
            chaptersByKey: request.chaptersByKey,
            statuses: request.statuses,
            coursePositions: request.coursePositions,
            courseKnowledgeIndexes: request.courseKnowledgeIndexes,
            knowledgeContext: request.questionKnowledgeContexts?[questionId]
                ?? request.knowledgeContext,
            knowledgeContextChapterKey: hasQuestionReview
                ? contextKey
                : request.knowledgeContextChapterKey,
            includeCurrentChapter: hasQuestionReview ? false : request.includeCurrentChapter
        )
    }

    /// Ensemble ordonné et dédoublonné de noms (la source utilise un `Set`).
    private struct OrderedNames {
        private var seen: Set<String> = []
        private(set) var values: [String] = []

        mutating func insert(_ name: String) {
            if seen.insert(name).inserted { values.append(name) }
        }
    }
}
