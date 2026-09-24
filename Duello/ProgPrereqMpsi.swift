//
//  ProgPrereqMpsi.swift
//  Duello
//
//  Phase 1a (mpsi) — port de src/data/mpsiPrerequisites.ts (RN) : revue de
//  prérequis par exercice MPSI (statut, granularité, ventilation par question)
//  et empreinte éditoriale de banque.
//
//  Réutilise sans les redéfinir (ne pas modifier) :
//    - `ProgPrereqMpsiMpGraph.mpsiDependencies`, `.uniqueChapterPrerequisites(_:)`,
//      `.semanticQuestionPrerequisites(year:chapterId:questionText:)` (socle, phase 0) ;
//    - `SubjChapterPrerequisites.questionReviewSourceFor(_:editorialSource:)`
//      (`SubjChapterPrerequisites+Granularity.swift`) ;
//    - `SubjChapterPrerequisite`, `SubjRequiredCourseStatus`,
//      `SubjQuestionReviewSource`, `SubjProgramYear`.
//
//  Notes :
//  - Le type RN `ReviewableMpsiExercise` est le `ProgPrereq.Exercise` du socle.
//  - `mpsiPrerequisiteSignature` est recopié tel quel (FNV-1a 32 bits, séparateurs
//    `\u001f` / `\u001e`, empreinte préservée si le premier exercice en porte une).
//  - La source itère `charCodeAt` (unités UTF-16) : le port itère `source.utf16`.
//
//  Cible : iOS 16, aucune dépendance externe.
//
import Foundation

// MARK: - Revue par exercice (MPSI)

/// `mpsiPrerequisites.ts` : revue de prérequis des exercices de première année
/// MPSI, plus l'empreinte de banque qui décide de l'état relu.
enum ProgPrereqMpsi {

    /// Difficulté à partir de laquelle le sujet suppose le chapitre terminé
    /// (`COMPLETED_CHAPTER_DIFFICULTY`).
    static let completedChapterDifficulty = 3

    /// `REVIEWED_MPSI_BANK_SIGNATURES` : empreintes entrées en revue (32).
    static let reviewedBankSignatures: [String: String] = [
        "mpsi-1:exercice:analyse-asymptotique": "11b8be70",
        "mpsi-1:exercice:applications-lineaires": "cc128cac",
        "mpsi-1:exercice:arithmetique": "7357380e",
        "mpsi-1:exercice:calcul-derivation": "7f346d8e",
        "mpsi-1:exercice:complexes": "d2d82e2a",
        "mpsi-1:exercice:denombrement": "de1062e8",
        "mpsi-1:exercice:derivabilite": "12f6155d",
        "mpsi-1:exercice:determinants": "d469be9b",
        "mpsi-1:exercice:dimension": "4dfe310b",
        "mpsi-1:exercice:ensembles": "f545544d",
        "mpsi-1:exercice:equations-differentielles": "e5bfdda9",
        "mpsi-1:exercice:espaces-vectoriels": "bba6a7ce",
        "mpsi-1:exercice:fonctions-deux-variables": "ed0e6e5f",
        "mpsi-1:exercice:fonctions-usuelles": "c9ac596f",
        "mpsi-1:exercice:fractions-rationnelles": "7dd3453c",
        "mpsi-1:exercice:geometrie": "c9fde097",
        "mpsi-1:exercice:integration": "1d2cfbec",
        "mpsi-1:exercice:limites-continuite": "b097ed9b",
        "mpsi-1:exercice:logique": "4606335c",
        "mpsi-1:exercice:matrices": "b17ef047",
        "mpsi-1:exercice:polynomes": "3d6df5e1",
        "mpsi-1:exercice:prehilbertiens": "986f73a8",
        "mpsi-1:exercice:probabilites": "ef3548d2",
        "mpsi-1:exercice:problemes-transversaux": "10a289f8",
        "mpsi-1:exercice:reels": "89fd5b71",
        "mpsi-1:exercice:series-numeriques": "feda40c2",
        "mpsi-1:exercice:sommes-produits": "2116b57f",
        "mpsi-1:exercice:structures-algebriques": "d49f3544",
        "mpsi-1:exercice:suites": "4e8fd8c2",
        "mpsi-1:exercice:systemes-lineaires": "891ef215",
        "mpsi-1:exercice:taylor": "21118e43",
        "mpsi-1:exercice:variables-aleatoires": "0f3ca7e5",
    ]

    // MARK: - Empreinte éditoriale

    /// `mpsiPrerequisiteSignature` : FNV-1a 32 bits sur les champs de chaque
    /// exercice, recopié tel quel. Une empreinte déjà portée par le premier
    /// exercice est conservée telle quelle (elle n'est pas recalculée).
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

    // MARK: - Revue

    /// `mpsiExercisePrerequisiteReview` : prérequis d'un exercice MPSI, ventilés
    /// par question lorsque la banque a été relue et compte au moins deux
    /// questions.
    static func review(_ input: ProgPrereq.ReviewInput) -> ProgPrereqReview {
        let prerequisites = exercisePrerequisites(
            chapterId: input.chapterId,
            statement: input.exercise.statement,
            difficulty: input.exercise.difficulty
        )
        guard reviewedBankSignatures[input.bankId] == input.bankSignature else {
            return ProgPrereqReview(
                status: .pending,
                granularity: .exercise,
                prerequisites: prerequisites,
                questionPrerequisites: nil,
                questionReviewSource: nil,
                reviewedAt: nil,
                reviewer: nil
            )
        }

        let questionPrerequisites = input.questionIds.count >= 2
            ? questionPrerequisites(for: input, prerequisites: prerequisites)
            : nil

        return ProgPrereqReview(
            status: .reviewed,
            granularity: questionPrerequisites == nil ? .exercise : .questions,
            prerequisites: prerequisites,
            questionPrerequisites: questionPrerequisites,
            questionReviewSource: questionPrerequisites.map {
                SubjChapterPrerequisites.questionReviewSourceFor($0, editorialSource: .semantic)
            },
            reviewedAt: "2026-08-21",
            reviewer: "Duello"
        )
    }

    // MARK: - Construction des prérequis

    /// `carrierStatus` : un sujet d'application se traite dès les premières
    /// séances, un sujet de synthèse suppose le chapitre bouclé.
    private static func carrierStatus(_ difficulty: Int?) -> SubjRequiredCourseStatus {
        (difficulty ?? 1) >= completedChapterDifficulty ? .completed : .inProgress
    }

    /// `dependency` : notion antérieure nécessaire, exigée terminée.
    private static func dependency(
        _ chapterId: String,
        reason: String = "Notion antérieure nécessaire à la résolution."
    ) -> SubjChapterPrerequisite {
        SubjChapterPrerequisite(
            year: .first,
            chapterId: chapterId,
            requiredStatus: .completed,
            reason: reason
        )
    }

    /// `transversePrerequisites` : notions qu'un problème transversal mobilise,
    /// reconnues dans l'énoncé (5 motifs, drapeau `/…/i`).
    private static func transversePrerequisites(_ statement: String) -> [SubjChapterPrerequisite] {
        var prerequisites: [SubjChapterPrerequisite] = []
        if matches(#"suite|u\s*n|r[ée]currence"#, statement) {
            prerequisites.append(dependency("suites", reason: "Le problème mobilise les suites numériques."))
        }
        if matches(#"limite|continuit|d[ée]riv|fonction"#, statement) {
            prerequisites.append(
                dependency("derivabilite", reason: "Le problème mobilise l’étude des fonctions d’une variable.")
            )
        }
        if matches(#"int[ée]grale|primitive|∫"#, statement) {
            prerequisites.append(dependency("integration", reason: "Le problème mobilise le calcul intégral."))
        }
        if matches(#"matrice|endomorph|application lin[ée]aire"#, statement) {
            prerequisites.append(
                dependency("applications-lineaires", reason: "Le problème mobilise l’algèbre linéaire.")
            )
        }
        if matches(#"probabilit|variable al[ée]atoire|esp[ée]rance|variance"#, statement) {
            prerequisites.append(
                dependency("variables-aleatoires", reason: "Le problème mobilise les probabilités et variables aléatoires.")
            )
        }
        return prerequisites
    }

    /// Test d'un motif de notion (drapeau `/…/i` de la source).
    private static func matches(_ pattern: String, _ text: String) -> Bool {
        text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }

    /// `exercisePrerequisites` : chapitre porteur (statut selon la difficulté),
    /// dépendances du programme, et motifs transversaux du seul chapitre
    /// `problemes-transversaux`, dédoublonnés.
    private static func exercisePrerequisites(
        chapterId: String,
        statement: String,
        difficulty: Int?
    ) -> [SubjChapterPrerequisite] {
        let requiredStatus = carrierStatus(difficulty)
        let carrier = SubjChapterPrerequisite(
            year: .first,
            chapterId: chapterId,
            requiredStatus: requiredStatus,
            reason: requiredStatus == .completed
                ? "Chapitre du sujet, dont la difficulté suppose le chapitre terminé."
                : "Chapitre dans lequel le sujet est rangé."
        )
        let structural = (ProgPrereqMpsiMpGraph.mpsiDependencies[chapterId] ?? []).map { dependency($0) }
        let transverse = chapterId == "problemes-transversaux" ? transversePrerequisites(statement) : []
        return ProgPrereqMpsiMpGraph.uniqueChapterPrerequisites([carrier] + structural + transverse)
    }

    /// Ventilation : chaque question hérite des prérequis de l'exercice, puis
    /// ajoute ceux que son énoncé et son corrigé mobilisent.
    private static func questionPrerequisites(
        for input: ProgPrereq.ReviewInput,
        prerequisites: [SubjChapterPrerequisite]
    ) -> [String: [SubjChapterPrerequisite]] {
        var byQuestion: [String: [SubjChapterPrerequisite]] = [:]
        for questionId in input.questionIds {
            let text = "\(input.questionPrompts[questionId] ?? "")\n\(input.questionSolutions[questionId] ?? "")"
            let semantic = ProgPrereqMpsiMpGraph.semanticQuestionPrerequisites(
                year: .first,
                chapterId: input.chapterId,
                questionText: text
            )
            byQuestion[questionId] = ProgPrereqMpsiMpGraph.uniqueChapterPrerequisites(prerequisites + semantic)
        }
        return byQuestion
    }
}
