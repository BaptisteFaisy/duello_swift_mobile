//
//  TrainEcgAnnaleClassification.swift
//  Duello
//
//  Port de src/utils/ecgAnnaleClassification.ts (RN) — classement des annales
//  ECG en 1re ou 2e année : le rangement pédagogique « Révisions de 1re année »
//  ne doit ni classer ni déverrouiller une annale.
//
//  Fichiers source Expo portés (libellés repris mot pour mot) :
//    - src/utils/ecgAnnaleClassification.ts
//        `ECG_YEAR_2_SOURCE_ANNALES_RECLASSIFIED_TO_YEAR_1`,
//        `isEcgRevisionChapter`, `effectiveEcgAnnalePrerequisites`,
//        `ecgAnnaleProgramYear`.
//    - src/data/tracks.ts — `ChapterPrerequisite` et `ProgramYear` sont portés
//        ici (imbriqués dans `TrainEcgAnnaleClassification` pour ne pas entrer en
//        collision avec un futur portage de `tracks.ts` : `Models.swift` ne les
//        modélise pas encore, `TrackChapter` n'ayant ni année ni prérequis).
//
//  Notes datées (24/09/2026) :
//    - Aucune dérive de comportement : les quatre fonctions sont des
//      translations directes, y compris l'ordre d'évaluation.
//    - `requiredStatus` et `reason` de `ChapterPrerequisite` ne sont pas lus par
//      ces fonctions ; ils sont conservés tels quels pour rester fidèles à la
//      source et servir aux portages qui les consomment.
//
//  Cible : iOS 16, aucune dépendance externe.
//

import Foundation

/// `ecgAnnaleClassification.ts` : classement des annales ECG.
enum TrainEcgAnnaleClassification {

    /// Année de programme (`ProgramYear` de `src/data/tracks.ts`) : 1 = 1re
    /// année, 2 = 2e année. Une 3e année reprend le programme de 2e année.
    enum ProgramYear: Int, Codable, CaseIterable {
        case first = 1
        case second = 2
    }

    /// Prérequis d'un chapitre (`ChapterPrerequisite` de `src/data/tracks.ts`).
    struct ChapterPrerequisite: Codable, Equatable, Hashable {
        var chapterId: String
        var year: ProgramYear
        /// Avancement minimal exigé par un sujet (`requiredStatus`) : une
        /// dépendance du programme qui n'indique rien reste un chapitre à
        /// avoir terminé. Non lu par le classement ECG.
        var requiredStatus: String?
        /// Raison pédagogique courte, propre au sujet lorsqu'elle est connue.
        var reason: String?
    }

    /// `ECG_YEAR_2_SOURCE_ANNALES_RECLASSIFIED_TO_YEAR_1` : identifiants déjà
    /// publiés sous une portée ECG2 mais reclassés en ECG1. Ils restent stables
    /// pour préserver progression, téléchargements et corrections ; le catalogue
    /// léger n'embarquant pas les prérequis, cette liste lui permet d'appliquer
    /// le même classement avant le téléchargement des banques.
    static let year2SourceAnnalesReclassifiedToYear1: Set<String> = [
        "ecg-approfondies-2-clemenceau-2025-2026-ds01-top-6",
        "ecg-approfondies-2-edhec-1995",
        "ecg-approfondies-2-edhec-1997",
        "ecg-approfondies-2-edhec-1999",
        "escp-oral-2025-sujet-2-1",
        "escp-oral-2025-sujet-2-2",
        "escp-oral-2025-sujet-2-3",
        "escp-oral-2025-sujet-2-4",
        "escp-oral-2025-sujet-2-5",
        "escp-oral-2025-sujet-3-2",
        "escp-oral-2025-sujet-3-4",
        "hec-oral-2019-s295",
        "hec-oral-2019-s296",
        "hec-oral-2019-s308",
        "hec-oral-2019-s313",
        "ecg-appliquees-2-rentree-2024-2025",
    ]

    /// `isEcgRevisionChapter` : « Révisions de 1re année » est un rangement
    /// pédagogique, pas une notion de deuxième année ; son statut ne doit donc
    /// jamais modifier celui d'une annale.
    static func isEcgRevisionChapter(_ prerequisite: ChapterPrerequisite) -> Bool {
        prerequisite.year == .second && prerequisite.chapterId == "analyse-concours"
    }

    /// `effectiveEcgAnnalePrerequisites` : prérequis qui participent réellement
    /// au classement et au badge d'une annale.
    static func effectiveEcgAnnalePrerequisites(
        _ prerequisites: [ChapterPrerequisite]?
    ) -> [ChapterPrerequisite] {
        (prerequisites ?? []).filter { !isEcgRevisionChapter($0) }
    }

    /// `ecgAnnaleProgramYear` : une annale est ECG2 si, et seulement si, elle
    /// mobilise une vraie notion de deuxième année. Une fiche encore dépourvue de
    /// prérequis conserve son classement source afin de rester bloquée par sa
    /// revue plutôt que d'être déplacée arbitrairement.
    static func ecgAnnaleProgramYear(
        _ prerequisites: [ChapterPrerequisite]?,
        sourceYear: ProgramYear
    ) -> ProgramYear {
        guard let prerequisites, !prerequisites.isEmpty else { return sourceYear }
        let effective = effectiveEcgAnnalePrerequisites(prerequisites)
        return effective.contains { $0.year == .second } ? .second : .first
    }
}
