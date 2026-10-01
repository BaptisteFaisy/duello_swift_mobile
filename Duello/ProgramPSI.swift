// [ProgramPSI] Programme PSI : catalogue complet des matières (`psiProgram` de `src/data/tracks.ts`).
// [ProgramPSI] `psiSubjects` assemble une fonction par matière (`psiMaths`, `psiPhysiqueChimie`, …) ; l'énum `PSI` porte le catalogue statique de chapitres.
import Foundation

extension DuelloProgram {

    // MARK: PSI (2e année)

    /// `psiProgram()` de la source : maths, physique-chimie, sciences de
    /// l'ingénieur, informatique commune et les matières communes de 2e année.
    static func psiSubjects() -> [TrackSubject] {
        [
            psiMaths(),
            psiPhysiqueChimie(),
            psiSciencesIngenieur(),
            psiInformatique(),
            psiFrancaisPhilo(),
            psiAnglais(),
            psiLv2(),
        ]
    }

    // MARK: - Matières PSI (une fonction par matière)

    private static func psiMaths() -> TrackSubject {
        TrackSubject(
            id: "maths",
            name: "Mathématiques",
            fullName: nil,
            icon: "function",
            chapters: PSI.maths
        )
    }

    private static func psiPhysiqueChimie() -> TrackSubject {
        TrackSubject(
            id: "physique-chimie",
            name: "Physique-Chimie",
            fullName: nil,
            icon: "atom",
            chapters: PSI.physiqueChimie
        )
    }

    private static func psiSciencesIngenieur() -> TrackSubject {
        TrackSubject(
            id: "sciences-ingenieur",
            name: "Sciences de l’ingénieur",
            fullName: "SII — filière PSI",
            icon: "wrench.and.screwdriver",
            chapters: PSI.si
        )
    }

    private static func psiInformatique() -> TrackSubject {
        TrackSubject(
            id: "informatique",
            name: "Informatique",
            fullName: "Informatique commune",
            icon: "chevron.left.forwardslash.chevron.right",
            chapters: MP.informatique
        )
    }

    private static func psiFrancaisPhilo() -> TrackSubject {
        TrackSubject(
            id: "francais-philo",
            name: "Français-Philosophie",
            fullName: "Thème et œuvres au programme du concours",
            icon: "book",
            chapters: MP.francais
        )
    }

    private static func psiAnglais() -> TrackSubject {
        TrackSubject(
            id: "anglais",
            name: "Anglais",
            fullName: "Langue vivante 1",
            icon: "globe",
            chapters: Langues.anglaisAnnee2
        )
    }

    private static func psiLv2() -> TrackSubject {
        TrackSubject(
            id: "lv2",
            name: "LV2",
            fullName: "Espagnol, allemand, italien…",
            icon: "bubble.left.and.bubble.right",
            chapters: Langues.lv2Annee2
        )
    }

    /// Catalogues de chapitres PSI (`PSI_*` de `src/data/tracks.ts`).
    enum PSI {

        /// `PSI_MATHS` (18 chapitres).
        static let maths: [TrackChapter] = [
            chapter("psi-algebre-lineaire", "Compléments sur les espaces vectoriels, les endomorphismes et les matrices", domain: "Algèbre"),
            chapter("psi-determinants", "Déterminants", domain: "Algèbre"),
            chapter("psi-reduction", "Réduction des endomorphismes et des matrices carrées", domain: "Algèbre"),
            chapter("psi-espaces-euclidiens", "Espaces préhilbertiens réels", domain: "Géométrie"),
            chapter("psi-endomorphismes-euclidiens", "Endomorphismes d’un espace euclidien", domain: "Géométrie"),
            chapter("psi-espaces-normes", "Espaces vectoriels normés", domain: "Géométrie"),
            chapter("psi-limites-continuite-et-derivabilite", "Limites, continuité et dérivabilité", domain: "Analyse"),
            chapter("psi-series-numeriques", "Compléments sur les séries numériques", domain: "Analyse"),
            chapter("psi-series-fonctions", "Suites et séries de fonctions", domain: "Analyse"),
            chapter("psi-series-entieres", "Séries entières", domain: "Analyse"),
            chapter("psi-integration-intervalle", "Intégration sur un intervalle quelconque", domain: "Analyse"),
            chapter("psi-integrales-parametre", "Intégrales dépendant d’un paramètre", domain: "Analyse"),
            chapter("psi-equations-differentielles", "Équations différentielles linéaires scalaires", domain: "Analyse"),
            chapter("psi-derivabilite-fonctions-vectorielles", "Dérivabilité des fonctions vectorielles", domain: "Analyse"),
            chapter("psi-calcul-differentiel", "Fonctions de plusieurs variables", domain: "Analyse"),
            chapter("psi-ensembles-denombrables-familles-sommables", "Ensembles dénombrables, familles sommables", domain: "Probabilités"),
            chapter("psi-variables-aleatoires", "Probabilités, variables aléatoires discrètes et lois usuelles", domain: "Probabilités"),
            chapter("psi-esperance-variance", "Espérance et variance", domain: "Probabilités"),
        ]

        /// `PSI_PHYSIQUE_CHIMIE` (8 chapitres).
        static let physiqueChimie: [TrackChapter] = [
            chapter("psi-electronique", "Électronique"),
            chapter("psi-phenomenes-transport", "Phénomènes de transport"),
            chapter("psi-bilans-macroscopiques", "Bilans macroscopiques"),
            chapter("psi-electromagnetisme", "Électromagnétisme"),
            chapter("psi-conversion-puissance", "Conversion de puissance"),
            chapter("psi-ondes", "Phénomènes ondulatoires"),
            chapter("psi-thermodynamique-chimique", "Thermodynamique des transformations chimiques"),
            chapter("psi-electrochimie", "Électrochimie"),
        ]

        /// `PSI_SI` (8 chapitres).
        static let si: [TrackChapter] = [
            chapter("psi-si-ingenierie-systeme", "Ingénierie système et analyse fonctionnelle"),
            chapter("psi-si-modelisation-multiphysique", "Modélisation multiphysique"),
            chapter("psi-si-automatique", "Automatique et commande des systèmes"),
            chapter("psi-si-mecanique-solides", "Mécanique des solides"),
            chapter("psi-si-energetique", "Énergétique et conversion de puissance"),
            chapter("psi-si-numerique", "Modélisation numérique et simulation"),
            chapter("psi-si-experimentation", "Expérimentation, identification et validation"),
            chapter("psi-si-conception", "Conception et optimisation des systèmes"),
        ]
    }
}
