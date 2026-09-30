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
//  Carte de sujet (2026-09-30) : `itemCardModel` renseigne le thème fiable
//  (`themeLabel`, `visibleItemTheme`) et le statut de programme
//  (`programStatus`) — métadonnées de `ExerciseItemCard`
//  (`SubjectsScreen.tsx:3185,3313`) — puis la meilleure note (`bestScore`,
//  `annaleAttempts[item.id]?.bestSubmittedScore`, `:9373`) et le premier
//  réussisseur (`firstAchiever`, `achieversFor(item)` + `difficulty >= 5`,
//  `:9384,3138`). La note vient de `AnnAttemptStore` (tentatives du compte) ;
//  les réussites très difficiles de `SubjVeryHardAchievers`, complétées par la
//  réussite locale optimiste. Aucune donnée n'est inventée ici.
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

    /// Meilleure note enregistrée d'un sujet
    /// (`annaleAttempts[item.id]?.bestSubmittedScore`, `SubjectsScreen.tsx:9373`) :
    /// le bilan de la tentative locale du compte, lu dans `AnnAttemptStore`.
    private func bestScore(for itemId: String) -> Double? {
        let accountId = ConsentPremiumGate.accountId(email: session.profile.email)
        return AnnAttemptStore.loadAnnaleAttempts(accountId: accountId)[itemId]?.bestSubmittedScore
    }

    /// Premier réussisseur d'un sujet (`achieversFor(item)` puis
    /// `firstAchiever`, `SubjectsScreen.tsx:9384,3138`) : réservé aux exercices
    /// très difficiles (`difficulty >= 5`). Le profil local de l'élève est servi
    /// en tête dès qu'il a réussi le sujet et n'est pas encore publié
    /// (`progress[item.id]?.bestOutcome === 'success'`), sinon le premier profil
    /// publié (`SubjVeryHardAchievers`).
    private func firstAchiever(for exercise: TrainExercise) -> SubjItemAchiever? {
        guard let difficulty = exercise.difficulty, difficulty >= 5 else { return nil }
        let published = SubjVeryHardAchievers.shared.byItemId[exercise.id] ?? []
        let ownId = DuelloAPI.publicProfileId(email: session.profile.email)
        if progress.items[exercise.id]?.bestOutcome == .success,
           !published.contains(where: { $0.id == ownId }) {
            return SubjItemAchiever(
                id: ownId,
                displayName: session.profile.displayName,
                photoURL: nil
            )
        }
        return published.first
    }

    /// Demande les réussites des exercices très difficiles du chapitre ouvert,
    /// une seule fois par identifiant (`veryHardAchievements`).
    private func requestVeryHardAchievers(for chapter: TrackChapter) {
        let ids = (loadedExercises[chapter.id] ?? [])
            .filter { ($0.difficulty ?? 0) >= 5 }
            .map(\.id)
        guard !ids.isEmpty else { return }
        SubjVeryHardAchievers.shared.ensureLoaded(exerciseIds: ids, token: session.token)
    }

    /// Modèle de fiche d'un sujet, complété des prérequis de sa revue. Reste
    /// vide (aucun prérequis) quand le sujet n'en porte pas — filière non servie.
    func itemCardModel(
        _ exercise: TrainExercise, chapter: TrackChapter, context: PrerequisiteCardContext
    ) -> SubjItemCardModel {
        var model = SubjItemCardModel(
            id: exercise.id, title: exercise.title, difficulty: exercise.difficulty
        )
        model.themeLabel = SubjItemThemeLabel.visible(
            badges: exercise.badges, theme: exercise.theme
        )
        model.programStatus = SubjProgramStatus(rawValue: exercise.programStatus ?? "") ?? .auProgramme
        model.bestScore = bestScore(for: exercise.id)
        model.firstAchiever = firstAchiever(for: exercise)
        requestVeryHardAchievers(for: chapter)
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

        let questions = questionPrerequisiteState(chapterRef, review, context, exercise)
        model.availableQuestionCount = questions.availableCount
        model.totalQuestionCount = questions.totalCount
        return model
    }

    /// État des prérequis de question d'une revue (`questionPrerequisiteState`) :
    /// les questions que l'avancement permet réellement de traiter.
    private func questionPrerequisiteState(
        _ chapterRef: SubjPrerequisiteChapterRef,
        _ review: ProgPrereqReview,
        _ context: PrerequisiteCardContext,
        _ exercise: TrainExercise
    ) -> SubjQuestionPrerequisiteState {
        SubjChapterPrerequisites.questionPrerequisiteState(
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
    }

    /// Identifiants de question d'un énoncé, dans l'ordre du texte
    /// (`statementQuestions` de la source).
    private func questionIds(_ statement: String) -> [String] {
        StmtQuestions.extractStatementQuestions(statement).map(\.id)
    }
}
