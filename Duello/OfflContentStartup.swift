//
//  OfflContentStartup.swift
//  Duello
//
//  Ordre dans lequel les banques servies sont lues puis téléchargées.
//
//  Fichier source Expo porté : `src/content/contentStartup.ts` (fonctions
//  `priorityChapterIds`, `startupContentBundleIds`, `exerciseContentBundleIds`,
//  `primaryExerciseContentBundleId`, `currentTrainingContentBundleIds`,
//  `annaleContentBundleIds`). Les variantes de profil
//  (`profileExerciseContentBundleIds`, `profileTrainingContentBundleIds`,
//  `profileContentBundleIds`, `allExerciseStatementContentBundleIds`,
//  `contentDownloadOrder`) vivent dans `OfflContentStartup+Profiles.swift`
//  (ratchet ≤ 10 fonctions par fichier).
//
//  Le manifeste compte vingt-cinq banques alors qu'un élève n'en utilise qu'une
//  poignée (3,7 Mo en MPSI, 6,1 en ECG approfondies) : prendre l'ordre du
//  manifeste ferait attendre son propre programme derrière des filières qu'il
//  n'ouvrira jamais. L'ordre des banques du profil vient de `TrainContent`
//  (même port de `contentStartup.ts`), ce fichier n'en fait que la composition.
//
//  Cible : iOS 16, aucune dépendance externe.
//
import Foundation

/// Ordre des banques servies au démarrage (`contentStartup.ts`).
enum OfflContentStartup {

    /// Deux chapitres choisis dans l'ordre métier demandé au démarrage
    /// (`priorityChapterIds`) : deux chapitres en cours, sinon un en cours et le
    /// dernier terminé, sinon les deux derniers terminés, sinon les deux
    /// premiers de la matière.
    static func priorityChapterIds(
        orderedChapterIds: [String],
        storedSubjects: Any?
    ) -> [String] {
        let statuses = chapterStatuses(storedSubjects)
        let inProgress = orderedChapterIds.filter { statuses[$0] == "in-progress" }
        if inProgress.count >= 2 { return Array(inProgress.prefix(2)) }
        let completed = orderedChapterIds.filter { statuses[$0] == "completed" }
        if inProgress.count == 1, let last = completed.last {
            return [inProgress[0], last]
        }
        if inProgress.isEmpty, completed.count >= 2 {
            return Array(completed.suffix(2).reversed())
        }
        return Array(orderedChapterIds.prefix(2))
    }

    /// Banques utiles au profil courant, ordonnées sans relire les autres au
    /// démarrage (`startupContentBundleIds`).
    static func startupContentBundleIds(
        track: String,
        specialty: String = "",
        year: Int = 1
    ) -> [OfflContentBundleId] {
        profileBundleIds(track: track, specialty: specialty, year: year)
    }

    /// Banques nécessaires aux exercices de l'année affichée
    /// (`exerciseContentBundleIds`). Le portage de la source vit dans
    /// `TrainContent.exerciseBundleIds` ; ici la banque principale est la
    /// première de la liste.
    static func exerciseContentBundleIds(
        track: String,
        specialty: String = "",
        year: Int = 1
    ) -> [OfflContentBundleId] {
        bundleIds(TrainContent.exerciseBundleIds(track: track, specialty: specialty, year: year))
    }

    /// Banque qui porte les énoncés de l'année affichée
    /// (`primaryExerciseContentBundleId`), ou `nil` hors filière servie.
    static func primaryExerciseContentBundleId(
        track: String,
        specialty: String = "",
        year: Int = 1
    ) -> OfflContentBundleId? {
        exerciseContentBundleIds(track: track, specialty: specialty, year: year).first
    }

    /// Énoncés d'exercices puis colles de l'année affichée
    /// (`currentTrainingContentBundleIds`).
    static func currentTrainingContentBundleIds(
        track: String,
        specialty: String = "",
        year: Int = 1
    ) -> [OfflContentBundleId] {
        let colles = profileBundleIds(track: track, specialty: specialty, year: year)
            .filter { $0.rawValue.hasPrefix("colles-") && $0.rawValue.hasSuffix("-\(year)") }
        return exerciseContentBundleIds(track: track, specialty: specialty, year: year) + colles
    }

    /// Banques d'annales du profil, année affichée en tête
    /// (`annaleContentBundleIds`).
    static func annaleContentBundleIds(
        track: String,
        specialty: String = "",
        year: Int = 1
    ) -> [OfflContentBundleId] {
        profileBundleIds(track: track, specialty: specialty, year: year).filter {
            !$0.rawValue.hasSuffix("-statements") && !$0.rawValue.hasPrefix("colles-")
        }
    }

    /// Banques du programme de l'élève (`profileBundleIds`) : le lycée n'a pas
    /// de banque servie, l'ECG reçoit en plus le corpus oral.
    static func profileBundleIds(
        track: String,
        specialty: String,
        year: Int
    ) -> [OfflContentBundleId] {
        bundleIds(TrainContent.profileBundleIds(track: track, specialty: specialty, year: year))
    }

    /// `manual-exercise-statement-overrides` et sa suite : les compléments
    /// d'énoncés servis séparément, à classer derrière les énoncés principaux.
    static func isManualOverrideBundle(_ id: OfflContentBundleId) -> Bool {
        id == .manualExerciseStatementOverrides || id == .manualExerciseStatementOverrides2
    }

    /// Convertit les identifiants bruts du portage d'ordre en banques typées.
    static func bundleIds(_ raw: [String]) -> [OfflContentBundleId] {
        raw.compactMap { OfflContentBundleId(rawValue: $0) }
    }

    /// Statuts de cours lus dans la progression du compte (`storedSubjects`) :
    /// seuls les identifiants de chapitre portant un statut connu entrent.
    private static func chapterStatuses(_ storedSubjects: Any?) -> [String: String] {
        let known: Set<String> = ["not-started", "in-progress", "completed"]
        guard let subjects = storedSubjects as? [Any] else { return [:] }
        var statuses: [String: String] = [:]
        for subject in subjects {
            guard let subject = subject as? [String: Any],
                  let chapters = subject["chapters"] as? [Any] else { continue }
            for chapter in chapters {
                guard let chapter = chapter as? [String: Any],
                      let id = chapter["id"] as? String,
                      let status = chapter["courseStatus"] as? String,
                      known.contains(status) else { continue }
                statuses[id] = status
            }
        }
        return statuses
    }
}
