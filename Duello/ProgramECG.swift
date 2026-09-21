// [ProgramECG] Programme ECG : liste des matières, puis chapitres de mathématiques (approfondies et appliquées).
// [ProgramECG] Dérogation : `ecgSubjects` (63 lignes) ne fait que retourner un catalogue statique — exception « données statiques volumineuses » des règles de complexité Duello.
import Foundation

extension DuelloProgram {

    // MARK: ECG

    static func ecgSubjects(isFirstYear: Bool, mathsApplied: Bool) -> [TrackSubject] {
        [
            TrackSubject(
                id: "maths",
                name: "Mathématiques",
                fullName: mathsApplied ? "Mathématiques appliquées" : "Mathématiques approfondies",
                icon: "function",
                chapters: mathsApplied
                    ? (isFirstYear ? MathsAppliquees.annee1 : MathsAppliquees.annee2)
                    : (isFirstYear ? MathsApprofondies.annee1 : MathsApprofondies.annee2)
            ),
            TrackSubject(
                id: "esh",
                name: "ESH",
                fullName: isFirstYear
                    ? "Économie, sociologie et histoire — modules 1 et 2"
                    : "Économie, sociologie et histoire — modules 3 et 4",
                icon: "chart.line.uptrend.xyaxis",
                chapters: isFirstYear ? ESH.annee1 : ESH.annee2
            ),
            TrackSubject(
                id: "hgg",
                name: "HGG",
                fullName: isFirstYear
                    ? "Histoire, géographie et géopolitique — modules 1 et 2"
                    : "Histoire, géographie et géopolitique — modules 3 et 4",
                icon: "globe.europe.africa",
                chapters: isFirstYear ? HGG.annee1 : HGG.annee2
            ),
            TrackSubject(
                id: "lettres",
                name: "Lettres",
                fullName: isFirstYear
                    ? "Culture générale — fondements et méthode"
                    : "Culture générale — thème du concours",
                icon: "book",
                chapters: isFirstYear ? Lettres.annee1 : Lettres.annee2
            ),
            TrackSubject(
                id: "philosophie",
                name: "Philosophie",
                fullName: isFirstYear
                    ? "Culture générale — notions et repères"
                    : "Culture générale — thème du concours",
                icon: "lightbulb",
                chapters: isFirstYear ? Philosophie.annee1 : Philosophie.annee2
            ),
            TrackSubject(
                id: "anglais",
                name: "Anglais",
                fullName: "Langue vivante 1",
                icon: "globe",
                chapters: isFirstYear ? Langues.anglaisAnnee1 : Langues.anglaisAnnee2
            ),
            TrackSubject(
                id: "lv2",
                name: "LV2",
                fullName: "Espagnol, allemand, italien…",
                icon: "bubble.left.and.bubble.right",
                chapters: isFirstYear ? Langues.lv2Annee1 : Langues.lv2Annee2
            ),
        ]
    }

    enum MathsApprofondies {
        static let annee1: [TrackChapter] = [
            chapter("raisonnement", "Raisonnements & calculs", domain: "Fondements"),
            chapter("ensembles-applications", "Ensembles & applications", domain: "Fondements"),
            chapter("suites", "Suites réelles", domain: "Analyse"),
            chapter("limites-continuite", "Limite & continuité en un point", domain: "Analyse"),
            chapter("fonctions-usuelles", "Étude globale des fonctions", domain: "Analyse"),
            chapter("derivation", "Dérivation", domain: "Analyse"),
            chapter("integration", "Intégration sur un segment", domain: "Analyse"),
            chapter("analyse-asymptotique", "Équivalence & négligeabilité", domain: "Analyse"),
            chapter("series", "Séries numériques", domain: "Analyse"),
            chapter("integrales-impropres", "Intégrales sur un intervalle", domain: "Analyse"),
            chapter("derivation-successive", "Dérivation successive", domain: "Analyse"),
            chapter("taylor-developpements-limites", "Étude locale des fonctions", domain: "Analyse"),
            chapter("matrices", "Calcul matriciel", domain: "Algèbre"),
            chapter("systemes-lineaires", "Systèmes linéaires", domain: "Algèbre"),
            chapter("polynomes", "Fonctions polynômes", domain: "Algèbre"),
            chapter("espaces-vectoriels", "Espaces vectoriels", domain: "Algèbre"),
            chapter("applications-lineaires", "Applications linéaires", domain: "Algèbre"),
            chapter("matrices-applications-lineaires", "Matrices & applications linéaires", domain: "Algèbre"),
            chapter("espaces-probabilises-finis", "Probabilités sur un univers fini", domain: "Probabilités"),
            chapter("espaces-probabilises", "Espace probabilisé", domain: "Probabilités"),
            chapter("variables-discretes", "VAR discrètes", domain: "Probabilités"),
            chapter("couples-discrets", "Couple de VAR discrètes", domain: "Probabilités"),
            chapter("python-approfondies-1-introduction", "Introduction à Python", domain: "Informatique"),
            chapter("python-approfondies-1-conditions", "Conditions", domain: "Informatique"),
            chapter("python-approfondies-1-boucles", "Boucles", domain: "Informatique"),
            chapter("python-approfondies-1-fonctions", "Fonctions", domain: "Informatique"),
            chapter("python-approfondies-1-matrices", "Matrices", domain: "Informatique"),
            chapter("python-approfondies-1-graphiques", "Graphiques", domain: "Informatique"),
            chapter("python-approfondies-1-probabilites", "Probabilités", domain: "Informatique"),
        ]

        static let annee2: [TrackChapter] = [
            chapter("analyse-concours", "Révisions de 1re année", domain: "Fondements"),
            chapter("familles-sommables", "Séries", domain: "Analyse"),
            chapter("integration-annee-2", "Intégration", domain: "Analyse"),
            chapter("fonctions-plusieurs-variables", "Fonctions à plusieurs variables", domain: "Analyse"),
            chapter("calcul-differentiel", "Calcul différentiel", domain: "Analyse"),
            chapter("algebre-complements", "Algèbre linéaire", domain: "Algèbre"),
            chapter("changement-base-trace", "Applications linéaires", domain: "Algèbre"),
            chapter("valeurs-propres", "Éléments propres", domain: "Algèbre"),
            chapter("diagonalisation", "Diagonalisation", domain: "Algèbre"),
            chapter("algebre-bilineaire", "Espaces euclidiens", domain: "Algèbre"),
            chapter("endomorphismes-symetriques", "Endomorphismes symétriques", domain: "Algèbre"),
            chapter("complements-variables-aleatoires", "Probabilités discrètes", domain: "Probabilités"),
            chapter("variables-densite", "Variables à densité", domain: "Probabilités"),
            chapter("couples-vecteurs", "Vecteurs aléatoires", domain: "Probabilités"),
            chapter("convergences", "Convergence de VA", domain: "Probabilités"),
            chapter("estimation-ponctuelle", "Estimation", domain: "Probabilités"),
            chapter("python-approfondies-2-simulation-va", "Simulation de VA", domain: "Informatique"),
            chapter("python-approfondies-2-suites-series", "Suites & Séries", domain: "Informatique"),
            chapter("python-approfondies-2-methodes-inversion", "Méthodes d'inversion", domain: "Informatique"),
            chapter("python-approfondies-2-va-densite", "VA à densité", domain: "Informatique"),
            chapter("python-approfondies-2-fonctions-2-variables", "Fonctions de 2 variables", domain: "Informatique"),
            chapter("python-approfondies-2-monte-carlo", "Méthode de Monte-Carlo", domain: "Informatique"),
            chapter("python-approfondies-2-statistiques", "Statistiques", domain: "Informatique"),
        ]
    }

    enum MathsAppliquees {
        static let annee1: [TrackChapter] = [
            chapter("appliquees-1-logique", "Rudiments de logique", domain: "Fondements"),
            chapter("appliquees-1-nombres-reels", "Nombres réels", domain: "Fondements"),
            chapter("appliquees-1-sommes-produits", "Sommes et produits", domain: "Fondements"),
            chapter("appliquees-1-applications", "Applications", domain: "Fondements"),
            chapter("appliquees-1-ensembles-denombrement", "Ensembles et dénombrement", domain: "Fondements"),
            chapter("appliquees-1-graphes", "Graphes", domain: "Fondements"),
            chapter("appliquees-1-generalites-fonctions", "Généralités sur les fonctions", domain: "Analyse"),
            chapter("appliquees-1-generalites-suites", "Généralités sur les suites", domain: "Analyse"),
            chapter("appliquees-1-convergence-suites", "Convergence des suites", domain: "Analyse"),
            chapter("appliquees-1-limites-fonctions", "Limites de fonctions", domain: "Analyse"),
            chapter("appliquees-1-continuite", "Continuité", domain: "Analyse"),
            chapter("appliquees-1-derivabilite", "Dérivabilité", domain: "Analyse"),
            chapter("appliquees-1-series-numeriques", "Séries numériques", domain: "Analyse"),
            chapter("appliquees-1-integration-segment", "Intégration sur un segment", domain: "Analyse"),
            chapter("appliquees-1-convexite", "Convexité", domain: "Analyse"),
            chapter("appliquees-1-equations-differentielles", "Équations différentielles linéaires", domain: "Analyse"),
            chapter("appliquees-1-systemes-lineaires", "Systèmes linéaires", domain: "Algèbre"),
            chapter("appliquees-1-fonctions-polynomiales", "Fonctions polynomiales", domain: "Algèbre"),
            chapter("appliquees-1-matrices", "Matrices", domain: "Algèbre"),
            chapter("appliquees-1-espaces-vectoriels", "Espaces vectoriels réels", domain: "Algèbre"),
            chapter("appliquees-1-applications-lineaires", "Applications linéaires", domain: "Algèbre"),
            chapter("appliquees-1-statistiques", "Statistiques", domain: "Probabilités"),
            chapter("appliquees-1-probabilites-finies", "Probabilités sur un univers fini", domain: "Probabilités"),
            chapter("appliquees-1-variables-finies", "Variables aléatoires finies", domain: "Probabilités"),
            chapter("python-appliquees-1-algorithmique-listes", "Algorithmique et listes", domain: "Informatique"),
            chapter("python-appliquees-1-statistiques-donnees", "Statistiques des données", domain: "Informatique"),
            chapter("python-appliquees-1-approximation-numerique", "Approximation numérique", domain: "Informatique"),
            chapter("python-appliquees-1-graphes", "Graphes", domain: "Informatique"),
            chapter("python-appliquees-1-simulation", "Simulation", domain: "Informatique"),
        ]

        static let annee2: [TrackChapter] = [
            chapter("python-appliquees-2-boucles-sommes", "Boucles et sommes", domain: "Informatique"),
            chapter("python-appliquees-2-simulation-discrete", "Simulation discrète", domain: "Informatique"),
            chapter("python-appliquees-2-simulation-couples", "Simulation de couples", domain: "Informatique"),
            chapter("python-appliquees-2-calcul-matriciel", "Calcul matriciel", domain: "Informatique"),
            chapter("python-appliquees-2-dichotomie", "Dichotomie", domain: "Informatique"),
            chapter("python-appliquees-2-bases-donnees", "Bases de données", domain: "Informatique"),
            chapter("python-appliquees-2-systemes-differentiels", "Systèmes différentiels", domain: "Informatique"),
            chapter("python-appliquees-2-statistiques-bivariees", "Statistiques bivariées", domain: "Informatique"),
            chapter("python-appliquees-2-chaines-markov", "Chaînes de Markov", domain: "Informatique"),
            chapter("python-appliquees-2-estimation", "Estimation", domain: "Informatique"),
        ]
    }
}
