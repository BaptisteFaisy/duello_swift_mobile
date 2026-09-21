// [ProgramPSI] Programme PSI condensé : mathématiques, physique-chimie, sciences industrielles.
// [ProgramPSI] Dérogation : `psiSubjects` (55 lignes) ne fait que retourner un catalogue statique de chapitres — exception « données statiques volumineuses » des règles de complexité Duello.
import Foundation

extension DuelloProgram {

    static func psiSubjects() -> [TrackSubject] {
        [
            TrackSubject(
                id: "maths",
                name: "Mathématiques",
                fullName: nil,
                icon: "function",
                chapters: [
                    chapter("psi-algebre-lineaire", "Algèbre linéaire : compléments", domain: "Algèbre"),
                    chapter("psi-reduction", "Réduction des endomorphismes et des matrices", domain: "Algèbre"),
                    chapter("psi-espaces-euclidiens", "Espaces préhilbertiens et euclidiens", domain: "Algèbre"),
                    chapter("psi-espaces-normes", "Espaces vectoriels normés", domain: "Analyse"),
                    chapter("psi-series-numeriques", "Suites et séries numériques", domain: "Analyse"),
                    chapter("psi-series-fonctions", "Suites et séries de fonctions", domain: "Analyse"),
                    chapter("psi-series-entieres", "Séries entières", domain: "Analyse"),
                    chapter("psi-integration-intervalle", "Intégration sur un intervalle quelconque", domain: "Analyse"),
                    chapter("psi-equations-differentielles", "Équations différentielles scalaires", domain: "Analyse"),
                    chapter("psi-calcul-differentiel", "Calcul différentiel de plusieurs variables", domain: "Analyse"),
                    chapter("psi-variables-aleatoires", "Variables aléatoires discrètes", domain: "Probabilités"),
                ]
            ),
            TrackSubject(
                id: "physique-chimie",
                name: "Physique-chimie",
                fullName: nil,
                icon: "atom",
                chapters: [
                    chapter("psi-electronique", "Électronique"),
                    chapter("psi-phenomenes-transport", "Phénomènes de transport"),
                    chapter("psi-bilans-macroscopiques", "Bilans macroscopiques"),
                    chapter("psi-electromagnetisme", "Électromagnétisme"),
                    chapter("psi-conversion-puissance", "Conversion de puissance"),
                    chapter("psi-ondes", "Phénomènes ondulatoires"),
                    chapter("psi-thermodynamique-chimique", "Thermodynamique des transformations chimiques"),
                    chapter("psi-electrochimie", "Électrochimie"),
                ]
            ),
            TrackSubject(
                id: "si",
                name: "Sciences industrielles",
                fullName: nil,
                icon: "wrench.and.screwdriver",
                chapters: [
                    chapter("psi-si-ingenierie-systeme", "Ingénierie système et analyse fonctionnelle"),
                    chapter("psi-si-modelisation-multiphysique", "Modélisation multiphysique"),
                    chapter("psi-si-automatique", "Automatique et commande des systèmes"),
                    chapter("psi-si-mecanique-solides", "Mécanique des solides"),
                    chapter("psi-si-energetique", "Énergétique et conversion de puissance"),
                    chapter("psi-si-numerique", "Modélisation numérique et simulation"),
                    chapter("psi-si-experimentation", "Expérimentation, identification et validation"),
                    chapter("psi-si-conception", "Conception et optimisation des systèmes"),
                ]
            ),
        ]
    }
}
