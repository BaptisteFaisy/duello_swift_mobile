// [ProgramMP] Programme MP : catalogue complet des matières (`mpsiProgram(specialty, 2)` de `src/data/tracks.ts`).
// [ProgramMP] `mpSubjects` assemble une fonction par matière (`mpMaths`, `mpPhysique`, …) ; l'énum `MP` porte le catalogue statique de chapitres.
import Foundation

extension DuelloProgram {

    // MARK: MP (2e année) — mêmes matières que MPSI, programmes de 2e année

    /// `mpsiProgram(specialty, 2)` de la source : la 2e année d'une filière
    /// scientifique. L'option `specialty` conditionne l'ajout des chapitres
    /// d'option d'informatique.
    static func mpSubjects(specialty: String) -> [TrackSubject] {
        let hasInformatique = !Self.normalize(specialty).contains("industrielles")

        return [
            mpMaths(),
            mpPhysique(),
            mpChimie(),
            mpSciencesIngenieur(),
            mpInformatique(hasInformatique: hasInformatique),
            mpFrancaisPhilo(),
            mpAnglais(),
            mpLv2(),
        ]
    }

    // MARK: - Matières MP (une fonction par matière)

    private static func mpMaths() -> TrackSubject {
        TrackSubject(
            id: "maths",
            name: "Mathématiques",
            fullName: nil,
            icon: "function",
            chapters: MP.maths
        )
    }

    private static func mpPhysique() -> TrackSubject {
        TrackSubject(
            id: "physique",
            name: "Physique",
            fullName: nil,
            icon: "atom",
            chapters: MP.physique
        )
    }

    private static func mpChimie() -> TrackSubject {
        TrackSubject(
            id: "chimie",
            name: "Chimie",
            fullName: nil,
            icon: "drop",
            chapters: MP.chimie
        )
    }

    private static func mpSciencesIngenieur() -> TrackSubject {
        TrackSubject(
            id: "sciences-ingenieur",
            name: "Sciences de l’ingénieur",
            fullName: "SII — modélisation et systèmes asservis",
            icon: "wrench.and.screwdriver",
            chapters: MP.si
        )
    }

    private static func mpInformatique(hasInformatique: Bool) -> TrackSubject {
        TrackSubject(
            id: "informatique",
            name: "Informatique",
            fullName: "Informatique pour tous — Python et algorithmique",
            icon: "chevron.left.forwardslash.chevron.right",
            chapters: hasInformatique
                ? MP.informatique + MP.informatiqueOption
                : MP.informatique
        )
    }

    private static func mpFrancaisPhilo() -> TrackSubject {
        TrackSubject(
            id: "francais-philo",
            name: "Français-Philosophie",
            fullName: "Thème et œuvres au programme du concours",
            icon: "book",
            chapters: MP.francais
        )
    }

    private static func mpAnglais() -> TrackSubject {
        TrackSubject(
            id: "anglais",
            name: "Anglais",
            fullName: "Langue vivante 1",
            icon: "globe",
            chapters: Langues.anglaisAnnee2
        )
    }

    private static func mpLv2() -> TrackSubject {
        TrackSubject(
            id: "lv2",
            name: "LV2",
            fullName: "Espagnol, allemand, italien…",
            icon: "bubble.left.and.bubble.right",
            chapters: Langues.lv2Annee2
        )
    }

    /// Catalogues de chapitres MP (`MP_*` de `src/data/tracks.ts`).
    enum MP {

        /// `MP_MATHS` (28 chapitres).
        static let maths: [TrackChapter] = [
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
            chapter("algebre-lineaire", "Compléments d’algèbre linéaire : sommes directes et projecteurs", domain: "Algèbre"),
            chapter("matrices-determinants", "Matrices et déterminants : compléments", domain: "Algèbre"),
            chapter("valeurs-propres", "Réduction : valeurs propres et vecteurs propres", domain: "Algèbre"),
            chapter("diagonalisation", "Diagonalisation et trigonalisation", domain: "Algèbre"),
            chapter("cayley-hamilton", "Polynômes d’endomorphismes et théorème de Cayley-Hamilton", domain: "Algèbre"),
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

        /// `MP_PHYSIQUE` (25 chapitres).
        static let physique: [TrackChapter] = [
            chapter("electrostatique", "Électrostatique : champ et potentiel"),
            chapter("theoreme-gauss", "Théorème de Gauss et symétries"),
            chapter("magnetostatique", "Magnétostatique et théorème d’Ampère"),
            chapter("maxwell", "Équations de Maxwell dans le vide"),
            chapter("poynting", "Énergie électromagnétique et vecteur de Poynting"),
            chapter("induction", "Induction et conversion électromécanique"),
            chapter("ondes-vide", "Propagation des ondes électromagnétiques dans le vide"),
            chapter("ondes-milieux", "Ondes dans les milieux : plasmas et conducteurs"),
            chapter("reflexion-transmission", "Réflexion et transmission d’une onde"),
            chapter("optique-ondulatoire", "Optique ondulatoire : modèle scalaire et cohérence"),
            chapter("interferences", "Interférences à deux ondes"),
            chapter("michelson", "Interféromètre de Michelson"),
            chapter("diffraction", "Diffraction et réseaux"),
            chapter("referentiels", "Changements de référentiel et référentiels non galiléens"),
            chapter("solide", "Mécanique du solide et théorème du moment cinétique"),
            chapter("force-centrale", "Mouvement dans un champ de force centrale et lois de Kepler"),
            chapter("diffusion-thermique", "Diffusion thermique"),
            chapter("rayonnement", "Rayonnement thermique et corps noir"),
            chapter("mecanique-fluides", "Statique et dynamique des fluides"),
            chapter("physique-statistique", "Physique statistique et facteur de Boltzmann"),
            chapter("schrodinger", "Mécanique quantique : équation de Schrödinger"),
            chapter("effet-tunnel", "Puits de potentiel, marche et effet tunnel"),
            chapter("electronique", "Électronique : filtrage actif et stabilité"),
            chapter("oscillateurs", "Oscillateurs et non-linéarités"),
            chapter("travaux-pratiques", "Travaux pratiques et analyse des incertitudes"),
        ]

        /// `MP_CHIMIE` (9 chapitres).
        static let chimie: [TrackChapter] = [
            chapter("potentiel-chimique", "Thermodynamique chimique : potentiel chimique et enthalpie libre"),
            chapter("equilibres", "Équilibres chimiques et constante d’équilibre"),
            chapter("deplacement-equilibres", "Déplacement des équilibres et optimisation d’un procédé"),
            chapter("binaires-liquide-vapeur", "Diagrammes binaires liquide-vapeur"),
            chapter("binaires-solide-liquide", "Diagrammes binaires solide-liquide"),
            chapter("diagrammes-e-ph", "Électrochimie : potentiels et diagrammes E-pH"),
            chapter("courbes-intensite-potentiel", "Courbes intensité-potentiel"),
            chapter("corrosion", "Corrosion humide et protection des métaux"),
            chapter("electrolyse", "Électrolyse et accumulateurs"),
        ]

        /// `MP_SI` (10 chapitres).
        static let si: [TrackChapter] = [
            chapter("modelisation-multiphysique", "Modélisation multiphysique des systèmes"),
            chapter("dynamique-solide", "Compléments de dynamique du solide"),
            chapter("chaine-energie", "Chaîne d’énergie : dimensionnement et rendement"),
            chapter("commande-actionneurs", "Modélisation des actionneurs et de leur commande"),
            chapter("asservissement", "Systèmes asservis : compléments d’analyse"),
            chapter("correction-avancee", "Correction avancée : avance de phase et PID"),
            chapter("systemes-echantillonnes", "Systèmes échantillonnés et commande numérique"),
            chapter("non-lineaire", "Comportement non linéaire des systèmes"),
            chapter("traitement-signal", "Traitement du signal et de l’information"),
            chapter("projet-systeme", "Travaux pratiques et projet système"),
        ]

        /// `MP_INFORMATIQUE` (10 chapitres) et `MP_INFORMATIQUE_OPTION` (10 chapitres).
        static let informatique: [TrackChapter] = [
            chapter("complexite", "Compléments de complexité algorithmique"),
            chapter("programmation-dynamique", "Programmation dynamique"),
            chapter("structures-donnees", "Structures de données : piles, files et arbres"),
            chapter("graphes-representations", "Graphes : représentations"),
            chapter("parcours-graphes", "Parcours de graphes et plus courts chemins"),
            chapter("strategies-algorithmiques", "Gloutons et diviser pour régner : compléments"),
            chapter("sql-avance", "Bases de données : modèle relationnel et SQL avancé"),
            chapter("systemes-lineaires", "Résolution numérique de systèmes linéaires"),
            chapter("integration-numerique", "Intégration numérique et équations différentielles"),
            chapter("monte-carlo", "Méthode de Monte-Carlo et simulation"),
        ]

        static let informatiqueOption: [TrackChapter] = [
            chapter("langages-reguliers", "Langages réguliers et expressions régulières"),
            chapter("automates", "Automates finis déterministes et non déterministes"),
            chapter("grammaires", "Grammaires et langages algébriques"),
            chapter("machines-turing", "Machines de Turing et calculabilité"),
            chapter("decidabilite", "Décidabilité et problème de l’arrêt"),
            chapter("sat", "Logique propositionnelle et problème SAT"),
            chapter("logique-premier-ordre", "Logique du premier ordre"),
            chapter("arbres-equilibres", "Arbres équilibrés et tables de hachage"),
            chapter("graphes-avances", "Algorithmique avancée des graphes"),
            chapter("preuve-programmes", "Preuve et terminaison des programmes"),
        ]

        /// `MP_FRANCAIS` (11 chapitres).
        static let francais: [TrackChapter] = [
            chapter("theme-annee", "Le thème de l’année : définition et problématiques"),
            chapter("oeuvre-1", "Première œuvre au programme"),
            chapter("oeuvre-2", "Deuxième œuvre au programme"),
            chapter("oeuvre-3", "Troisième œuvre au programme"),
            chapter("confrontation", "Confrontation et mise en dialogue des œuvres"),
            chapter("reperes-philosophiques", "Repères philosophiques liés au thème"),
            chapter("methode-resume", "Méthode du résumé de texte"),
            chapter("methode-dissertation", "Méthode de la dissertation"),
            chapter("citations", "Constitution d’un carnet de citations"),
            chapter("entrainement-ecrit", "Entraînement aux épreuves écrites"),
            chapter("preparation-oral", "Préparation de l’oral"),
        ]
    }
}
