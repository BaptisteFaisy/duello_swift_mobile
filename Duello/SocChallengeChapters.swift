//
//  SocChallengeChapters.swift
//  Duello
//
//  V1 L5 (2026-09-26) — chapitres éligibles aux volets de défi : liste du
//  programme entier (Défi-Exercice) et liste réduite aux chapitres avec
//  flashcards (Défi-Cours).
//
//  Fichier source Expo porté (ordres et clés repris mot pour mot) :
//    - src/utils/subjectProgress.ts
//      (`EligibleChallengeChapter`, `loadEligibleChallengeChapters`,
//       `loadCourseChallengeChapters`)
//
//  `DuelloProgram.subjects` reprend `getTrackSubjects` ; le filtre « maths
//  hors informatique » reprend `getChallengeTrackSubjects` (tracks.ts:2010).
//
//  Écart V1 assumé (U07 partB#1, réponse du lot) : le stockage iOS des
//  flashcards de cours n'est pas encore adossé à
//  `prepapp-course-flashcards:v1:<id>` ; le volet Défi-Cours lit donc les
//  documents validés par `CollFlashcards.parse` sous cette clé, et liste tout
//  le programme à défaut (aucun document stocké = volet vide, jamais le
//  programme entier sous ce nom).
//
//  Cible : iOS 16, aucune API iOS 17.
//
import Foundation

/// Chapitres éligibles aux volets de défi (`subjectProgress.ts`).
enum SocChallengeChapters {
    /// Programme entier de l'année : l'élève de 2e année couvre les deux
    /// années, ses chapitres de l'année en cours d'abord
    /// (`loadEligibleChallengeChapters`).
    static func eligible(
        track: String,
        specialty: String,
        year: String
    ) -> [SocChallengeChapter] {
        chapters(track: track, specialty: specialty, year: year) { _ in true }
    }

    /// Chapitres du Défi-Cours : seuls ceux où le compte a des flashcards
    /// générées ou créées (`loadCourseChallengeChapters`). Les documents sont
    /// relus sous la clé Expo (`prepapp-course-flashcards:v1:<id>`) et validés
    /// par `CollFlashcards.parse`, comme la source (`parseCourseFlashcards`).
    static func course(
        track: String,
        specialty: String,
        year: String
    ) -> [SocChallengeChapter] {
        chapters(track: track, specialty: specialty, year: year) { chapter in
            let key = "prepapp-course-flashcards:v1:\(chapter.id)"
            let raw = UserDefaults.standard.string(forKey: key)
            return CollFlashcards.parse(raw) != nil
        }
    }

    /// Année de programme (`toProgramYear` de `data/tracks.ts`) : seule la
    /// 1re année vaut 1, tout le reste vaut 2.
    private static func programYear(_ year: String) -> Int {
        year == "1re année" ? 1 : 2
    }

    /// Construit les chapitres d'une matière de défi, filtrés par `keep`.
    private static func chapters(
        track: String,
        specialty: String,
        year: String,
        keep: (SocChallengeChapter) -> Bool
    ) -> [SocChallengeChapter] {
        let current = programYear(year)
        let years = current == 2 ? [2, 1] : [1]
        var result: [SocChallengeChapter] = []
        for year in years {
            let program = DuelloProgram.subjects(
                track: track,
                specialty: specialty,
                year: String(year)
            )
            // `getChallengeTrackSubjects` : les défis n'existent qu'en maths,
            // et les chapitres d'informatique sont écartés.
            for subject in program where subject.id == SocChallengeProgram.mathsId {
                for chapter in subject.chapters where !SocChallengeProgram.isInformatique(chapter) {
                    let eligible = SocChallengeChapter(
                        key: "\(year):\(subject.id):\(chapter.id)",
                        id: chapter.id,
                        name: chapter.name,
                        year: year
                    )
                    if keep(eligible) { result.append(eligible) }
                }
            }
        }
        return result
    }
}
