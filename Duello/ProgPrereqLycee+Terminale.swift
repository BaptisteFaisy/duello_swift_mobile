//
//  ProgPrereqLycee+Terminale.swift
//  Duello
//
//  Niveau Terminale spécialité mathématiques — port de
//  `src/data/terminalePrerequisites.ts` (RN).
//
//  `TERMINALE_CHAPTER_DEPENDENCIES` suit l'ordre du programme
//  (`TALE_SP_CHAPTERS`) ; les dépendances sont directes. L'année de la fiche
//  est `LYCEE_PROGRAM_YEAR` (`lyceeProgram.ts`).
//
//  Cible : iOS 16, aucune dépendance externe.
//
import Foundation

extension ProgPrereqLycee {

    /// `TERMINALE_CHAPTER_DEPENDENCIES` : chapitres de Terminale dont dépend un
    /// chapitre, dans l'ordre du programme. Certaines dépendances visent un
    /// chapitre que la banque ne sert pas encore (`algorithmique-python`,
    /// `automatismes`).
    static let TERMINALE_CHAPTER_DEPENDENCIES: [String: [String]] = [
        // Les suites ouvrent l'année : récurrence, convergence et limites.
        "suites-recurrence-limites": [],
        // La continuité et le TVI s'énoncent sur les limites de fonctions.
        "limites-continuite-tvi": ["suites-recurrence-limites"],
        // La dérivée d'une composée et la convexité supposent la continuité.
        "derivation-convexite": ["limites-continuite-tvi"],
        // Le logarithme et l'exponentielle sont étudiés par leur dérivée.
        "logarithme-exponentielle": ["derivation-convexite"],
        // La dérivée de sin et cos s'appuie sur les mêmes outils.
        "fonctions-trigonometriques": ["derivation-convexite"],
        // Une équation différentielle linéaire se résout avec l'exponentielle.
        "primitives-equations-differentielles": ["logarithme-exponentielle"],
        // L'intégrale se définit à partir des primitives.
        "calcul-integral": ["primitives-equations-differentielles"],
        // Le dénombrement ouvre le versant probabilités de l'année.
        "combinatoire-denombrement": [],
        // Les vecteurs de l'espace reprennent ceux du plan vus en Première.
        "vecteurs-geometrie-espace": [],
        // Une droite et un plan de l'espace se caractérisent par leurs vecteurs.
        "droites-plans-espace": ["vecteurs-geometrie-espace"],
        "produit-scalaire-espace": ["vecteurs-geometrie-espace"],
        // Une probabilité conditionnelle se compte après le dénombrement.
        "probabilites-conditionnelles": ["combinatoire-denombrement"],
        // La loi d'une variable aléatoire se lit sur les arbres pondérés.
        "variables-aleatoires-lois": ["probabilites-conditionnelles"],
        // L'inégalité de concentration s'énonce pour une variable aléatoire.
        "concentration-loi-grands-nombres": ["variables-aleatoires-lois"],
        "algorithmique-python": [],
        "automatismes": [],
    ]

    /// `dependency` : exigence portée par un chapitre antérieur de Terminale.
    private static func terminaleDependency(_ chapterId: String) -> SubjChapterPrerequisite {
        SubjChapterPrerequisite(
            year: LYCEE_PROGRAM_YEAR,
            chapterId: chapterId,
            requiredStatus: .completed,
            reason: "Notion antérieure du programme de Terminale nécessaire à la résolution."
        )
    }

    /// `terminaleRequiredChapters` : chapitres exigés par un sujet, le chapitre
    /// porteur compris. Le porteur demande le chapitre terminé dès que la
    /// difficulté l'implique ; ses dépendances sont toujours à avoir terminées.
    static func terminaleRequiredChapters(
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
        let dependencies = (TERMINALE_CHAPTER_DEPENDENCIES[chapterId] ?? []).map(terminaleDependency)
        return ProgPrereqMpsiMpGraph.uniqueChapterPrerequisites([carrier] + dependencies)
    }

    /// `terminalePrerequisiteSignature` : empreinte du contenu d'une banque de
    /// chapitre — FNV-1a 32 bits sur les unités de code UTF-16 (comme
    /// `charCodeAt`). Une modification de la banque doit remettre sa revue en
    /// attente.
    static func terminalePrerequisiteSignature(_ exercises: [ProgPrereq.Exercise]) -> String {
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

    /// `REVIEWED_TERMINALE_BANK_SIGNATURES` : empreintes des banques de
    /// Terminale dont les prérequis ont été contrôlés.
    static let REVIEWED_TERMINALE_BANK_SIGNATURES: [String: String] = [
        "terminale:exercice:suites-recurrence-limites": "6b752c41",
        "terminale:exercice:limites-continuite-tvi": "a8da8b4c",
        "terminale:exercice:derivation-convexite": "52bddc32",
        "terminale:exercice:logarithme-exponentielle": "48701123",
        "terminale:exercice:fonctions-trigonometriques": "d395ec3e",
        "terminale:exercice:primitives-equations-differentielles": "d20e2e09",
        "terminale:exercice:calcul-integral": "b7930911",
        "terminale:exercice:combinatoire-denombrement": "7a0a2589",
        "terminale:exercice:vecteurs-geometrie-espace": "68726117",
        "terminale:exercice:droites-plans-espace": "4173324c",
        "terminale:exercice:produit-scalaire-espace": "15d0759a",
        "terminale:exercice:probabilites-conditionnelles": "003bd878",
        "terminale:exercice:variables-aleatoires-lois": "bfb6642c",
        "terminale:exercice:concentration-loi-grands-nombres": "d77fba47",
    ]

    /// `terminaleExercisePrerequisiteReview` : fiche de prérequis d'un sujet de
    /// Terminale, portée au niveau de l'exercice. Une banque dont l'empreinte ne
    /// correspond plus repasse en `pending`.
    static func terminaleExercisePrerequisiteReview(
        _ input: ProgPrereq.ReviewInput
    ) -> ProgPrereqReview {
        let prerequisites = terminaleRequiredChapters(input.chapterId, input.exercise.difficulty)
        if REVIEWED_TERMINALE_BANK_SIGNATURES[input.bankId] != input.bankSignature {
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
            reviewedAt: "2026-09-24",
            reviewer: "Duello"
        )
    }
}
