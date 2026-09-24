//
//  ProgPrereqLycee+Premiere.swift
//  Duello
//
//  Niveau Première spécialité mathématiques — port de
//  `src/data/premierePrerequisites.ts` (RN).
//
//  `PREMIERE_CHAPTER_DEPENDENCIES` suit l'ordre du programme
//  (`PREMIERE_SPE_MATHS`) ; les dépendances sont directes. L'année de la fiche
//  est `LYCEE_PROGRAM_YEAR` (`lyceeProgram.ts`).
//
//  Cible : iOS 16, aucune dépendance externe.
//
import Foundation

extension ProgPrereqLycee {

    /// `PREMIERE_CHAPTER_DEPENDENCIES` : chapitres de Première dont dépend un
    /// chapitre, dans l'ordre du programme. Certaines dépendances visent un
    /// chapitre que la banque ne sert pas encore (`logique-premiere`,
    /// `suites-limites-intuitives`, `fonctions-parite-valeur-absolue`,
    /// `bernoulli-premiere`, `experimentations-simulation`,
    /// `algorithmique-premiere`).
    static let PREMIERE_CHAPTER_DEPENDENCIES: [String: [String]] = [
        // Les automatismes ouvrent l'année : calcul numérique, littéral et
        // pourcentages sont mobilisés par tous les chapitres qui suivent.
        "logique-premiere": [],
        "automatismes-premiere": [],
        // Une équation du second degré commence par développer et factoriser.
        "second-degre": ["automatismes-premiere"],
        // Une suite se définit sur une expression algébrique ; les sommes
        // géométriques se calculent avec le second degré.
        "suites-premiere": ["second-degre", "automatismes-premiere"],
        "suites-limites-intuitives": ["suites-premiere"],
        // Le nombre dérivé se calcule comme limite d'un taux de variation.
        "derivation-premiere": ["second-degre"],
        "derivation-variations": ["derivation-premiere"],
        // L'exponentielle est introduite par les suites géométriques.
        "fonction-exponentielle": ["derivation-variations", "suites-premiere"],
        "fonctions-parite-valeur-absolue": ["derivation-premiere"],
        // Le cercle trigonométrique ne suppose aucun chapitre antérieur.
        "trigonometrie-premiere": [],
        // Le produit scalaire reprend les vecteurs du plan de Seconde.
        "produit-scalaire-premiere": [],
        // Les équations de droites et de cercles se déduisent du produit scalaire.
        "geometrie-repere-premiere": ["produit-scalaire-premiere"],
        // Les probabilités conditionnelles se lisent dans un tableau croisé.
        "probabilites-conditionnelles-premiere": [],
        "variables-aleatoires-premiere": ["probabilites-conditionnelles-premiere"],
        "bernoulli-premiere": ["variables-aleatoires-premiere"],
        "experimentations-simulation": ["variables-aleatoires-premiere"],
        "algorithmique-premiere": [],
    ]

    /// `dependency` : exigence portée par un chapitre antérieur de Première.
    private static func premiereDependency(_ chapterId: String) -> SubjChapterPrerequisite {
        SubjChapterPrerequisite(
            year: LYCEE_PROGRAM_YEAR,
            chapterId: chapterId,
            requiredStatus: .completed,
            reason: "Notion antérieure du programme de Première nécessaire à la résolution."
        )
    }

    /// `premiereRequiredChapters` : chapitres exigés par un sujet, le chapitre
    /// porteur compris. Le porteur demande le chapitre terminé dès que la
    /// difficulté l'implique ; ses dépendances sont toujours à avoir terminées.
    static func premiereRequiredChapters(
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
        let dependencies = (PREMIERE_CHAPTER_DEPENDENCIES[chapterId] ?? []).map(premiereDependency)
        return ProgPrereqMpsiMpGraph.uniqueChapterPrerequisites([carrier] + dependencies)
    }

    /// `premierePrerequisiteSignature` : empreinte du contenu d'une banque de
    /// chapitre — FNV-1a 32 bits sur les unités de code UTF-16 (comme
    /// `charCodeAt`). Une modification de la banque doit remettre sa revue en
    /// attente.
    static func premierePrerequisiteSignature(_ exercises: [ProgPrereq.Exercise]) -> String {
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

    /// `REVIEWED_PREMIERE_BANK_SIGNATURES` : empreintes des banques de Première
    /// dont les prérequis ont été contrôlés.
    static let REVIEWED_PREMIERE_BANK_SIGNATURES: [String: String] = [
        "premiere:exercice:second-degre": "d2a849b1",
        "premiere:exercice:suites-premiere": "eed10392",
        "premiere:exercice:derivation-premiere": "f9ea1d9d",
        "premiere:exercice:derivation-variations": "41316d66",
        "premiere:exercice:fonction-exponentielle": "8811fdd8",
        "premiere:exercice:trigonometrie-premiere": "ba05f0ce",
        "premiere:exercice:produit-scalaire-premiere": "3228a476",
        "premiere:exercice:geometrie-repere-premiere": "52112314",
        "premiere:exercice:probabilites-conditionnelles-premiere": "a5b9a487",
        "premiere:exercice:variables-aleatoires-premiere": "7e4054ea",
        "premiere:exercice:automatismes-premiere": "30f142b7",
    ]

    /// `premiereExercisePrerequisiteReview` : fiche de prérequis d'un sujet de
    /// Première, portée au niveau de l'exercice. Une banque dont l'empreinte ne
    /// correspond plus repasse en `pending`.
    static func premiereExercisePrerequisiteReview(
        _ input: ProgPrereq.ReviewInput
    ) -> ProgPrereqReview {
        let prerequisites = premiereRequiredChapters(input.chapterId, input.exercise.difficulty)
        if REVIEWED_PREMIERE_BANK_SIGNATURES[input.bankId] != input.bankSignature {
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
