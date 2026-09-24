//
//  ProgPrereqLycee+Seconde.swift
//  Duello
//
//  Niveau Seconde — port de `src/data/secondePrerequisites.ts` (RN).
//
//  `SECONDE_CHAPTER_DEPENDENCIES` suit l'ordre du programme de Seconde
//  (`SECONDE_MATHS`) ; les dépendances sont directes. L'année de la fiche est
//  `LYCEE_PROGRAM_YEAR` (`secondeProgram.ts` ne fait que réexporter la
//  constante de `lyceeProgram.ts`).
//
//  Cible : iOS 16, aucune dépendance externe.
//
import Foundation

extension ProgPrereqLycee {

    /// `SECONDE_CHAPTER_DEPENDENCIES` : chapitres de Seconde dont dépend un
    /// chapitre, dans l'ordre du programme. Les chapitres sans entrée n'ont pas
    /// de notion antérieure propre : le socle de calcul et le calcul littéral
    /// ouvrent l'année. Certaines dépendances visent un chapitre que la banque
    /// ne sert pas encore (`calcul-litteral-identites`, `proportions-evolutions`,
    /// `tableaux-croises-frequences`).
    static let SECONDE_CHAPTER_DEPENDENCIES: [String: [String]] = [
        // Nombres et calculs est le socle de l'année.
        "arithmetique-seconde": ["nombres-et-calculs"],
        // Une équation du premier degré commence par développer et factoriser.
        "equations-inequations-seconde": [
            "nombres-et-calculs",
            "calcul-litteral-identites",
        ],
        "generalites-fonctions": [
            "nombres-et-calculs",
            "equations-inequations-seconde",
        ],
        "fonctions-reference": ["generalites-fonctions"],
        "variations-extremums-seconde": [
            "fonctions-reference",
            "equations-inequations-seconde",
        ],
        // Les vecteurs s'appuient sur le calcul et les coordonnées.
        "vecteurs-du-plan": ["nombres-et-calculs"],
        // Les équations de droites se déduisent des vecteurs, puis se résolvent.
        "geometrie-reperee-droites-seconde": [
            "vecteurs-du-plan",
            "equations-inequations-seconde",
        ],
        // Moyennes, médianes et écarts-types se calculent sur les proportions.
        "statistique-probabilites": [
            "nombres-et-calculs",
            "proportions-evolutions",
        ],
        // Une probabilité conditionnelle se lit dans un tableau croisé.
        "probabilites-conditionnelles-seconde": [
            "statistique-probabilites",
            "tableaux-croises-frequences",
        ],
        // La loi des grands nombres s'énonce avec la fréquence et la probabilité.
        "echantillonnage-loi-grands-nombres": ["statistique-probabilites"],
    ]

    /// `dependency` : exigence portée par un chapitre antérieur de Seconde.
    private static func secondeDependency(_ chapterId: String) -> SubjChapterPrerequisite {
        SubjChapterPrerequisite(
            year: LYCEE_PROGRAM_YEAR,
            chapterId: chapterId,
            requiredStatus: .completed,
            reason: "Notion antérieure du programme de Seconde nécessaire à la résolution."
        )
    }

    /// `secondeRequiredChapters` : chapitres exigés par un sujet, le chapitre
    /// porteur compris. Le porteur demande le chapitre terminé dès que la
    /// difficulté l'implique ; ses dépendances sont toujours à avoir terminées.
    static func secondeRequiredChapters(
        _ chapterId: String,
        _ difficulty: Int?
    ) -> [SubjChapterPrerequisite] {
        let requiredStatus: SubjRequiredCourseStatus =
            (difficulty ?? 1) >= COMPLETED_CHAPTER_DIFFICULTY ? .completed : .inProgress

        let carrier = SubjChapterPrerequisite(
            year: LYCEE_PROGRAM_YEAR,
            chapterId: chapterId,
            requiredStatus: requiredStatus,
            reason: requiredStatus == .completed
                ? "Chapitre du sujet, dont la difficulté suppose le chapitre terminé."
                : "Chapitre dans lequel le sujet est rangé."
        )
        let dependencies = (SECONDE_CHAPTER_DEPENDENCIES[chapterId] ?? []).map(secondeDependency)
        return ProgPrereqMpsiMpGraph.uniqueChapterPrerequisites([carrier] + dependencies)
    }

    /// `secondePrerequisiteSignature` : empreinte du contenu d'une banque de
    /// chapitre — FNV-1a 32 bits sur les unités de code UTF-16 (comme
    /// `charCodeAt`). Une modification de la banque doit remettre sa revue en
    /// attente.
    static func secondePrerequisiteSignature(_ exercises: [ProgPrereq.Exercise]) -> String {
        let source = exercises.map { exercise in
            [
                exercise.key,
                exercise.title,
                exercise.statement,
                exercise.solution ?? "",
                exercise.difficulty.map { String($0) } ?? "",
            ].joined(separator: "\u{1f}")
        }.joined(separator: "\u{1e}")

        var hash: UInt32 = 0x811c9dc5
        for unit in source.utf16 {
            hash ^= UInt32(unit)
            hash = hash &* 0x01000193
        }
        return String(format: "%08x", hash)
    }

    /// `REVIEWED_SECONDE_BANK_SIGNATURES` : empreintes des banques de Seconde
    /// dont les prérequis ont été contrôlés. La revue porte sur le graphe et la
    /// règle de difficulté, pas sur le texte des sujets.
    static let REVIEWED_SECONDE_BANK_SIGNATURES: [String: String] = [
        "seconde:exercice:nombres-et-calculs": "8227578e",
        "seconde:exercice:generalites-fonctions": "ddff422d",
        "seconde:exercice:geometrie-reperee-droites-seconde": "6f8aec05",
        "seconde:exercice:equations-inequations-seconde": "d150461f",
        "seconde:exercice:vecteurs-du-plan": "669775bb",
        "seconde:exercice:statistique-probabilites": "9b560f86",
        "seconde:exercice:probabilites-conditionnelles-seconde": "b01dc57a",
        "seconde:exercice:fonctions-reference": "edbda700",
        "seconde:exercice:variations-extremums-seconde": "320ac968",
        "seconde:exercice:arithmetique-seconde": "a22fd098",
        "seconde:exercice:echantillonnage-loi-grands-nombres": "55b5c166",
    ]

    /// `secondeExercisePrerequisiteReview` : fiche de prérequis d'un sujet de
    /// Seconde, portée au niveau de l'exercice (le contenu vient d'un catalogue
    /// de devoirs où un sujet est un bloc). Une banque dont l'empreinte ne
    /// correspond plus repasse en `pending`.
    static func secondeExercisePrerequisiteReview(
        _ input: ProgPrereq.ReviewInput
    ) -> ProgPrereqReview {
        let prerequisites = secondeRequiredChapters(input.chapterId, input.exercise.difficulty)
        if REVIEWED_SECONDE_BANK_SIGNATURES[input.bankId] != input.bankSignature {
            return ProgPrereqReview(
                status: .pending,
                granularity: .exercise,
                prerequisites: prerequisites
            )
        }
        return ProgPrereqReview(
            status: .reviewed,
            granularity: .exercise,
            prerequisites: prerequisites,
            reviewedAt: "2026-09-20",
            reviewer: "Duello"
        )
    }
}
