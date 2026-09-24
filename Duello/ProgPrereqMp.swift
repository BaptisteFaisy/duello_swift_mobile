//
//  ProgPrereqMp.swift
//  Duello
//
//  Phase 1a — port de src/data/mpPrerequisites.ts (RN) : revue des prérequis
//  par exercice pour la filière MP (deuxième année), et empreinte de banque.
//
//  Réutilise sans les redéfinir :
//    - `ProgPrereqMpsiMpGraph` : `mpDependencies`, `uniqueChapterPrerequisites(_:)`,
//      `semanticQuestionPrerequisites(year:chapterId:questionText:)` ;
//    - `SubjChapterPrerequisites.questionReviewSourceFor(_:editorialSource:)`
//      (`+Granularity.swift`) ;
//    - `SubjChapterPrerequisite`, `SubjRequiredCourseStatus`
//      (`SubjChapterPrerequisites.swift`) et `SubjProgramYear`
//      (`SubjFlashcardSelection.swift`).
//
//  Fidélité : `REVIEWED_MP_BANK_SIGNATURES`, `COMPLETED_CHAPTER_DIFFICULTY = 3`,
//  les raisons, `reviewedAt` et `reviewer` sont recopiés à l'identique.
//
//  ⚠️ `mpDependencies` porte des `MpsiMpDependency` (année + statut + raison) ;
//  la conversion au boundary vers `SubjChapterPrerequisite` est faite ici
//  (`asPrerequisite(_:)`), comme le socle le laisse à l'appelant.
//
//  Cible : iOS 16, aucune dépendance externe.
//
import Foundation

// MARK: - Revue des prérequis MP

/// `mpPrerequisites.ts` : revue par exercice pour la deuxième année MP.
enum ProgPrereqMp {

    // MARK: - Banques relues

    /// `REVIEWED_MP_BANK_SIGNATURES` : empreinte attendue de chaque banque
    /// auditée. Une signature n'est ajoutée qu'après contrôle du rattachement du
    /// chapitre et de ses dépendances ; toute modification remet la banque
    /// concernée en attente.
    private static let reviewedBankSignatures: [String: String] = [
        "mp-2:exercice:espaces-normes": "2620e18a",
        "mp-2:exercice:topologie": "70fe824b",
        "mp-2:exercice:series-numeriques": "0c839022",
        "mp-2:exercice:familles-sommables": "4dc54f59",
        "mp-2:exercice:suites-series-fonctions": "8ab30d95",
        "mp-2:exercice:series-entieres": "f19adaae",
        "mp-2:exercice:integration-intervalle": "56568607",
        "mp-2:exercice:convergence-dominee": "5acf20d9",
        "mp-2:exercice:fonctions-vectorielles": "560173e9",
        "mp-2:exercice:systemes-differentiels": "0717c3ea",
        "mp-2:exercice:calcul-differentiel": "3f92ca27",
        "mp-2:exercice:extrema": "7cf6c3bf",
        "mp-2:exercice:structures-arithmetique": "c25a4b4d",
        "mp-2:exercice:algebre-lineaire": "311999f9",
        "mp-2:exercice:matrices-determinants": "c802ef69",
        "mp-2:exercice:valeurs-propres": "629d6fb1",
        "mp-2:exercice:diagonalisation": "23f4f614",
        "mp-2:exercice:cayley-hamilton": "e51609aa",
        "mp-2:exercice:prehilbertiens": "849af702",
        "mp-2:exercice:euclidiens": "a3cf296a",
        "mp-2:exercice:isometries": "ded51411",
        "mp-2:exercice:espaces-probabilises": "f2e71627",
        "mp-2:exercice:variables-discretes": "306a8e56",
        "mp-2:exercice:couples-independance": "b56e7ebb",
        "mp-2:exercice:fonctions-generatrices": "6dd75939",
        "mp-2:exercice:concentration": "ca27bc60",
        "mp-2:exercice:convexite": "da91627c",
    ]

    /// `COMPLETED_CHAPTER_DIFFICULTY` : difficulté à partir de laquelle un sujet
    /// n'est plus abordable avec le seul début du chapitre. Un chapitre « en
    /// cours » ne dit pas où l'étudiant en est ; la difficulté auditée est le
    /// seul indicateur dérivé qui en approche.
    private static let completedChapterDifficulty = 3

    // MARK: - Empreinte de banque

    /// `mpPrerequisiteSignature` : empreinte FNV-1a 32 bits des exercices d'une
    /// banque, ou l'empreinte préservée du premier exercice. Les codes UTF-16 de
    /// la source (`charCodeAt`) sont recopiés tels quels.
    static func signature(_ exercises: [ProgPrereq.Exercise]) -> String {
        if let preserved = exercises.first?.prerequisiteBankSignature, !preserved.isEmpty {
            return preserved
        }
        let source = exercises
            .map { exercise in
                [exercise.key, exercise.title, exercise.statement, exercise.solution ?? ""]
                    .joined(separator: "\u{1f}")
            }
            .joined(separator: "\u{1e}")
        var hash: UInt32 = 0x811c_9dc5
        for unit in source.utf16 {
            hash ^= UInt32(unit)
            hash = hash &* 0x0100_0193
        }
        let hex = String(hash, radix: 16)
        return String(repeating: "0", count: max(0, 8 - hex.count)) + hex
    }

    // MARK: - Exigences du sujet

    /// `prerequisites(chapterId, difficulty)` : le chapitre qui porte le sujet,
    /// puis ses dépendances de programme (deuxième année).
    private static func prerequisites(
        chapterId: String,
        difficulty: Int?
    ) -> [SubjChapterPrerequisite] {
        let requiredStatus: SubjRequiredCourseStatus =
            (difficulty ?? 1) >= completedChapterDifficulty ? .completed : .inProgress
        let carrier = SubjChapterPrerequisite(
            year: .second,
            chapterId: chapterId,
            requiredStatus: requiredStatus,
            reason: requiredStatus == .completed
                ? "Chapitre du sujet, dont la difficulté suppose le chapitre terminé."
                : "Chapitre dans lequel le sujet est rangé."
        )
        let dependencies = (ProgPrereqMpsiMpGraph.mpDependencies[chapterId] ?? [])
            .map(asPrerequisite)
        return [carrier] + dependencies
    }

    /// Conversion au boundary : `MpsiMpDependency` (année + statut + raison) vers
    /// `SubjChapterPrerequisite`.
    private static func asPrerequisite(_ dependency: MpsiMpDependency) -> SubjChapterPrerequisite {
        SubjChapterPrerequisite(
            year: dependency.year,
            chapterId: dependency.chapterId,
            requiredStatus: dependency.requiredStatus,
            reason: dependency.reason
        )
    }

    // MARK: - Ventilation par question

    /// Ventilation d'une banque relue : chaque question reprend les exigences de
    /// l'exercice, augmentées de ce que son énoncé et son corrigé mobilisent.
    private static func questionBreakdown(
        _ input: ProgPrereq.ReviewInput,
        exercisePrerequisites: [SubjChapterPrerequisite]
    ) -> [String: [SubjChapterPrerequisite]] {
        var breakdown: [String: [SubjChapterPrerequisite]] = [:]
        for questionId in input.questionIds {
            let questionText = "\(input.questionPrompts[questionId] ?? "")\n"
                + "\(input.questionSolutions[questionId] ?? "")"
            let semantic = ProgPrereqMpsiMpGraph.semanticQuestionPrerequisites(
                year: .second,
                chapterId: input.chapterId,
                questionText: questionText
            )
            breakdown[questionId] = ProgPrereqMpsiMpGraph.uniqueChapterPrerequisites(
                exercisePrerequisites + semantic
            )
        }
        return breakdown
    }

    // MARK: - Revue par exercice

    /// `mpExercisePrerequisiteReview` : revue d'un exercice de deuxième année MP.
    /// Une banque non relue reste `pending` ; une banque relue ventile par
    /// question dès qu'elle en porte au moins deux.
    static func review(_ input: ProgPrereq.ReviewInput) -> ProgPrereqReview {
        let exercisePrerequisites = prerequisites(
            chapterId: input.chapterId,
            difficulty: input.exercise.difficulty
        )
        guard reviewedBankSignatures[input.bankId] == input.bankSignature else {
            return ProgPrereqReview(
                status: .pending,
                granularity: .exercise,
                prerequisites: exercisePrerequisites,
                questionPrerequisites: nil,
                questionReviewSource: nil,
                reviewedAt: nil,
                reviewer: nil
            )
        }
        guard input.questionIds.count >= 2 else {
            return ProgPrereqReview(
                status: .reviewed,
                granularity: .exercise,
                prerequisites: exercisePrerequisites,
                questionPrerequisites: nil,
                questionReviewSource: nil,
                reviewedAt: "2026-07-30",
                reviewer: "Duello"
            )
        }
        let breakdown = questionBreakdown(input, exercisePrerequisites: exercisePrerequisites)
        return ProgPrereqReview(
            status: .reviewed,
            granularity: .questions,
            prerequisites: exercisePrerequisites,
            questionPrerequisites: breakdown,
            questionReviewSource: SubjChapterPrerequisites.questionReviewSourceFor(
                breakdown,
                editorialSource: .semantic
            ),
            reviewedAt: "2026-07-30",
            reviewer: "Duello"
        )
    }
}
