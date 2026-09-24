//
//  ProgPrereqEcgProgram.swift
//  Duello
//
//  Phase 1a — port de src/data/ecgMathsProgram.ts (RN) : découpage pédagogique
//  des deux parcours de mathématiques en ECG (appliquées et approfondies), avec
//  les prérequis de chapitre déclarés par `req(year, …)`.
//
//  ⚠️ Ne remplace pas `ProgramECG.swift` (catalogues d'affichage, sans
//  prérequis) : `TrackChapter` (Models.swift) ne porte pas `prerequisites`.
//  Ce module est la source de données brute dont la revue de prérequis ECG
//  approfondies (`ProgPrereqEcgAdvanced`) a besoin pour calculer la fermeture
//  transitive de son programme (`advancedChapterIndex`).
//
//  Fidélité : identifiants, noms, domaines, ordre et prérequis recopiés à
//  l'identique de la source. `req` produit des `SubjChapterPrerequisite` sans
//  `requiredStatus` ni `reason` (la source ne renseigne que `year`/`chapterId`).
//
//  Cible : iOS 16, aucune dépendance externe.
//
import Foundation

/// Domaine d'un chapitre ECG (`ChapterDomain` de tracks.ts, sous-ensemble ECG).
enum ProgEcgChapterDomain: String {
    case fondements
    case analyse
    case algebre
    case probabilites
    case informatique
}

/// Chapitre de programme ECG (`TrackChapter`), prérequis inclus.
struct ProgEcgChapter: Equatable {
    var id: String
    var name: String
    var domain: ProgEcgChapterDomain?
    var prerequisites: [SubjChapterPrerequisite]
}

/// `ecgMathsProgram.ts` : programmes ECG appliquées/approfondies par année.
enum ProgPrereqEcgProgram {

    /// `MathsOption`.
    enum MathsOption: String {
        case appliquees
        case approfondies
    }

    // MARK: - Fabriques (helpers de la source)

    /// `req(year, …)` : prérequis d'année, sans statut ni raison.
    private static func req(_ year: SubjProgramYear, _ chapterIds: String...) -> [SubjChapterPrerequisite] {
        chapterIds.map {
            SubjChapterPrerequisite(year: year, chapterId: $0, requiredStatus: nil, reason: nil)
        }
    }

    /// `domain(value, chapters)` : rattache un bloc à un domaine.
    private static func domain(_ value: ProgEcgChapterDomain, _ chapters: [ProgEcgChapter]) -> [ProgEcgChapter] {
        chapters.map { chapter in
            var chapter = chapter
            chapter.domain = value
            return chapter
        }
    }

    /// Chapitre sans domaine (le domaine vient de `domain(…)`).
    private static func chapter(_ id: String, _ name: String, _ prerequisites: [SubjChapterPrerequisite] = []) -> ProgEcgChapter {
        ProgEcgChapter(id: id, name: name, domain: nil, prerequisites: prerequisites)
    }

    // MARK: - Informatique appliquées

    /// `APPLIQUEES_INFORMATIQUE_1`.
    private static let appliqueesInformatique1: [ProgEcgChapter] = domain(.informatique, [
        chapter("python-appliquees-1-algorithmique-listes", "Algorithmique des listes"),
        chapter("python-appliquees-1-statistiques-donnees", "Statistiques descriptives et analyse de données"),
        chapter("python-appliquees-1-approximation-numerique", "Approximation numérique"),
        chapter("python-appliquees-1-graphes", "Graphes finis et plus courts chemins"),
        chapter("python-appliquees-1-simulation", "Simulation de phénomènes aléatoires"),
    ])

    /// `APPLIQUEES_INFORMATIQUE_2`.
    private static let appliqueesInformatique2: [ProgEcgChapter] = domain(.informatique, [
        chapter("python-appliquees-2-boucles-sommes", "Boucles, suites et sommes"),
        chapter("python-appliquees-2-simulation-discrete", "Simulation de variables aléatoires discrètes"),
        chapter("python-appliquees-2-simulation-couples", "Simulation de couples de variables aléatoires"),
        chapter("python-appliquees-2-calcul-matriciel", "Calcul matriciel et réduction"),
        chapter("python-appliquees-2-dichotomie", "Approximation numérique et dichotomie"),
        chapter("python-appliquees-2-bases-donnees", "Bases de données"),
        chapter("python-appliquees-2-systemes-differentiels", "Équations et systèmes différentiels"),
        chapter("python-appliquees-2-statistiques-bivariees", "Statistiques descriptives bivariées"),
        chapter("python-appliquees-2-chaines-markov", "Chaînes de Markov"),
        chapter("python-appliquees-2-estimation", "Estimation ponctuelle ou par intervalle de confiance"),
    ])

    // MARK: - Informatique approfondies

    /// `APPROFONDIES_INFORMATIQUE_1`.
    private static let approfondiesInformatique1: [ProgEcgChapter] = domain(.informatique, [
        chapter("python-approfondies-1-introduction", "Introduction à Python"),
        chapter("python-approfondies-1-conditions", "Instructions conditionnelles"),
        chapter("python-approfondies-1-boucles", "Boucles"),
        chapter("python-approfondies-1-fonctions", "Fonctions"),
        chapter("python-approfondies-1-matrices", "Matrices"),
        chapter("python-approfondies-1-graphiques", "Graphiques"),
        chapter("python-approfondies-1-probabilites", "Probabilités"),
    ])

    /// `APPROFONDIES_INFORMATIQUE_2`.
    private static let approfondiesInformatique2: [ProgEcgChapter] = domain(.informatique, [
        chapter("python-approfondies-2-simulation-va", "Simulation de VA"),
        chapter("python-approfondies-2-suites-series", "Suites & Séries"),
        chapter("python-approfondies-2-methodes-inversion", "Méthodes d’inversion"),
        chapter("python-approfondies-2-va-densite", "VA à densité"),
        chapter("python-approfondies-2-fonctions-2-variables", "Fonctions de 2 variables"),
        chapter("python-approfondies-2-monte-carlo", "Méthode de Monte Carlo"),
        chapter("python-approfondies-2-statistiques", "Statistiques univariées et bivariées"),
    ])

    // MARK: - Mathématiques approfondies

    /// `APPROFONDIES_1` : 1re année.
    private static let approfondies1: [ProgEcgChapter] =
        domain(.fondements, [
            chapter("raisonnement", "Raisonnements & calculs"),
            chapter("ensembles-applications", "Ensembles & applications", req(.first, "raisonnement")),
        ])
        + domain(.analyse, [
            chapter("suites", "Suites réelles", req(.first, "raisonnement")),
            chapter("limites-continuite", "Limite & continuité en un point", req(.first, "ensembles-applications")),
            chapter("fonctions-usuelles", "Étude globale des fonctions", req(.first, "limites-continuite")),
            chapter("derivation", "Dérivation", req(.first, "limites-continuite")),
            chapter("integration", "Intégration sur un segment", req(.first, "derivation")),
            chapter("analyse-asymptotique", "Équivalence & négligeabilité", req(.first, "suites", "limites-continuite")),
            chapter("series", "Séries numériques", req(.first, "analyse-asymptotique")),
            chapter("integrales-impropres", "Intégrales sur un intervalle", req(.first, "integration", "analyse-asymptotique")),
            chapter("derivation-successive", "Dérivation successive", req(.first, "derivation")),
            chapter("taylor-developpements-limites", "Étude locale des fonctions", req(.first, "derivation-successive", "analyse-asymptotique")),
        ])
        + domain(.algebre, [
            chapter("matrices", "Calcul matriciel"),
            chapter("systemes-lineaires", "Systèmes linéaires", req(.first, "matrices")),
            chapter("polynomes", "Fonctions polynômes"),
            chapter("espaces-vectoriels", "Espaces vectoriels", req(.first, "raisonnement")),
            chapter("applications-lineaires", "Applications linéaires", req(.first, "espaces-vectoriels")),
            chapter("matrices-applications-lineaires", "Matrices & applications linéaires", req(.first, "applications-lineaires", "matrices")),
        ])
        + domain(.probabilites, [
            chapter("espaces-probabilises-finis", "Probabilités sur un univers fini", req(.first, "raisonnement")),
            chapter("espaces-probabilises", "Espace probabilisé", req(.first, "espaces-probabilises-finis")),
            chapter("variables-discretes", "VAR discrètes", req(.first, "series", "espaces-probabilises")),
            chapter("couples-discrets", "Couple de VAR discrètes", req(.first, "variables-discretes")),
        ])
        + approfondiesInformatique1

    /// `APPROFONDIES_2` : 2e année.
    private static let approfondies2: [ProgEcgChapter] =
        domain(.fondements, [
            chapter("analyse-concours", "Révisions de 1re année", req(.first, "analyse-asymptotique", "series", "integrales-impropres", "taylor-developpements-limites")),
        ])
        + domain(.analyse, [
            chapter("familles-sommables", "Séries", req(.first, "series")),
            chapter("integration-annee-2", "Intégration", req(.first, "integration", "integrales-impropres")),
            chapter("fonctions-plusieurs-variables", "Fonctions à plusieurs variables", req(.first, "derivation", "espaces-vectoriels")),
            chapter("calcul-differentiel", "Calcul différentiel", req(.second, "fonctions-plusieurs-variables")),
        ])
        + domain(.algebre, [
            chapter("algebre-complements", "Algèbre linéaire", req(.first, "espaces-vectoriels")),
            chapter("changement-base-trace", "Applications linéaires", req(.first, "matrices-applications-lineaires")),
            chapter("valeurs-propres", "Éléments propres", req(.first, "polynomes") + req(.second, "changement-base-trace")),
            chapter("diagonalisation", "Diagonalisation", req(.second, "algebre-complements", "valeurs-propres")),
            chapter("algebre-bilineaire", "Espaces euclidiens", req(.first, "espaces-vectoriels")),
            chapter("endomorphismes-symetriques", "Endomorphismes symétriques", req(.second, "diagonalisation", "algebre-bilineaire")),
        ])
        + domain(.probabilites, [
            chapter("complements-variables-aleatoires", "Probabilités discrètes", req(.first, "variables-discretes", "espaces-probabilises-finis")),
            chapter("variables-densite", "Variables à densité", req(.first, "integrales-impropres") + req(.second, "complements-variables-aleatoires")),
            chapter("couples-vecteurs", "Vecteurs aléatoires", req(.first, "couples-discrets") + req(.second, "variables-densite")),
            chapter("convergences", "Convergence de VA", req(.second, "couples-vecteurs")),
            chapter("estimation-ponctuelle", "Estimation", req(.second, "convergences")),
        ])
        + approfondiesInformatique2

    // MARK: - Mathématiques appliquées

    /// `APPLIQUEES_1` : 1re année.
    private static let appliquees1: [ProgEcgChapter] =
        domain(.fondements, [
            chapter("appliquees-1-logique", "Rudiments de logique"),
            chapter("appliquees-1-nombres-reels", "Nombres réels", req(.first, "appliquees-1-logique")),
            chapter("appliquees-1-sommes-produits", "Sommes et produits", req(.first, "appliquees-1-logique")),
            chapter("appliquees-1-applications", "Applications", req(.first, "appliquees-1-logique")),
            chapter("appliquees-1-ensembles-denombrement", "Ensembles et dénombrement", req(.first, "appliquees-1-logique")),
            chapter("appliquees-1-graphes", "Graphes", req(.first, "appliquees-1-ensembles-denombrement")),
        ])
        + domain(.analyse, [
            chapter("appliquees-1-generalites-fonctions", "Généralités sur les fonctions", req(.first, "appliquees-1-nombres-reels")),
            chapter("appliquees-1-generalites-suites", "Généralités sur les suites", req(.first, "appliquees-1-nombres-reels")),
            chapter("appliquees-1-convergence-suites", "Convergence des suites", req(.first, "appliquees-1-generalites-suites")),
            chapter("appliquees-1-limites-fonctions", "Limites de fonctions", req(.first, "appliquees-1-generalites-fonctions")),
            chapter("appliquees-1-continuite", "Continuité", req(.first, "appliquees-1-limites-fonctions")),
            chapter("appliquees-1-derivabilite", "Dérivabilité", req(.first, "appliquees-1-continuite")),
            chapter("appliquees-1-series-numeriques", "Séries numériques", req(.first, "appliquees-1-convergence-suites")),
            chapter("appliquees-1-integration-segment", "Intégration sur un segment", req(.first, "appliquees-1-derivabilite")),
            chapter("appliquees-1-convexite", "Convexité", req(.first, "appliquees-1-derivabilite")),
            chapter("appliquees-1-equations-differentielles", "Équations différentielles linéaires", req(.first, "appliquees-1-derivabilite")),
        ])
        + domain(.algebre, [
            chapter("appliquees-1-systemes-lineaires", "Systèmes linéaires", req(.first, "appliquees-1-logique")),
            chapter("appliquees-1-fonctions-polynomiales", "Fonctions polynomiales"),
            chapter("appliquees-1-matrices", "Matrices", req(.first, "appliquees-1-systemes-lineaires")),
            chapter("appliquees-1-espaces-vectoriels", "Espaces vectoriels réels", req(.first, "appliquees-1-systemes-lineaires")),
            chapter("appliquees-1-applications-lineaires", "Applications linéaires", req(.first, "appliquees-1-espaces-vectoriels", "appliquees-1-matrices")),
        ])
        + domain(.probabilites, [
            chapter("appliquees-1-statistiques", "Statistiques"),
            chapter("appliquees-1-probabilites-finies", "Probabilités sur un univers fini", req(.first, "appliquees-1-ensembles-denombrement")),
            chapter("appliquees-1-variables-finies", "Variables aléatoires finies", req(.first, "appliquees-1-probabilites-finies")),
            chapter("appliquees-1-probabilites-infinies", "Probabilités sur un univers infini", req(.first, "appliquees-1-series-numeriques")),
            chapter("appliquees-1-variables-discretes", "Variables aléatoires discrètes", req(.first, "appliquees-1-probabilites-infinies")),
        ])
        + appliqueesInformatique1

    /// `APPLIQUEES_2` : 2e année.
    private static let appliquees2: [ProgEcgChapter] =
        domain(.analyse, [
            chapter("appliquees-2-fonctions", "Études et comparaisons de fonctions", req(.first, "appliquees-1-limites-fonctions", "appliquees-1-derivabilite")),
            chapter("appliquees-2-suites", "Suites", req(.first, "appliquees-1-convergence-suites")),
            chapter("appliquees-2-series", "Séries", req(.first, "appliquees-1-series-numeriques")),
            chapter("appliquees-2-developpements-limites", "Développements limités", req(.second, "appliquees-2-fonctions")),
            chapter("appliquees-2-integration", "Intégration", req(.first, "appliquees-1-integration-segment")),
            chapter("appliquees-2-systemes-differentiels", "Systèmes différentiels linéaires", req(.first, "appliquees-1-equations-differentielles") + req(.second, "appliquees-2-reduction-matrices")),
            chapter("appliquees-2-fonctions-deux-variables", "Fonctions de deux variables", req(.second, "appliquees-2-fonctions")),
        ])
        + domain(.algebre, [
            chapter("appliquees-2-espaces-vectoriels", "Espaces vectoriels", req(.first, "appliquees-1-espaces-vectoriels")),
            chapter("appliquees-2-applications-lineaires", "Applications linéaires", req(.first, "appliquees-1-applications-lineaires")),
            chapter("appliquees-2-reduction-matrices", "Réduction des matrices carrées", req(.second, "appliquees-2-applications-lineaires")),
        ])
        + domain(.probabilites, [
            chapter("appliquees-2-probabilites-generales", "Probabilités générales", req(.first, "appliquees-1-probabilites-infinies")),
            chapter("appliquees-2-variables-generales", "Variables aléatoires générales", req(.second, "appliquees-2-probabilites-generales")),
            chapter("appliquees-2-variables-discretes", "Variables aléatoires discrètes", req(.first, "appliquees-1-variables-discretes")),
            chapter("appliquees-2-couples-discrets", "Couples de variables aléatoires discrètes", req(.second, "appliquees-2-variables-discretes")),
            chapter("appliquees-2-variables-densite", "Variables aléatoires à densité", req(.second, "appliquees-2-integration", "appliquees-2-variables-generales")),
            chapter("appliquees-2-chaines-markov", "Chaînes de Markov", req(.first, "appliquees-1-graphes") + req(.second, "appliquees-2-reduction-matrices")),
            chapter("appliquees-2-convergence-approximation", "Convergence et approximation", req(.second, "appliquees-2-variables-densite", "appliquees-2-couples-discrets")),
            chapter("appliquees-2-estimation", "Estimation", req(.second, "appliquees-2-convergence-approximation")),
        ])
        + appliqueesInformatique2

    // MARK: - Programmes exportés

    /// `ECG_MATHS_PROGRAMS`.
    static let programs: [MathsOption: [SubjProgramYear: [ProgEcgChapter]]] = [
        .appliquees: [.first: appliquees1, .second: appliquees2],
        .approfondies: [.first: approfondies1, .second: approfondies2],
    ]

    /// `ECG_MATHS_PROGRAM` : alias historique, les annales ESCP sont approfondies.
    static let program: [SubjProgramYear: [ProgEcgChapter]] = [
        .first: approfondies1,
        .second: approfondies2,
    ]

    /// `ECG_MATHS_PROGRAMS.approfondies` (accès direct utilisé par la revue).
    static let approfondies: [SubjProgramYear: [ProgEcgChapter]] = [
        .first: approfondies1,
        .second: approfondies2,
    ]

    /// `ECG_MATHS_PROGRAMS.appliquees`.
    static let appliquees: [SubjProgramYear: [ProgEcgChapter]] = [
        .first: appliquees1,
        .second: appliquees2,
    ]
}
