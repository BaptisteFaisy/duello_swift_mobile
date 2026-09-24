//
//  ProgPrereqMpsiMpGraph+Topics.swift
//  Duello
//
//  Phase 0 (socle) — section extraite de `ProgPrereqMpsiMpGraph.swift` :
//  la table `CHAPTER_TOPICS` de src/data/mpsiMpPrerequisiteGraph.ts (RN), 57
//  entrées, portée à l'identique (données, motifs, ordre).
//
//  Découpage (24/09/2026) : table déplacée ici pour respecter le ratchet Hermes
//  (≤ 500 lignes/fichier) — même enum, `static let`.
//
//  `topics` est du câblage interne (partagé entre ce fichier et le fichier
//  principal) ; il ne fait pas partie du contrat gelé.
//
//  Cible : iOS 16, aucune dépendance externe.
//
import Foundation

extension ProgPrereqMpsiMpGraph {

    /// Notion que chaque chapitre laisse reconnaître dans le texte d'une question.
    ///
    /// Un motif doit désigner la notion elle-même, jamais une notation ni un mot
    /// dont le sens change de chapitre en chapitre. Les chapitres absents de
    /// cette table le sont volontairement :
    ///
    /// - `logique` et `calcul-derivation` sont acquis dès les premières semaines
    ///   et figurent en amont de presque tout : les ajouter ne distinguerait rien ;
    /// - `fonctions-usuelles` a été écarté du côté approfondi après relecture,
    ///   parce que « exponentielle » et « logarithme » désignent une loi de
    ///   probabilité plus souvent qu'une fonction ; la même prudence s'applique ici ;
    /// - `problemes-transversaux` est un chapitre porteur, pas une notion.
    static let topics: [Topic] = [
        // Première année.
        Topic(
            year: .first, chapterId: "ensembles",
            name: "Ensembles, applications et relations",
            // `bijecti` a été retiré : dans les corrigés, « f réalise une bijection de
            // ]0;+∞[ sur ℝ » désigne le théorème de la bijection, qui relève de la
            // continuité. Sur 74 déclenchements, aucun ne visait une application entre
            // ensembles abstraits.
            question: #"injecti|surjecti|image r[ée]ciproque|relation d.[ée]quivalence"#),
        Topic(
            year: .first, chapterId: "sommes-produits",
            name: "Sommes, produits et coefficients binomiaux",
            question: #"coefficients? binomia|bin[oô]me de Newton|somme t[ée]lescopique|produit t[ée]lescopique"#),
        Topic(
            year: .first, chapterId: "complexes",
            name: "Nombres complexes et trigonométrie",
            question: #"nombres? complexes?|racines? n-i[eè]mes? de l.unit[ée]|forme trigonom[ée]trique|module et argument"#),
        Topic(
            year: .first, chapterId: "equations-differentielles",
            name: "Équations différentielles linéaires",
            question: #"[ée]quation diff[ée]rentielle|solution g[ée]n[ée]rale|variation de la constante"#),
        Topic(
            year: .first, chapterId: "reels",
            name: "Nombres réels et borne supérieure",
            question: #"borne sup[ée]rieure|borne inf[ée]rieure|partie enti[eè]re"#),
        Topic(
            year: .first, chapterId: "suites",
            name: "Suites numériques",
            question: #"(?:la|une|cette)\s+suite|suite r[ée]currente|suite extraite|suites? adjacentes?"#),
        Topic(
            year: .first, chapterId: "limites-continuite",
            name: "Limites et continuité",
            question: #"continuit[ée]|prolongement par continuit[ée]|valeurs interm[ée]diaires|uniform[ée]ment continue|r[ée]alise une bijection|th[ée]or[eè]me de la bijection"#),
        Topic(
            year: .first, chapterId: "calcul-derivation",
            name: "Techniques fondamentales de calcul : dérivation et primitives",
            // Ce chapitre était d'abord exclu comme « trop précoce pour distinguer quoi
            // que ce soit ». La lecture des corrigés l'a réhabilité : « f est dérivable
            // et f ′(x) = … » y est constant, et l'attribuer à `derivabilite` nommait le
            // mauvais chapitre dans le détail du badge. Étant en amont de la dérivabilité,
            // de l'intégration et des équations différentielles, il reste sans effet là
            // où il n'apprend rien.
            question: #"d[ée]riv[ée]e|d[ée]rivable|primitive"#),
        Topic(
            year: .first, chapterId: "derivabilite",
            name: "Dérivabilité et théorème des accroissements finis",
            // Seuls les théorèmes du chapitre le désignent : « dérivable » seul décrit
            // le plus souvent l'espace de fonctions dans lequel on travaille.
            question: #"accroissements finis|th[ée]or[eè]me de Rolle|th[ée]or[eè]me de la limite de la d[ée]riv[ée]e"#),
        Topic(
            year: .first, chapterId: "analyse-asymptotique",
            name: "Analyse asymptotique et développements limités",
            question: #"d[ée]veloppement limit[ée]|[ée]quivalent [aà]|n[ée]gligeable|d[ée]veloppement asymptotique"#),
        Topic(
            year: .first, chapterId: "taylor",
            name: "Formules de Taylor",
            question: #"formule de Taylor|Taylor-Young|Taylor-Lagrange|reste int[ée]gral"#),
        Topic(
            year: .first, chapterId: "integration",
            name: "Intégration sur un segment",
            question: #"int[ée]grale|int[ée]gration par parties|somme de Riemann|changement de variable"#),
        Topic(
            year: .first, chapterId: "series-numeriques",
            name: "Procédés sommatoires : séries numériques et familles sommables",
            // « s[ée]rie » seul attrapait « têtes de série » dans les exercices de
            // probabilités. Le motif exige donc le sens mathématique.
            question: #"s[ée]ries? (?:num[ée]rique|convergente|divergente|harmonique|g[ée]om[ée]trique|de terme g[ée]n[ée]ral|altern[ée]e)|nature de la s[ée]rie|somme partielle|crit[eè]re de comparaison|famille sommable"#),
        Topic(
            year: .first, chapterId: "fonctions-deux-variables",
            name: "Fonctions de deux variables",
            question: #"d[ée]riv[ée]es? partielles?|fonction de deux variables|\bgradient\b"#),
        Topic(
            year: .first, chapterId: "arithmetique",
            name: "Arithmétique dans Z",
            question: #"divisib|\bpgcd\b|\bppcm\b|nombres? premiers?|congru|B[ée]zout"#),
        Topic(
            year: .first, chapterId: "structures-algebriques",
            name: "Structures algébriques : groupes, anneaux, corps",
            question: #"\bgroupe\b|\banneau\b|sous-groupe|morphisme de groupes|\bid[ée]al\b"#),
        Topic(
            year: .first, chapterId: "polynomes",
            name: "Polynômes",
            question: #"polyn[oô]me|racine multiple|scind[ée]"#),
        Topic(
            year: .first, chapterId: "fractions-rationnelles",
            name: "Fractions rationnelles",
            question: #"fraction rationnelle|[ée]l[ée]ments simples|\bp[oô]les?\b"#),
        Topic(
            year: .first, chapterId: "espaces-vectoriels",
            name: "Espaces vectoriels et sous-espaces",
            question: #"espace vectoriel|sous-espace|famille g[ée]n[ée]ratrice|combinaison lin[ée]aire"#),
        Topic(
            year: .first, chapterId: "dimension",
            name: "Familles libres, bases et dimension",
            // « rang » seul désignait le rang d'une suite (« à partir de quel rang »)
            // aussi souvent que celui d'une application linéaire.
            question: #"dimension|famille libre|rang de (?:la matrice|l.application|f\b)|th[ée]or[eè]me du rang"#),
        Topic(
            year: .first, chapterId: "applications-lineaires",
            name: "Applications linéaires",
            question: #"application lin[ée]aire|endomorphisme|\bnoyau\b|\bKer\b|\bIm\b"#),
        Topic(
            year: .first, chapterId: "matrices",
            name: "Matrices et calcul matriciel",
            // « inversible » qualifie une application linéaire ou une fonction aussi
            // souvent qu'une matrice : c'était le motif le plus déclenché de la table, et
            // le plus faux. Seul le vocabulaire proprement matriciel subsiste. `trace`
            // exige un déterminant devant lui : « si on trace dans le plan complexe »
            // est le verbe tracer, pas la trace d'un endomorphisme.
            question: #"matrice|transpos[ée]|\btr\s*\(|(?:la|sa|une|de) trace\b"#),
        Topic(
            year: .first, chapterId: "systemes-lineaires",
            name: "Systèmes linéaires et pivot de Gauss",
            question: #"syst[eè]me lin[ée]aire|pivot de Gauss"#),
        Topic(
            year: .first, chapterId: "determinants",
            name: "Déterminants",
            question: #"d[ée]terminant|comatrice"#),
        Topic(
            year: .first, chapterId: "prehilbertiens",
            name: "Espaces préhilbertiens réels et espaces euclidiens",
            question: #"produit scalaire|orthonorm|orthogonal|Cauchy-Schwarz|projection orthogonale"#),
        Topic(
            year: .first, chapterId: "geometrie",
            name: "Géométrie du plan et de l’espace",
            question: #"produit vectoriel|barycentre"#),
        Topic(
            year: .first, chapterId: "denombrement",
            name: "Dénombrement",
            question: #"d[ée]nombr|\bcardinal\b|nombre de fa[çc]ons|arrangements?\b"#),
        Topic(
            year: .first, chapterId: "probabilites",
            name: "Probabilités sur un univers fini",
            question: #"probabilit[ée]|[ée]v[ée]nement|formule de Bayes|probabilit[ée]s? conditionnelle"#),
        Topic(
            year: .first, chapterId: "variables-aleatoires",
            name: "Variables aléatoires sur un univers fini",
            question: #"variable al[ée]atoire|esp[ée]rance|variance|loi binomiale|loi uniforme"#),
        // Deuxième année.
        Topic(
            year: .second, chapterId: "convexite",
            name: "Convexité",
            question: #"convexe|concave|convexit[ée]"#),
        Topic(
            year: .second, chapterId: "espaces-normes",
            name: "Espaces vectoriels normés",
            question: #"\bnormes?\b|espace vectoriel norm[ée]|boule (?:ouverte|ferm[ée]e)|normes? [ée]quivalentes"#),
        Topic(
            year: .second, chapterId: "topologie",
            name: "Topologie : ouverts, fermés, compacité et connexité",
            // « intervalle ouvert » et « intervalle fermé » appartiennent au vocabulaire
            // de première année : le motif exige une formulation topologique.
            question: #"\bcompacte?\b|connexe par arcs|adh[ée]rence|dense dans|(?:partie|ensemble)s? (?:ouvert|ferm[ée])"#),
        Topic(
            year: .second, chapterId: "series-numeriques",
            name: "Suites et séries numériques",
            question: #"s[ée]ries? (?:num[ée]rique|convergente|divergente|harmonique|g[ée]om[ée]trique|de terme g[ée]n[ée]ral|altern[ée]e)|nature de la s[ée]rie|somme partielle|crit[eè]re de d.Alembert|reste d.une s[ée]rie"#),
        Topic(
            year: .second, chapterId: "familles-sommables",
            name: "Familles sommables",
            question: #"famille sommable|sommation par paquets|th[ée]or[eè]me de Fubini"#),
        Topic(
            year: .second, chapterId: "suites-series-fonctions",
            name: "Suites et séries de fonctions : convergence uniforme",
            question: #"convergence uniforme|convergence simple|s[ée]rie de fonctions|suite de fonctions"#),
        Topic(
            year: .second, chapterId: "series-entieres",
            name: "Séries entières",
            question: #"s[ée]rie enti[eè]re|rayon de convergence|d[ée]veloppable en s[ée]rie enti[eè]re"#),
        Topic(
            year: .second, chapterId: "integration-intervalle",
            name: "Intégration sur un intervalle quelconque",
            question: #"int[ée]grale (?:impropre|g[ée]n[ée]ralis[ée]e|convergente)|int[ée]grabilit[ée]|int[ée]grable sur"#),
        Topic(
            year: .second, chapterId: "convergence-dominee",
            name: "Convergence dominée et intégrales à paramètre",
            question: #"convergence domin[ée]e|int[ée]grale [aà] param[eè]tre|d[ée]rivation sous le signe"#),
        Topic(
            year: .second, chapterId: "fonctions-vectorielles",
            name: "Fonctions vectorielles et arcs paramétrés",
            question: #"arc param[ée]tr[ée]|fonction vectorielle|courbe param[ée]tr[ée]e|longueur d.arc"#),
        Topic(
            year: .second, chapterId: "systemes-differentiels",
            name: "Équations différentielles linéaires et systèmes différentiels",
            question: #"syst[eè]me diff[ée]rentiel|[ée]quation diff[ée]rentielle|wronskien|r[ée]solvante"#),
        Topic(
            year: .second, chapterId: "calcul-differentiel",
            name: "Calcul différentiel et fonctions de plusieurs variables",
            // « différentielle » seul attrapait « équation différentielle », qui relève
            // des systèmes différentiels et non du calcul différentiel.
            question: #"diff[ée]rentiable|la diff[ée]rentielle|d[ée]riv[ée]es? partielles?|\bgradient\b|jacobien"#),
        Topic(
            year: .second, chapterId: "extrema",
            name: "Extrema et optimisation",
            question: #"extremum|extrema|maximum local|minimum local|points? critiques?"#),
        Topic(
            year: .second, chapterId: "structures-arithmetique",
            name: "Structures algébriques et arithmétique : compléments",
            question: #"\bid[ée]al\b|ordre d.un [ée]l[ée]ment|groupe cyclique"#),
        Topic(
            year: .second, chapterId: "algebre-lineaire",
            name: "Compléments d’algèbre linéaire : sommes directes et projecteurs",
            // « hyperplan » et « supplémentaire » s'apprennent en première année : les
            // rattacher à ce complément ferait passer pour non vue une notion acquise.
            question: #"somme directe|projecteur"#),
        Topic(
            year: .second, chapterId: "matrices-determinants",
            name: "Matrices et déterminants : compléments",
            question: #"matrice par blocs|comatrice"#),
        Topic(
            year: .second, chapterId: "valeurs-propres",
            name: "Réduction : valeurs propres et vecteurs propres",
            question: #"valeurs? propres?|vecteurs? propres?|\bspectre\b|polyn[oô]me caract[ée]ristique|sous-espace propre"#),
        Topic(
            year: .second, chapterId: "diagonalisation",
            name: "Diagonalisation et trigonalisation",
            question: #"diagonalis|trigonalis|semblable [aà]"#),
        Topic(
            year: .second, chapterId: "cayley-hamilton",
            name: "Polynômes d’endomorphismes et théorème de Cayley-Hamilton",
            question: #"Cayley-Hamilton|polyn[oô]me minimal|polyn[oô]me annulateur|lemme des noyaux"#),
        Topic(
            year: .second, chapterId: "prehilbertiens",
            name: "Espaces préhilbertiens réels : compléments",
            question: #"Gram-Schmidt|projection orthogonale|Cauchy-Schwarz"#),
        Topic(
            year: .second, chapterId: "euclidiens",
            name: "Espaces euclidiens et endomorphismes autoadjoints",
            question: #"autoadjoint|endomorphisme sym[ée]trique|th[ée]or[eè]me spectral|matrice sym[ée]trique r[ée]elle"#),
        Topic(
            year: .second, chapterId: "isometries",
            name: "Isométries et matrices orthogonales",
            question: #"isom[ée]trie|matrice orthogonale|groupe orthogonal"#),
        Topic(
            year: .second, chapterId: "denombrabilite",
            name: "Dénombrabilité",
            question: #"d[ée]nombrable"#),
        Topic(
            year: .second, chapterId: "espaces-probabilises",
            name: "Espaces probabilisés et probabilités discrètes",
            question: #"espace probabilis[ée]|\btribu\b|syst[eè]me complet d.[ée]v[ée]nements"#),
        Topic(
            year: .second, chapterId: "variables-discretes",
            name: "Variables aléatoires discrètes et lois usuelles",
            question: #"variable al[ée]atoire|loi de Poisson|loi g[ée]om[ée]trique|esp[ée]rance|variance"#),
        Topic(
            year: .second, chapterId: "couples-independance",
            name: "Couples de variables, indépendance et covariance",
            question: #"covariance|ind[ée]pendantes|loi conjointe|couple de variables"#),
        Topic(
            year: .second, chapterId: "fonctions-generatrices",
            name: "Fonctions génératrices",
            question: #"fonction g[ée]n[ée]ratrice|s[ée]rie g[ée]n[ée]ratrice"#),
        Topic(
            year: .second, chapterId: "concentration",
            name: "Inégalités de concentration et loi faible des grands nombres",
            question: #"in[ée]galit[ée] de Markov|Bienaym[ée]-Tchebychev|loi faible des grands nombres|concentration"#),
    ]
}
