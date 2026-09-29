//
//  TrainIntItems+Prereq.swift
//  Duello
//
//  Prérequis des fiches d'un chapitre ouvert : contexte partagé (noms de
//  chapitres et statuts de cours) puis modèle de fiche d'un sujet.
//
//  Port de `SubjectsScreen.tsx` (`prerequisiteState`, lignes 6588-6639) et de
//  ses appels de fiche (9258-9271) : la revue par exercice
//  (`exercise.prerequisiteReview`) alimente le dépliage de chapitre
//  (`SubjChapterPrerequisites.chapterPrerequisiteState`) et la granularité par
//  question (`…questionPrerequisiteState`).
//
//  Couture documentée (aucune donnée fabriquée) : la source indexe
//  `chaptersByKey` / `statuses` sur **les deux années** du parcours ; le port ne
//  dispose ici que du programme **affiché** (`subject.chapters`). Les prérequis
//  d'une autre année gardent donc leur repli « Chapitre <id> » et comptent pour
//  « à venir ». Les prérequis **de chapitre** sont vides dans la source RN comme
//  ici : `chaptersByKey` ne sert qu'aux noms.
//
//  Carte de sujet (2026-09-29) : `itemCardModel` ne renseigne encore ni le thème
//  fiable (`themeLabel`), ni le statut de programme (`programStatus`), ni la
//  meilleure note (`bestScore`), ni le premier réussisseur (`firstAchiever`) —
//  métadonnées de `ExerciseItemCard` (`SubjectsScreen.tsx:3185,3313,9362,3138`).
//  Leurs sources ne sont pas portées : `theme`/`programStatus` absents de
//  `DuelloAPI.ChapterExercise`, note absente de `ProgressStore.ItemProgress`,
//  liste des réussites jamais servie. Alimenter le modèle exige d'étendre
//  `TrainExercise.swift`, `DuelloAPIContent.swift` et `ProgressStore.swift`
//  (fichiers hors lot) : cf. « À raccorder » du rapport IMPL-07. Aucune donnée
//  n'est inventée ici.
//
//  Cible iOS 16, aucune dépendance externe.
//
import SwiftUI

/// Contexte des prérequis d'un chapitre ouvert, partagé par toutes ses fiches.
struct PrerequisiteCardContext {
    /// Année de programme du profil (`programYear` de la source).
    var programYear: SubjProgramYear
    /// Noms des chapitres du programme affiché, clé `chapterCompletionKey`.
    var chaptersByKey: [String: SubjPrerequisiteChapter]
    /// Statuts de cours des chapitres, même clé ; même source que les pastilles
    /// de chapitre de l'écran (`TrainCourseStatusStore`).
    var statuses: [String: TrainCourseStatus]
}

extension TrainingCatalogView {

    /// Contexte des prérequis : noms des chapitres du programme affiché et
    /// statuts de cours, indexés par clé de chapitre.
    func prerequisiteCardContext() -> PrerequisiteCardContext {
        let year = prerequisiteProgramYear
        var chapters: [String: SubjPrerequisiteChapter] = [:]
        var statuses: [String: TrainCourseStatus] = [:]
        for chapter in subject.chapters {
            let key = SubjChapterPrerequisites.chapterCompletionKey(year, chapter.id)
            chapters[key] = SubjPrerequisiteChapter(name: chapter.name, prerequisites: [])
            statuses[key] = courseStatus.status(for: chapter.id)
        }
        return PrerequisiteCardContext(
            programYear: year, chaptersByKey: chapters, statuses: statuses
        )
    }

    /// Année de programme du profil, telle que la source la résout
    /// (`toProgramYear`) : « 2 » dans le libellé signifie 2e année.
    var prerequisiteProgramYear: SubjProgramYear {
        TrainContent.programYear(from: session.profile.year) == 2 ? .second : .first
    }

    /// Modèle de fiche d'un sujet, complété des prérequis de sa revue. Reste
    /// vide (aucun prérequis) quand le sujet n'en porte pas — filière non servie.
    func itemCardModel(
        _ exercise: TrainExercise, chapter: TrackChapter, context: PrerequisiteCardContext
    ) -> SubjItemCardModel {
        var model = SubjItemCardModel(title: exercise.title, difficulty: exercise.difficulty)
        guard let review = exercise.prerequisiteReview else { return model }
        model.isPrerequisiteReviewPending = review.status == .pending

        let chapterRef = SubjPrerequisiteChapterRef(id: chapter.id, prerequisites: [])
        let state = SubjChapterPrerequisites.chapterPrerequisiteState(
            SubjPrerequisiteRequest(
                chapter: chapterRef,
                requiredChapters: review.prerequisites,
                programYear: context.programYear,
                chaptersByKey: context.chaptersByKey,
                statuses: context.statuses,
                coursePositions: nil,
                courseKnowledgeIndexes: nil,
                knowledgeContext: nil,
                knowledgeContextChapterKey: nil,
                includeCurrentChapter: true
            )
        )
        model.missingPrerequisites = state.missingNames
        model.startedPrerequisites = state.startedNames

        let questions = SubjChapterPrerequisites.questionPrerequisiteState(
            SubjQuestionPrerequisiteRequest(
                chapter: chapterRef,
                programYear: context.programYear,
                chaptersByKey: context.chaptersByKey,
                statuses: context.statuses,
                questionIds: questionIds(exercise.statement),
                requiredChapters: review.prerequisites,
                questionRequiredChapters: review.questionPrerequisites,
                reviewPending: review.status == .pending,
                questionKnowledgeContexts: nil,
                coursePositions: nil,
                courseKnowledgeIndexes: nil,
                knowledgeContext: nil,
                knowledgeContextChapterKey: nil,
                includeCurrentChapter: true
            )
        )
        model.availableQuestionCount = questions.availableCount
        model.totalQuestionCount = questions.totalCount
        return model
    }

    /// Identifiants de question d'un énoncé, dans l'ordre du texte
    /// (`statementQuestions` de la source).
    private func questionIds(_ statement: String) -> [String] {
        StmtQuestions.extractStatementQuestions(statement).map(\.id)
    }
}
