//
//  OfflContentStartup+Profiles.swift
//  Duello
//
//  Variantes « profil » de l'ordre des banques servies
//  (`src/content/contentStartup.ts` : `profileExerciseContentBundleIds`,
//  `allExerciseStatementContentBundleIds`, `profileTrainingContentBundleIds`,
//  `profileContentBundleIds`, `contentDownloadOrder`).
//
//  Fichier séparé pour tenir le budget de fonctions de
//  `OfflContentStartup.swift` (ratchet ≤ 10 fonctions par fichier).
//
//  Cible : iOS 16.
//
import Foundation

extension OfflContentStartup {

    /// Banques d'exercices de la filière choisie, année courante en premier
    /// (`profileExerciseContentBundleIds`). Le téléchargement silencieux couvre
    /// les deux années : changer d'onglet ne doit pas lancer un second
    /// téléchargement. Les corrigés partagés suivent les banques d'énoncés.
    static func profileExerciseContentBundleIds(
        track: String,
        specialty: String = "",
        year: Int = 1
    ) -> [OfflContentBundleId] {
        let otherYear = year == 2 ? 1 : 2
        let ordered = exerciseContentBundleIds(track: track, specialty: specialty, year: year)
            + exerciseContentBundleIds(track: track, specialty: specialty, year: otherYear)
        let statements = ordered.filter { !isManualOverrideBundle($0) }
        let complements = ordered.filter { isManualOverrideBundle($0) }
        return unique(statements + complements)
    }

    /// Tous les énoncés d'exercices publiés, profil courant en tête
    /// (`allExerciseStatementContentBundleIds`) : le profil accélère l'ordre, il
    /// ne limite pas le corpus.
    static func allExerciseStatementContentBundleIds(
        track: String,
        specialty: String = "",
        year: Int = 1
    ) -> [OfflContentBundleId] {
        let profile = profileExerciseContentBundleIds(
            track: track, specialty: specialty, year: year
        )
        let everyStatement = OfflContentBundleId.all.filter {
            $0.rawValue.hasSuffix("-statements") && !isManualOverrideBundle($0)
        }
        return unique(profile + everyStatement)
    }

    /// Banques d'entraînement à actualiser silencieusement pour le profil
    /// (`profileTrainingContentBundleIds`). Les colles suivent les exercices :
    /// les relire depuis le cache sans jamais les télécharger laissait une
    /// installation neuve sur le seul socle embarqué.
    static func profileTrainingContentBundleIds(
        track: String,
        specialty: String = "",
        year: Int = 1
    ) -> [OfflContentBundleId] {
        let profileIds = profileBundleIds(track: track, specialty: specialty, year: year)
        let exerciseIds = profileExerciseContentBundleIds(
            track: track, specialty: specialty, year: year
        )
        let currentIds = currentTrainingContentBundleIds(
            track: track, specialty: specialty, year: year
        )
        var requested = Set(exerciseIds)
        for id in profileIds where id.rawValue.hasPrefix("colles-") { requested.insert(id) }
        let remaining = profileIds.filter {
            requested.contains($0) && !currentIds.contains($0)
        }
        return currentIds
            + remaining.filter { $0.rawValue.hasPrefix("colles-") }
            + remaining.filter { !$0.rawValue.hasPrefix("colles-") }
            + exerciseIds.filter {
                !profileIds.contains($0) && !currentIds.contains($0)
            }
    }

    /// Toutes les banques utiles au profil : exercices, colles et annales
    /// (`profileContentBundleIds`), compléments d'énoncés compris.
    static func profileContentBundleIds(
        track: String,
        specialty: String = "",
        year: Int = 1
    ) -> [OfflContentBundleId] {
        unique(
            startupContentBundleIds(track: track, specialty: specialty, year: year)
                + profileTrainingContentBundleIds(
                    track: track, specialty: specialty, year: year
                )
                + [.manualExerciseStatementOverrides, .manualExerciseStatementOverrides2]
        )
    }

    /// Ordre de téléchargement complet (`contentDownloadOrder`) : le programme de
    /// l'élève d'abord, puis le cahier des relectures, puis le reste — rien n'est
    /// retiré, une banque non classée arrive simplement derrière.
    static func contentDownloadOrder(
        track: String,
        specialty: String = "",
        year: Int = 1
    ) -> [OfflContentBundleId] {
        let priority = profileBundleIds(track: track, specialty: specialty, year: year)
            + [.manualExerciseStatementOverrides, .manualExerciseStatementOverrides2]
        let seen = Set(priority)
        return priority + OfflContentBundleId.all.filter { !seen.contains($0) }
    }

    /// Déduplication stable (`[...new Set(...)]` de la source).
    private static func unique(_ ids: [OfflContentBundleId]) -> [OfflContentBundleId] {
        var seen = Set<OfflContentBundleId>()
        var result: [OfflContentBundleId] = []
        for id in ids where seen.insert(id).inserted { result.append(id) }
        return result
    }
}
