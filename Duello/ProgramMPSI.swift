// [ProgramMPSI] Programme MPSI : catalogue complet des matières (`mpsiProgram` de `src/data/tracks.ts`).
// [ProgramMPSI] `mpsiSubjects` assemble une fonction par matière (`mpsiMaths`, `mpsiPhysique`, …) ; l'énum `MPSI` porte le catalogue statique de chapitres.
import Foundation

extension DuelloProgram {

    // MARK: MPSI (maths, physique, chimie, SI, informatique, français-philo, langues)

    /// `mpsiProgram(specialty, year)` de la source. L'option suivie
    /// (`specialty`) conditionne l'ajout des chapitres d'option : tant que
    /// l'option n'est pas renseignée, les chapitres des deux options sont
    /// proposés (aucun chapitre du programme n'est masqué).
    static func mpsiSubjects(specialty: String) -> [TrackSubject] {
        let option = Self.normalize(specialty)
        let hasInformatique = !option.contains("industrielles")
        let hasSi = !option.contains("informatique")

        return [
            mpsiMaths(),
            mpsiPhysique(),
            mpsiChimie(),
            mpsiSciencesIngenieur(hasSi: hasSi),
            mpsiInformatique(hasInformatique: hasInformatique),
            mpsiFrancaisPhilo(),
            mpsiAnglais(),
            mpsiLv2(),
        ]
    }

    // MARK: - Matières MPSI (une fonction par matière)

    private static func mpsiMaths() -> TrackSubject {
        TrackSubject(
            id: "maths",
            name: "Mathématiques",
            fullName: nil,
            icon: "function",
            chapters: MPSI.maths
        )
    }

    private static func mpsiPhysique() -> TrackSubject {
        TrackSubject(
            id: "physique",
            name: "Physique",
            fullName: nil,
            icon: "atom",
            chapters: MPSI.physique
        )
    }

    private static func mpsiChimie() -> TrackSubject {
        TrackSubject(
            id: "chimie",
            name: "Chimie",
            fullName: nil,
            icon: "drop",
            chapters: MPSI.chimie
        )
    }

    private static func mpsiSciencesIngenieur(hasSi: Bool) -> TrackSubject {
        TrackSubject(
            id: "sciences-ingenieur",
            name: "Sciences de l’ingénieur",
            fullName: "SII — modélisation et systèmes asservis",
            icon: "wrench.and.screwdriver",
            chapters: hasSi ? MPSI.si + MPSI.siOption : MPSI.si
        )
    }

    private static func mpsiInformatique(hasInformatique: Bool) -> TrackSubject {
        TrackSubject(
            id: "informatique",
            name: "Informatique",
            fullName: "Informatique pour tous — Python et algorithmique",
            icon: "chevron.left.forwardslash.chevron.right",
            chapters: hasInformatique
                ? MPSI.informatique + MPSI.informatiqueOption
                : MPSI.informatique
        )
    }

    private static func mpsiFrancaisPhilo() -> TrackSubject {
        TrackSubject(
            id: "francais-philo",
            name: "Français-Philosophie",
            fullName: "Méthode et culture générale",
            icon: "book",
            chapters: MPSI.francais
        )
    }

    private static func mpsiAnglais() -> TrackSubject {
        TrackSubject(
            id: "anglais",
            name: "Anglais",
            fullName: "Langue vivante 1",
            icon: "globe",
            chapters: Langues.anglaisAnnee1
        )
    }

    private static func mpsiLv2() -> TrackSubject {
        TrackSubject(
            id: "lv2",
            name: "LV2",
            fullName: "Espagnol, allemand, italien…",
            icon: "bubble.left.and.bubble.right",
            chapters: Langues.lv2Annee1
        )
    }

    /// Catalogues de chapitres MPSI (`MPSI_*` de `src/data/tracks.ts`).
    enum MPSI {

        /// `MPSI_MATHS` (32 chapitres).
        static let maths: [TrackChapter] = [
            chapter("logique", "Rudiments de logique et modes de raisonnement", domain: "Fondements"),
            chapter("ensembles", "Ensembles, applications et relations", domain: "Fondements"),
            chapter("sommes-produits", "Sommes, produits et coefficients binomiaux", domain: "Fondements"),
            chapter("complexes", "Nombres complexes et trigonométrie", domain: "Fondements"),
            chapter("fonctions-usuelles", "Fonctions usuelles", domain: "Analyse"),
            chapter("calcul-derivation", "Techniques fondamentales de calcul : dérivation et primitives", domain: "Analyse"),
            chapter("equations-differentielles", "Équations différentielles linéaires", domain: "Analyse"),
            chapter("reels", "Nombres réels et borne supérieure", domain: "Analyse"),
            chapter("suites", "Suites numériques", domain: "Analyse"),
            chapter("limites-continuite", "Limites et continuité", domain: "Analyse"),
            chapter("derivabilite", "Dérivabilité et théorème des accroissements finis", domain: "Analyse"),
            chapter("analyse-asymptotique", "Analyse asymptotique et développements limités", domain: "Analyse"),
            chapter("taylor", "Formules de Taylor", domain: "Analyse"),
            chapter("integration", "Intégration sur un segment", domain: "Analyse"),
            chapter("series-numeriques", "Procédés sommatoires : séries numériques et familles sommables", domain: "Analyse"),
            chapter("fonctions-deux-variables", "Fonctions de deux variables", domain: "Analyse"),
            chapter("arithmetique", "Arithmétique dans Z", domain: "Algèbre"),
            chapter("structures-algebriques", "Structures algébriques : groupes, anneaux, corps", domain: "Algèbre"),
            chapter("polynomes", "Polynômes", domain: "Algèbre"),
            chapter("fractions-rationnelles", "Fractions rationnelles", domain: "Algèbre"),
            chapter("espaces-vectoriels", "Espaces vectoriels et sous-espaces", domain: "Algèbre"),
            chapter("dimension", "Familles libres, bases et dimension", domain: "Algèbre"),
            chapter("applications-lineaires", "Applications linéaires", domain: "Algèbre"),
            chapter("matrices", "Matrices et calcul matriciel", domain: "Algèbre"),
            chapter("systemes-lineaires", "Systèmes linéaires et pivot de Gauss", domain: "Algèbre"),
            chapter("determinants", "Déterminants", domain: "Algèbre"),
            chapter("prehilbertiens", "Espaces préhilbertiens réels et espaces euclidiens", domain: "Géométrie"),
            chapter("geometrie", "Géométrie du plan et de l’espace", domain: "Géométrie"),
            chapter("denombrement", "Dénombrement", domain: "Probabilités"),
            chapter("probabilites", "Probabilités sur un univers fini", domain: "Probabilités"),
            chapter("variables-aleatoires", "Variables aléatoires sur un univers fini", domain: "Probabilités"),
            chapter("problemes-transversaux", "Problèmes transversaux de première année", domain: "Synthèse"),
        ]

        /// `MPSI_PHYSIQUE` (27 chapitres).
        static let physique: [TrackChapter] = [
            chapter("mesures-incertitudes", "Mesures, incertitudes et méthodes expérimentales"),
            chapter("oscillateur-harmonique", "Oscillateur harmonique"),
            chapter("propagation-signal", "Propagation d’un signal et ondes progressives"),
            chapter("interferences", "Superposition et interférences d’ondes"),
            chapter("optique-lois", "Optique géométrique : lois de Snell-Descartes"),
            chapter("lentilles", "Lentilles minces et instruments d’optique"),
            chapter("monde-quantique", "Introduction au monde quantique"),
            chapter("arqs", "Circuits électriques dans l’ARQS"),
            chapter("premier-ordre", "Régimes transitoires : circuits du premier ordre"),
            chapter("rlc", "Oscillateurs amortis et circuit RLC"),
            chapter("regime-sinusoidal", "Régime sinusoïdal forcé et impédances"),
            chapter("filtrage", "Filtrage linéaire et diagrammes de Bode"),
            chapter("cinematique-point", "Cinématique du point"),
            chapter("dynamique-point", "Dynamique du point et lois de Newton"),
            chapter("energetique", "Approche énergétique du mouvement"),
            chapter("oscillateurs-mecaniques", "Oscillateurs mécaniques et portrait de phase"),
            chapter("particules-chargees", "Mouvement de particules chargées dans un champ"),
            chapter("forces-centrales", "Forces centrales conservatives et mouvement képlérien"),
            chapter("moment-cinetique", "Moment cinétique et solide en rotation"),
            chapter("statique-fluides", "Statique des fluides"),
            chapter("systemes-thermo", "Descriptions macroscopique et microscopique d’un système"),
            chapter("premier-principe", "Premier principe de la thermodynamique"),
            chapter("second-principe", "Second principe et entropie"),
            chapter("machines-thermiques", "Machines thermiques"),
            chapter("corps-diphase", "Corps pur diphasé et changements d’état"),
            chapter("champ-magnetique", "Champ magnétique et forces de Laplace"),
            chapter("induction", "Induction électromagnétique et circuit mobile"),
        ]

        /// `MPSI_CHIMIE` (15 chapitres).
        static let chimie: [TrackChapter] = [
            chapter("transformations", "Transformations de la matière et états physiques"),
            chapter("avancement", "Description d’un système physico-chimique et avancement"),
            chapter("equilibre", "Évolution vers un état final : équilibre et quotient réactionnel"),
            chapter("cinetique", "Cinétique chimique macroscopique"),
            chapter("mecanismes", "Mécanismes réactionnels"),
            chapter("atome", "Structure de l’atome et classification périodique"),
            chapter("liaison-covalente", "Liaison covalente : schémas de Lewis et VSEPR"),
            chapter("forces-intermoleculaires", "Polarité, forces intermoléculaires et solvants"),
            chapter("cristaux", "Structure des solides cristallins"),
            chapter("acide-base", "Réactions acide-base en solution aqueuse"),
            chapter("precipitation", "Réactions de précipitation et solubilité"),
            chapter("complexation", "Réactions de complexation"),
            chapter("oxydoreduction", "Oxydoréduction et piles électrochimiques"),
            chapter("diagrammes-e-ph", "Diagrammes potentiel-pH"),
            chapter("titrages", "Dosages et titrages"),
        ]

        /// `MPSI_SI` (19 chapitres) et `MPSI_SI_OPTION` (2 chapitres).
        static let si: [TrackChapter] = [
            chapter("demarche-ingenieur", "Démarche de l’ingénieur et analyse des systèmes"),
            chapter("sysml", "Modélisation fonctionnelle (SysML) et cahier des charges"),
            chapter("chaines-fonctionnelles", "Chaîne d’énergie et chaîne d’information"),
            chapter("cinematique-solide", "Cinématique du solide indéformable"),
            chapter("liaisons", "Liaisons et schéma cinématique"),
            chapter("torseurs-cinematiques", "Torseurs cinématiques et champ des vitesses"),
            chapter("statique", "Statique et torseurs d’actions mécaniques"),
            chapter("frottement", "Lois de Coulomb et frottement"),
            chapter("cinetique", "Cinétique du solide et torseur cinétique"),
            chapter("pfd", "Principe fondamental de la dynamique"),
            chapter("theoremes-energetiques", "Théorèmes énergétiques et rendement"),
            chapter("slci", "Modélisation des systèmes linéaires continus invariants"),
            chapter("fonction-transfert", "Fonctions de transfert et schémas-blocs"),
            chapter("reponses-temporelles", "Réponses temporelles : premier et second ordre"),
            chapter("reponses-frequentielles", "Réponses fréquentielles et diagrammes de Bode"),
            chapter("performances", "Performances : stabilité, précision, rapidité"),
            chapter("correction", "Correction des systèmes asservis (P, PI, PID)"),
            chapter("actionneurs", "Modélisation des actionneurs et moteur à courant continu"),
            chapter("capteurs", "Capteurs, conditionnement et acquisition"),
        ]

        static let siOption: [TrackChapter] = [
            chapter("simulation-numerique", "Résolution numérique et simulation des modèles"),
            chapter("projet-conception", "Travaux pratiques et projet de conception"),
        ]

        /// `MPSI_INFORMATIQUE` (19 chapitres) et `MPSI_INFORMATIQUE_OPTION` (8 chapitres).
        static let informatique: [TrackChapter] = [
            chapter("python-bases", "Prise en main de Python : types et variables"),
            chapter("structures-controle", "Structures de contrôle : tests et boucles"),
            chapter("fonctions", "Fonctions, portée et documentation"),
            chapter("listes", "Listes, tuples et chaînes de caractères"),
            chapter("dictionnaires", "Dictionnaires et ensembles"),
            chapter("recursivite", "Récursivité"),
            chapter("correction-terminaison", "Spécification, correction et terminaison"),
            chapter("complexite", "Complexité d’un algorithme"),
            chapter("tris-elementaires", "Tris élémentaires : insertion et sélection"),
            chapter("tris-recursifs", "Tris récursifs : fusion et tri rapide"),
            chapter("dichotomie", "Recherche dichotomique"),
            chapter("diviser-regner", "Diviser pour régner"),
            chapter("gloutons", "Algorithmes gloutons"),
            chapter("representation-nombres", "Représentation des nombres en machine"),
            chapter("zeros-fonctions", "Résolution approchée d’équations : dichotomie et Newton"),
            chapter("integration-numerique", "Calcul approché d’intégrales"),
            chapter("euler", "Résolution numérique d’équations différentielles : méthode d’Euler"),
            chapter("bases-de-donnees", "Bases de données relationnelles et algèbre relationnelle"),
            chapter("sql", "Requêtes SQL"),
        ]

        static let informatiqueOption: [TrackChapter] = [
            chapter("ocaml", "Programmation fonctionnelle en OCaml"),
            chapter("types-construits", "Types construits et filtrage de motifs"),
            chapter("recursivite-terminale", "Récursivité terminale et preuve de programmes"),
            chapter("structures-persistantes", "Listes et structures de données persistantes"),
            chapter("arbres", "Arbres binaires et arbres binaires de recherche"),
            chapter("piles-files", "Piles, files et structures mutables"),
            chapter("graphes", "Graphes : représentations et parcours"),
            chapter("logique-propositionnelle", "Logique propositionnelle et satisfiabilité"),
        ]

        /// `MPSI_FRANCAIS` (13 chapitres).
        static let francais: [TrackChapter] = [
            chapter("methode-resume", "Méthode du résumé de texte"),
            chapter("methode-dissertation", "Méthode de la dissertation"),
            chapter("explication-texte", "Analyse et explication de texte"),
            chapter("philosophie-antique", "Repères de philosophie antique"),
            chapter("philosophie-moderne", "Repères de philosophie moderne"),
            chapter("philosophie-contemporaine", "Repères de philosophie contemporaine"),
            chapter("courants-litteraires", "Grands courants littéraires"),
            chapter("theatre", "Le théâtre : formes et enjeux"),
            chapter("roman", "Le roman et le récit"),
            chapter("poesie", "La poésie"),
            chapter("argumentation", "Argumentation et rhétorique"),
            chapter("notions-transversales", "Culture générale : notions transversales"),
            chapter("expression", "Expression écrite et orale"),
        ]
    }
}
