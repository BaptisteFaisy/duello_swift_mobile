// [ProgramMP] Programme MP condensé : mathématiques.
import Foundation

extension DuelloProgram {

    static func mpSubjects() -> [TrackSubject] {
        [
            TrackSubject(
                id: "maths",
                name: "Mathématiques",
                fullName: nil,
                icon: "function",
                chapters: [
                    chapter("convexite", "Convexité", domain: "Analyse"),
                    chapter("espaces-normes", "Espaces vectoriels normés", domain: "Analyse"),
                    chapter("topologie", "Topologie : ouverts, fermés, compacité et connexité", domain: "Analyse"),
                    chapter("series-numeriques", "Suites et séries numériques", domain: "Analyse"),
                    chapter("familles-sommables", "Familles sommables", domain: "Analyse"),
                    chapter("suites-series-fonctions", "Suites et séries de fonctions : convergence uniforme", domain: "Analyse"),
                    chapter("series-entieres", "Séries entières", domain: "Analyse"),
                    chapter("integration-intervalle", "Intégration sur un intervalle quelconque", domain: "Analyse"),
                    chapter("convergence-dominee", "Convergence dominée et intégrales à paramètre", domain: "Analyse"),
                    chapter("fonctions-vectorielles", "Fonctions vectorielles et arcs paramétrés", domain: "Analyse"),
                    chapter("systemes-differentiels", "Équations différentielles linéaires et systèmes différentiels", domain: "Analyse"),
                    chapter("calcul-differentiel", "Calcul différentiel et fonctions de plusieurs variables", domain: "Analyse"),
                    chapter("extrema", "Extrema et optimisation", domain: "Analyse"),
                    chapter("structures-arithmetique", "Structures algébriques et arithmétique : compléments", domain: "Algèbre"),
                    chapter("algebre-lineaire", "Compléments d'algèbre linéaire : sommes directes et projecteurs", domain: "Algèbre"),
                    chapter("matrices-determinants", "Matrices et déterminants : compléments", domain: "Algèbre"),
                    chapter("valeurs-propres", "Réduction : valeurs propres et vecteurs propres", domain: "Algèbre"),
                    chapter("diagonalisation", "Diagonalisation et trigonalisation", domain: "Algèbre"),
                    chapter("cayley-hamilton", "Polynômes d'endomorphismes et théorème de Cayley-Hamilton", domain: "Algèbre"),
                    chapter("prehilbertiens", "Espaces préhilbertiens réels : compléments", domain: "Géométrie"),
                    chapter("euclidiens", "Espaces euclidiens et endomorphismes autoadjoints", domain: "Géométrie"),
                    chapter("isometries", "Isométries et matrices orthogonales", domain: "Géométrie"),
                    chapter("denombrabilite", "Dénombrabilité", domain: "Probabilités"),
                    chapter("espaces-probabilises", "Espaces probabilisés et probabilités discrètes", domain: "Probabilités"),
                    chapter("variables-discretes", "Variables aléatoires discrètes et lois usuelles", domain: "Probabilités"),
                    chapter("couples-independance", "Couples de variables, indépendance et covariance", domain: "Probabilités"),
                    chapter("fonctions-generatrices", "Fonctions génératrices", domain: "Probabilités"),
                    chapter("concentration", "Inégalités de concentration et loi faible des grands nombres", domain: "Probabilités"),
                ]
            ),
        ]
    }
}
