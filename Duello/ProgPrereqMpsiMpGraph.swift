//
//  ProgPrereqMpsiMpGraph.swift
//  Duello
//
//  Phase 0 (socle) — port de src/data/mpsiMpPrerequisiteGraph.ts (RN) : graphe
//  des prérequis du programme MPSI/MP et ventilation par question qui s'en
//  déduit.
//
//  Les deux tables de dépendances vivent ici plutôt que dans
//  `ProgPrereqMpsi.swift` / `ProgPrereqMp.swift` parce que la ventilation d'une
//  question de deuxième année a besoin du graphe complet : un chapitre de MP
//  dépend de chapitres de MPSI, qui dépendent à leur tour les uns des autres.
//  Sans la fermeture transitive des deux années, on ajouterait à une question des
//  chapitres que le programme exige déjà, ce qui ne distinguerait rien.
//
//  Réutilise sans les redéfinir : `SubjChapterPrerequisite`,
//  `SubjRequiredCourseStatus` (SubjChapterPrerequisites.swift) et
//  `SubjProgramYear` (SubjFlashcardSelection.swift).
//
//  Découpage (24/09/2026) : la table `CHAPTER_TOPICS` (57 entrées) est dans
//  `ProgPrereqMpsiMpGraph+Topics.swift` (même enum) pour respecter le ratchet
//  Hermes (≤ 500 lignes/fichier).
//
//  Notes :
//  - `MPSI_MP_TOPIC_CHAPTER_KEYS` est dérivé de `CHAPTER_TOPICS` : `topicChapterKeys`
//    le recalcule, il n'est jamais figé.
//  - La source met en cache la fermeture transitive (`upstreamCache`) ; le port
//    recalcule (aucun cache partagé), comme `SubjChapterPrerequisites`.
//
//  Cible : iOS 16, aucune dépendance externe.
//
import Foundation

// MARK: - Dépendance élémentaire

/// `MpsiMpDependency` : une dépendance datée (année, statut minimal, raison).
struct MpsiMpDependency: Equatable {
    var year: SubjProgramYear
    var chapterId: String
    var requiredStatus: SubjRequiredCourseStatus
    var reason: String
}

// MARK: - Graphe MPSI / MP

/// `mpsiMpPrerequisiteGraph.ts` : graphe des prérequis MPSI+MP, fermeture
/// transitive et ventilation sémantique par question.
enum ProgPrereqMpsiMpGraph {

    /// Une notion qu'un chapitre laisse reconnaître dans l'énoncé d'une question.
    struct Topic {
        var year: SubjProgramYear
        var chapterId: String
        var name: String
        /// Motif regex, testé avec `.regularExpression` + `.caseInsensitive`
        /// (le drapeau `/…/i` de la source).
        var question: String
    }

    // MARK: - Dépendances internes au programme de première année

    /// `MPSI_CHAPTER_DEPENDENCIES`.
    static let mpsiDependencies: [String: [String]] = [
        "ensembles": ["logique"],
        "sommes-produits": ["logique"],
        "equations-differentielles": ["calcul-derivation"],
        "reels": ["logique"],
        "suites": ["reels", "fonctions-usuelles"],
        "limites-continuite": ["reels", "fonctions-usuelles"],
        "derivabilite": ["limites-continuite", "calcul-derivation"],
        "analyse-asymptotique": ["derivabilite"],
        "taylor": ["derivabilite"],
        "integration": ["calcul-derivation", "derivabilite"],
        "series-numeriques": ["suites"],
        "arithmetique": ["logique"],
        "structures-algebriques": ["ensembles", "arithmetique"],
        "polynomes": ["sommes-produits"],
        "fractions-rationnelles": ["polynomes"],
        "espaces-vectoriels": ["ensembles", "structures-algebriques"],
        "dimension": ["espaces-vectoriels"],
        "applications-lineaires": ["espaces-vectoriels", "dimension"],
        "systemes-lineaires": ["matrices"],
        "determinants": ["matrices", "dimension"],
        "prehilbertiens": ["dimension", "applications-lineaires"],
        "geometrie": ["prehilbertiens"],
        "denombrement": ["ensembles", "sommes-produits"],
        "probabilites": ["denombrement"],
        "variables-aleatoires": ["probabilites", "sommes-produits"],
        "fonctions-deux-variables": ["limites-continuite", "derivabilite"],
    ]

    // MARK: - Fabriques de dépendance

    /// `firstYearDependency`.
    static func firstYearDependency(_ chapterId: String) -> MpsiMpDependency {
        MpsiMpDependency(
            year: .first,
            chapterId: chapterId,
            requiredStatus: .completed,
            reason: "Notion de première année nécessaire à la résolution."
        )
    }

    /// `secondYearDependency`.
    static func secondYearDependency(_ chapterId: String) -> MpsiMpDependency {
        MpsiMpDependency(
            year: .second,
            chapterId: chapterId,
            requiredStatus: .completed,
            reason: "Chapitre antérieur de deuxième année nécessaire à la résolution."
        )
    }

    // MARK: - Dépendances des chapitres de deuxième année

    /// `MP_CHAPTER_DEPENDENCIES` : dépendances des chapitres de deuxième année,
    /// sur les deux années.
    static let mpDependencies: [String: [MpsiMpDependency]] = [
        "convexite": [firstYearDependency("derivabilite")],
        "espaces-normes": [
            firstYearDependency("dimension"),
            firstYearDependency("prehilbertiens"),
        ],
        "topologie": [secondYearDependency("espaces-normes")],
        "series-numeriques": [firstYearDependency("series-numeriques")],
        "familles-sommables": [
            secondYearDependency("series-numeriques"),
            firstYearDependency("denombrement"),
        ],
        "suites-series-fonctions": [
            secondYearDependency("topologie"),
            secondYearDependency("series-numeriques"),
        ],
        "series-entieres": [secondYearDependency("series-numeriques")],
        "integration-intervalle": [
            firstYearDependency("integration"),
            secondYearDependency("series-numeriques"),
        ],
        "convergence-dominee": [
            secondYearDependency("integration-intervalle"),
            secondYearDependency("suites-series-fonctions"),
        ],
        "fonctions-vectorielles": [
            firstYearDependency("derivabilite"),
            firstYearDependency("integration"),
        ],
        "systemes-differentiels": [
            firstYearDependency("equations-differentielles"),
            secondYearDependency("valeurs-propres"),
        ],
        "calcul-differentiel": [
            secondYearDependency("espaces-normes"),
            firstYearDependency("fonctions-deux-variables"),
        ],
        "extrema": [secondYearDependency("calcul-differentiel")],
        "structures-arithmetique": [
            firstYearDependency("arithmetique"),
            firstYearDependency("structures-algebriques"),
        ],
        "algebre-lineaire": [
            firstYearDependency("dimension"),
            firstYearDependency("applications-lineaires"),
        ],
        "matrices-determinants": [
            firstYearDependency("matrices"),
            firstYearDependency("determinants"),
        ],
        "valeurs-propres": [
            firstYearDependency("applications-lineaires"),
            firstYearDependency("polynomes"),
        ],
        "diagonalisation": [secondYearDependency("valeurs-propres")],
        "cayley-hamilton": [
            secondYearDependency("diagonalisation"),
            firstYearDependency("polynomes"),
        ],
        "prehilbertiens": [firstYearDependency("prehilbertiens")],
        "euclidiens": [
            secondYearDependency("prehilbertiens"),
            secondYearDependency("diagonalisation"),
        ],
        "isometries": [secondYearDependency("euclidiens")],
        "denombrabilite": [firstYearDependency("ensembles")],
        "espaces-probabilises": [
            secondYearDependency("denombrabilite"),
            firstYearDependency("probabilites"),
        ],
        "variables-discretes": [
            secondYearDependency("espaces-probabilises"),
            secondYearDependency("familles-sommables"),
        ],
        "couples-independance": [secondYearDependency("variables-discretes")],
        "fonctions-generatrices": [
            secondYearDependency("variables-discretes"),
            secondYearDependency("series-entieres"),
        ],
        "concentration": [secondYearDependency("couples-independance")],
    ]

    // MARK: - Fermeture transitive

    /// Clé canonique d'un chapitre, toutes années confondues.
    private static func chapterKey(year: SubjProgramYear, chapterId: String) -> String {
        "\(year.rawValue):\(chapterId)"
    }

    /// `directDependencies` : arêtes sortantes directes d'un chapitre.
    private static func directDependencies(
        year: SubjProgramYear,
        chapterId: String
    ) -> [MpsiMpDependency] {
        if year == .first {
            return (mpsiDependencies[chapterId] ?? []).map { firstYearDependency($0) }
        }
        return mpDependencies[chapterId] ?? []
    }

    /// `chapterUpstream` : fermeture transitive des chapitres qu'un chapitre
    /// exige déjà, sur les deux années. Un chapitre qui s'y trouve n'apporte
    /// aucune distinction entre les questions d'un même exercice : le badge le
    /// déplie de toute façon.
    static func chapterUpstream(year: SubjProgramYear, chapterId: String) -> Set<String> {
        var upstream = Set<String>()
        var pending = directDependencies(year: year, chapterId: chapterId)
        while let parent = pending.popLast() {
            let parentKey = chapterKey(year: parent.year, chapterId: parent.chapterId)
            if upstream.contains(parentKey) { continue }
            upstream.insert(parentKey)
            pending.append(
                contentsOf: directDependencies(year: parent.year, chapterId: parent.chapterId)
            )
        }
        return upstream
    }

    /// `uniqueChapterPrerequisites` : une exigence par chapitre, la plus forte
    /// gagnant — un chapitre demandé « en cours » par le porteur et « acquis »
    /// par une question reste « acquis ». L'ordre d'insertion est conservé.
    static func uniqueChapterPrerequisites(
        _ prerequisites: [SubjChapterPrerequisite]
    ) -> [SubjChapterPrerequisite] {
        var order: [String] = []
        var byChapter: [String: SubjChapterPrerequisite] = [:]
        for prerequisite in prerequisites {
            let key = chapterKey(year: prerequisite.year, chapterId: prerequisite.chapterId)
            guard let existing = byChapter[key] else {
                order.append(key)
                byChapter[key] = prerequisite
                continue
            }
            if existing.requiredStatus == .inProgress,
               prerequisite.requiredStatus == .completed {
                byChapter[key] = prerequisite
            }
        }
        return order.compactMap { byChapter[$0] }
    }

    // MARK: - Ventilation sémantique par question

    /// `MPSI_MP_TOPIC_CHAPTER_KEYS` : chapitres cités par la table des notions,
    /// dérivé de `topics` (jamais figé).
    static var topicChapterKeys: [String] {
        topics.map { chapterKey(year: $0.year, chapterId: $0.chapterId) }
    }

    /// Test d'un motif de notion (drapeau `/…/i` de la source).
    private static func matches(_ pattern: String, _ text: String) -> Bool {
        text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }

    /// `semanticQuestionPrerequisites` : connaissances supplémentaires qu'une
    /// question mobilise, au-delà du chapitre qui porte l'exercice.
    ///
    /// Trois garde-fous : jamais un chapitre de l'année suivante, un chapitre
    /// déjà exigé transitivement est ignoré, le motif désigne la notion.
    static func semanticQuestionPrerequisites(
        year: SubjProgramYear,
        chapterId: String,
        questionText: String
    ) -> [SubjChapterPrerequisite] {
        if questionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return [] }
        let upstream = chapterUpstream(year: year, chapterId: chapterId)

        var extras: [SubjChapterPrerequisite] = []
        for topic in topics {
            if topic.year.rawValue > year.rawValue { continue }
            let key = chapterKey(year: topic.year, chapterId: topic.chapterId)
            if topic.year == year && topic.chapterId == chapterId { continue }
            if upstream.contains(key) { continue }
            if !matches(topic.question, questionText) { continue }
            extras.append(
                SubjChapterPrerequisite(
                    year: topic.year,
                    chapterId: topic.chapterId,
                    requiredStatus: .completed,
                    reason: "La question mobilise « \(topic.name) », au-delà du chapitre courant."
                )
            )
        }
        return extras
    }
}
