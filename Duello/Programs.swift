import Foundation

/// Programmes officiels portés par Duello, repris de `src/data/tracks.ts` et
/// `src/data/ecgMathsProgram.ts`. Les identifiants de chapitres sont les clés
/// utilisées par le serveur pour l'appariement des défis : ils doivent rester
/// identiques à ceux de l'app Expo.
enum DuelloProgram {

    /// Matières du parcours choisi, dans l'ordre de l'app Expo.
    static func subjects(track: String, specialty: String, year: String) -> [TrackSubject] {
        let normalized = Self.normalize(track)
        let isFirstYear = !year.lowercased().contains("2")

        if normalized.contains("ecg") {
            return ecgSubjects(
                isFirstYear: isFirstYear,
                mathsApplied: Self.normalize(specialty).contains("applique")
            )
        }
        if normalized.contains("mpsi") { return mpsiSubjects() }
        if normalized.contains("psi") { return psiSubjects() }
        if normalized == "mp" || normalized.contains("mp2") || normalized.contains("mpi") {
            return mpSubjects()
        }
        // Sans parcours connu, l'ECG 1re année s'affiche : le parcours le plus
        // courant, aucune matière du programme ECG n'est masquée.
        return ecgSubjects(isFirstYear: true, mathsApplied: false)
    }

    private static func normalize(_ value: String) -> String {
        value.folding(options: .diacriticInsensitive, locale: Locale(identifier: "fr_FR"))
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: ECG

    private static func ecgSubjects(isFirstYear: Bool, mathsApplied: Bool) -> [TrackSubject] {
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

    private static func chapter(_ id: String, _ name: String, domain: String? = nil) -> TrackChapter {
        TrackChapter(id: id, name: name, domain: domain)
    }

    private enum MathsApprofondies {
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

    private enum MathsAppliquees {
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

    private enum ESH {
        static let annee1: [TrackChapter] = [
            chapter("objet-economie", "Module 1 — L'objet et les méthodes de l'économie"),
            chapter("courants-pensee", "Module 1 — Les grands courants de la pensée économique"),
            chapter("production-valeur", "Module 1 — Production, valeur ajoutée et répartition"),
            chapter("monnaie", "Module 1 — La monnaie et sa création"),
            chapter("financement", "Module 1 — Le financement de l'économie"),
            chapter("marches-prix", "Module 1 — Les marchés et la formation des prix"),
            chapter("defaillances-marche", "Module 1 — Concurrence, imperfections et défaillances de marché"),
            chapter("fondements-sociologie", "Module 1 — Les fondements de la sociologie et ses grands auteurs"),
            chapter("stratification", "Module 1 — Stratification sociale et mobilité"),
            chapter("croissance", "Module 2 — La croissance économique : sources et mesure"),
            chapter("revolutions-industrielles", "Module 2 — Les révolutions industrielles et l'innovation"),
            chapter("fluctuations", "Module 2 — Fluctuations et crises économiques depuis le XIXe siècle"),
            chapter("developpement", "Module 2 — Le développement et ses indicateurs"),
            chapter("mutations-productives", "Module 2 — Mutations des structures économiques et productives"),
            chapter("mutations-sociales", "Module 2 — Mutations des structures sociales et démographiques"),
            chapter("travail-salariat", "Module 2 — Travail, emploi et transformations du salariat"),
            chapter("role-etat", "Module 2 — Le rôle de l'État dans la croissance"),
            chapter("methode-dissertation", "Méthode de la dissertation d'ESH"),
        ]

        static let annee2: [TrackChapter] = [
            chapter("origines-mondialisation", "Module 3 — Les origines historiques de la mondialisation"),
            chapter("commerce-international", "Module 3 — Le commerce international : théories et politiques"),
            chapter("mondialisation-productive", "Module 3 — Mondialisation productive et firmes multinationales"),
            chapter("mondialisation-financiere", "Module 3 — La mondialisation financière et les marchés de capitaux"),
            chapter("systeme-monetaire", "Module 3 — Le système monétaire international et les changes"),
            chapter("integration-europeenne", "Module 3 — L'intégration européenne et l'union monétaire"),
            chapter("inegalites-mondialisation", "Module 3 — Inégalités et développement dans la mondialisation"),
            chapter("modeles-macro", "Module 4 — Les grands modèles macroéconomiques : classiques et keynésiens"),
            chapter("equilibre-macro", "Module 4 — L'équilibre macroéconomique et ses déséquilibres"),
            chapter("chomage", "Module 4 — Le chômage : mesures, causes et politiques"),
            chapter("inflation", "Module 4 — L'inflation et la déflation"),
            chapter("crises-financieres", "Module 4 — Les crises financières et leur régulation"),
            chapter("politique-monetaire", "Module 4 — La politique monétaire et les banques centrales"),
            chapter("politique-budgetaire", "Module 4 — La politique budgétaire et la dette publique"),
            chapter("politiques-structurelles", "Module 4 — Les politiques structurelles et de l'emploi"),
            chapter("protection-sociale", "Module 4 — La protection sociale et l'État-providence"),
            chapter("croissance-soutenable", "Module 4 — Politiques environnementales et croissance soutenable"),
            chapter("limites-action-publique", "Module 4 — Les limites et contraintes de l'action publique"),
        ]
    }

    private enum HGG {
        static let annee1: [TrackChapter] = [
            chapter("tableaux-geopolitiques", "Module 1 — Tableaux géopolitiques du monde en 1913, 1939 et 1945"),
            chapter("guerres-mondiales", "Module 1 — Les deux guerres mondiales et leurs conséquences"),
            chapter("guerre-froide", "Module 1 — La guerre froide : acteurs et espaces"),
            chapter("decolonisation", "Module 1 — Décolonisation et émergence du tiers-monde"),
            chapter("construction-europeenne", "Module 1 — La construction européenne et ses défis"),
            chapter("croissance-1945-1970", "Module 1 — Croissance et types de croissance de 1945 aux années 1970"),
            chapter("crises-1970-1990", "Module 1 — Crises et mutations économiques des années 1970-1990"),
            chapter("france-1945-1990", "Module 1 — La France, une puissance en mutation (1945-1990)"),
            chapter("dynamiques-mondialisation", "Module 2 — Les dynamiques de la mondialisation contemporaine"),
            chapter("acteurs-mondialisation", "Module 2 — Les acteurs : firmes, États, organisations et ONG"),
            chapter("flux-reseaux", "Module 2 — Flux, échanges et réseaux mondiaux"),
            chapter("metropolisation", "Module 2 — Métropolisation, littoralisation et recompositions territoriales"),
            chapter("ressources-energie", "Module 2 — Ressources, énergie et matières premières"),
            chapter("environnement-climat", "Module 2 — Environnement, climat et développement durable"),
            chapter("migrations", "Module 2 — Migrations internationales et enjeux démographiques"),
            chapter("gouvernance-conflits", "Module 2 — Puissance, gouvernance mondiale et conflits"),
            chapter("france-mondialisation", "Module 2 — La France dans la mondialisation"),
            chapter("methode", "Méthode : dissertation et croquis de géopolitique"),
        ]

        static let annee2: [TrackChapter] = [
            chapter("europe-dynamiques", "Module 3 — L'Europe : dynamiques territoriales et puissance"),
            chapter("union-europeenne", "Module 3 — L'Union européenne : intégration, crises et élargissements"),
            chapter("france-puissance", "Module 3 — La France : territoire, puissance et influence"),
            chapter("afrique-dynamiques", "Module 3 — L'Afrique : dynamiques démographiques et économiques"),
            chapter("afrique-mondialisation", "Module 3 — L'Afrique dans la mondialisation : ressources et conflits"),
            chapter("moyen-orient-conflits", "Module 3 — Le Proche et Moyen-Orient : géopolitique des conflits"),
            chapter("moyen-orient-energie", "Module 3 — Le Proche et Moyen-Orient : énergie et recompositions"),
            chapter("russie", "Module 3 — La Russie : puissance eurasiatique et étranger proche"),
            chapter("etats-unis", "Module 4 — Les États-Unis : société et puissance mondiale"),
            chapter("amerique-nord", "Module 4 — Le Canada et l'intégration nord-américaine"),
            chapter("amerique-latine", "Module 4 — L'Amérique latine : dynamiques et intégrations régionales"),
            chapter("bresil", "Module 4 — Le Brésil et les puissances émergentes d'Amérique"),
            chapter("asie-dynamiques", "Module 4 — L'Asie dans la mondialisation : dynamiques régionales"),
            chapter("chine", "Module 4 — La Chine, puissance mondiale"),
            chapter("inde", "Module 4 — L'Inde, puissance émergente"),
            chapter("japon-npi", "Module 4 — Le Japon et les nouveaux pays industrialisés d'Asie"),
            chapter("asie-sud-est", "Module 4 — L'Asie du Sud-Est et les enjeux maritimes"),
            chapter("methode", "Méthode : dissertation et croquis de géopolitique"),
        ]
    }

    private enum Lettres {
        static let annee1: [TrackChapter] = [
            chapter("methode-dissertation", "Méthode de la dissertation de culture générale"),
            chapter("explication-texte", "Analyse et explication de texte"),
            chapter("antiquite", "L'Antiquité et ses héritages"),
            chapter("courants-litteraires", "Les grands courants littéraires"),
            chapter("theatre", "Le théâtre : formes et enjeux"),
            chapter("roman", "Le roman et le récit"),
            chapter("poesie", "La poésie"),
            chapter("essai", "L'essai et la littérature d'idées"),
            chapter("mythes", "Mythes et grands récits fondateurs"),
            chapter("rhetorique", "Rhétorique et argumentation"),
            chapter("arts", "Repères artistiques : peinture, musique, cinéma"),
            chapter("carnet-references", "Constitution d'un carnet de références littéraires"),
        ]

        static let annee2: [TrackChapter] = [
            chapter("theme-annee", "Le thème de l'année : approche littéraire"),
            chapter("auteurs-reference", "Œuvres et auteurs de référence sur le thème"),
            chapter("theme-theatre", "Le thème dans le théâtre"),
            chapter("theme-roman", "Le thème dans le roman"),
            chapter("theme-poesie", "Le thème dans la poésie"),
            chapter("theme-essai", "Le thème dans l'essai et la littérature d'idées"),
            chapter("theme-arts", "Le thème dans les arts et le cinéma"),
            chapter("corpus-citations", "Constitution d'un corpus de citations"),
            chapter("methode-dissertation", "Méthode de la dissertation"),
            chapter("entrainement-ecrit", "Entraînement en temps limité"),
        ]
    }

    private enum Philosophie {
        static let annee1: [TrackChapter] = [
            chapter("methode-dissertation", "Méthode de la dissertation de philosophie"),
            chapter("problematisation", "Analyse et problématisation d'une notion"),
            chapter("philosophie-antique", "Repères antiques : Platon, Aristote, stoïciens, épicuriens"),
            chapter("philosophie-moderne", "Repères modernes : Descartes, Spinoza, Hume, Kant"),
            chapter("philosophie-19e", "Repères du XIXe siècle : Hegel, Marx, Nietzsche, Freud"),
            chapter("philosophie-contemporaine", "Repères contemporains : phénoménologie et philosophie analytique"),
            chapter("connaissance", "La connaissance, la vérité et la science"),
            chapter("sujet-conscience", "Le sujet, la conscience et l'inconscient"),
            chapter("desir-passions", "Le désir et les passions"),
            chapter("liberte", "La liberté et le déterminisme"),
            chapter("morale-devoir", "La morale et le devoir"),
            chapter("justice-droit", "La justice et le droit"),
            chapter("politique-etat", "La politique, l'État et le pouvoir"),
            chapter("travail", "Le travail et l'échange"),
            chapter("technique", "La technique et le progrès"),
            chapter("nature-culture", "La nature et la culture"),
            chapter("langage", "Le langage"),
            chapter("art-beau", "L'art et le beau"),
            chapter("temps-histoire", "Le temps et l'histoire"),
            chapter("autrui", "Autrui et la reconnaissance"),
            chapter("carnet-references", "Constitution d'un carnet de références philosophiques"),
        ]

        static let annee2: [TrackChapter] = [
            chapter("theme-annee", "Le thème de l'année : enjeux philosophiques"),
            chapter("problematisation", "Problématisation et distinctions conceptuelles"),
            chapter("theme-antiquite", "Le thème chez les Anciens"),
            chapter("theme-moderne", "Le thème dans la philosophie moderne"),
            chapter("theme-contemporain", "Le thème dans la philosophie contemporaine"),
            chapter("concepts-cles", "Les concepts clés du thème"),
            chapter("objections", "Objections, limites et débats autour du thème"),
            chapter("corpus-references", "Constitution d'un corpus de références philosophiques"),
            chapter("methode-dissertation", "Méthode de la dissertation"),
            chapter("entrainement-ecrit", "Entraînement en temps limité"),
            chapter("preparation-oral", "Préparation aux oraux"),
        ]
    }

    private enum Langues {
        static let anglaisAnnee1: [TrackChapter] = [
            chapter("temps-aspects", "Grammaire : temps et aspects"),
            chapter("modaux", "Grammaire : modaux et expression de l'hypothèse"),
            chapter("voix-passive", "Grammaire : voix passive et structures complexes"),
            chapter("syntaxe", "Syntaxe de la phrase complexe"),
            chapter("vocabulaire-presse", "Vocabulaire de la presse et de l'actualité"),
            chapter("vocabulaire-economie", "Vocabulaire : économie et entreprise"),
            chapter("vocabulaire-societe", "Vocabulaire : société et politique"),
            chapter("vocabulaire-sciences", "Vocabulaire : sciences et technologies"),
            chapter("version", "Version : méthode et entraînement"),
            chapter("theme-grammatical", "Thème grammatical"),
            chapter("comprehension-orale", "Compréhension orale"),
            chapter("essai", "Essai argumenté"),
            chapter("colle", "Colle : présentation d'un article de presse"),
            chapter("civilisation-britannique", "Civilisation britannique : institutions et société"),
            chapter("civilisation-americaine", "Civilisation américaine : institutions et société"),
        ]

        static let anglaisAnnee2: [TrackChapter] = [
            chapter("grammaire-revisions", "Grammaire : révisions et points difficiles"),
            chapter("vocabulaire-presse", "Vocabulaire de la presse et de l'actualité"),
            chapter("vocabulaire-thematique", "Vocabulaire thématique : dossiers du concours"),
            chapter("version", "Version : textes littéraires et journalistiques"),
            chapter("theme-suivi", "Thème suivi"),
            chapter("theme-grammatical", "Thème grammatical"),
            chapter("synthese", "Synthèse de documents"),
            chapter("essai", "Essai argumenté et expression écrite"),
            chapter("comprehension-orale", "Compréhension orale et actualité"),
            chapter("colle", "Colle : revue de presse et discussion"),
            chapter("civilisation", "Civilisation du monde anglophone : dossiers de fond"),
            chapter("entrainement-ecrit", "Entraînement aux épreuves écrites du concours"),
            chapter("entrainement-oral", "Entraînement aux épreuves orales"),
        ]

        static let lv2Annee1: [TrackChapter] = [
            chapter("grammaire-bases", "Grammaire et conjugaison : bases"),
            chapter("grammaire-syntaxe", "Grammaire : syntaxe et subordination"),
            chapter("vocabulaire-quotidien", "Vocabulaire courant et de l'actualité"),
            chapter("vocabulaire-thematique", "Vocabulaire thématique"),
            chapter("comprehension-ecrite", "Compréhension écrite"),
            chapter("comprehension-orale", "Compréhension orale"),
            chapter("version", "Version"),
            chapter("theme", "Thème"),
            chapter("expression-ecrite", "Expression écrite"),
            chapter("expression-orale", "Expression orale et colle"),
            chapter("civilisation", "Civilisation de l'aire linguistique"),
        ]

        static let lv2Annee2: [TrackChapter] = [
            chapter("grammaire-revisions", "Grammaire : révisions et points difficiles"),
            chapter("vocabulaire-actualite", "Vocabulaire de l'actualité et de la presse"),
            chapter("vocabulaire-thematique", "Vocabulaire thématique : dossiers du concours"),
            chapter("version", "Version"),
            chapter("theme", "Thème"),
            chapter("essai", "Essai et expression écrite"),
            chapter("comprehension-orale", "Compréhension orale"),
            chapter("colle", "Colle : présentation d'article et discussion"),
            chapter("civilisation", "Civilisation : dossiers de fond"),
            chapter("entrainement-concours", "Entraînement aux épreuves du concours"),
        ]
    }

    // MARK: MPSI / MP / PSI (programmes condensés aux matières principales)

    private static func mpsiSubjects() -> [TrackSubject] {
        [
            TrackSubject(
                id: "maths",
                name: "Mathématiques",
                fullName: nil,
                icon: "function",
                chapters: [
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
                    chapter("geometrie", "Géométrie du plan et de l'espace", domain: "Géométrie"),
                    chapter("denombrement", "Dénombrement", domain: "Probabilités"),
                    chapter("probabilites", "Probabilités sur un univers fini", domain: "Probabilités"),
                    chapter("variables-aleatoires", "Variables aléatoires sur un univers fini", domain: "Probabilités"),
                ]
            ),
            TrackSubject(
                id: "physique",
                name: "Physique",
                fullName: nil,
                icon: "atom",
                chapters: [
                    chapter("mesures-incertitudes", "Mesures, incertitudes et méthodes expérimentales"),
                    chapter("oscillateur-harmonique", "Oscillateur harmonique"),
                    chapter("propagation-signal", "Propagation d'un signal et ondes progressives"),
                    chapter("interferences", "Superposition et interférences d'ondes"),
                    chapter("optique-lois", "Optique géométrique : lois de Snell-Descartes"),
                    chapter("lentilles", "Lentilles minces et instruments d'optique"),
                    chapter("monde-quantique", "Introduction au monde quantique"),
                    chapter("arqs", "Circuits électriques dans l'ARQS"),
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
                    chapter("systemes-thermo", "Descriptions macroscopique et microscopique d'un système"),
                    chapter("premier-principe", "Premier principe de la thermodynamique"),
                    chapter("second-principe", "Second principe et entropie"),
                    chapter("machines-thermiques", "Machines thermiques"),
                    chapter("corps-diphase", "Corps pur diphasé et changements d'état"),
                    chapter("champ-magnetique", "Champ magnétique et forces de Laplace"),
                    chapter("induction", "Induction électromagnétique et circuit mobile"),
                ]
            ),
            TrackSubject(
                id: "chimie",
                name: "Chimie",
                fullName: nil,
                icon: "drop",
                chapters: [
                    chapter("transformations", "Transformations de la matière et états physiques"),
                    chapter("avancement", "Description d'un système physico-chimique et avancement"),
                    chapter("equilibre", "Évolution vers un état final : équilibre et quotient réactionnel"),
                    chapter("cinetique", "Cinétique chimique macroscopique"),
                    chapter("mecanismes", "Mécanismes réactionnels"),
                    chapter("atome", "Structure de l'atome et classification périodique"),
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
            ),
            TrackSubject(
                id: "informatique",
                name: "Informatique",
                fullName: nil,
                icon: "chevron.left.forwardslash.chevron.right",
                chapters: [
                    chapter("python-bases", "Prise en main de Python : types et variables"),
                    chapter("structures-controle", "Structures de contrôle : tests et boucles"),
                    chapter("fonctions", "Fonctions, portée et documentation"),
                    chapter("listes", "Listes, tuples et chaînes de caractères"),
                    chapter("dictionnaires", "Dictionnaires et ensembles"),
                    chapter("recursivite", "Récursivité"),
                    chapter("correction-terminaison", "Spécification, correction et terminaison"),
                    chapter("complexite", "Complexité d'un algorithme"),
                    chapter("tris-elementaires", "Tris élémentaires : insertion et sélection"),
                    chapter("tris-recursifs", "Tris récursifs : fusion et tri rapide"),
                    chapter("dichotomie", "Recherche dichotomique"),
                    chapter("diviser-regner", "Diviser pour régner"),
                    chapter("gloutons", "Algorithmes gloutons"),
                    chapter("representation-nombres", "Représentation des nombres en machine"),
                    chapter("zeros-fonctions", "Résolution approchée d'équations : dichotomie et Newton"),
                    chapter("integration-numerique", "Calcul approché d'intégrales"),
                    chapter("euler", "Résolution numérique d'équations différentielles : méthode d'Euler"),
                    chapter("bases-de-donnees", "Bases de données relationnelles et algèbre relationnelle"),
                    chapter("sql", "Requêtes SQL"),
                    chapter("ocaml", "Programmation fonctionnelle en OCaml"),
                    chapter("types-construits", "Types construits et filtrage de motifs"),
                    chapter("recursivite-terminale", "Récursivité terminale et preuve de programmes"),
                    chapter("structures-persistantes", "Listes et structures de données persistantes"),
                    chapter("arbres", "Arbres binaires et arbres binaires de recherche"),
                    chapter("piles-files", "Piles, files et structures mutables"),
                    chapter("graphes", "Graphes : représentations et parcours"),
                    chapter("logique-propositionnelle", "Logique propositionnelle et satisfiabilité"),
                ]
            ),
        ]
    }

    private static func mpSubjects() -> [TrackSubject] {
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

    private static func psiSubjects() -> [TrackSubject] {
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
