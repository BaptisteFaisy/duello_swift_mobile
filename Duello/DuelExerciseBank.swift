import Foundation

// MARK: - Banque d'exos de défi : exos intégrés et tirage déterministe
// (port de data/duelExercises.ts et des fonctions de tirage de utils/duel.ts)

/// Banque des exos de « colle » servis aux défis, et tirage déterministe de
/// l'énoncé d'un match. Les modèles (`DuelExercise`, `ChallengeExerciseEntry`)
/// et la mise en forme vivent dans `DuelExerciseModels.swift`.
enum DuelExerciseBank {

    /// Exos intégrés, un par matière : l'adversaire simulé y a une copie
    /// pré-rédigée (`opponentProduction`) et un corrigé de référence
    /// (`solution`), dévoilés après le défi.
    static let DUEL_EXERCISES: [DuelExercise] = [
        DuelExercise(
            id: "maths-suite-homographique",
            subject: "Mathématiques",
            context: "Soit la suite (uₙ) définie par u₀ = 2 et uₙ₊₁ = (uₙ + 3) / (uₙ + 1).",
            questions: [
                DuelExercise.Question(id: "bonne-definition", prompt: "Montrer que la suite est bien définie et que uₙ > 0 pour tout n.", label: nil),
                DuelExercise.Question(id: "limite", prompt: "Déterminer sa limite éventuelle.", label: nil),
            ],
            opponentProduction: "On montre par récurrence que uₙ > 0 : c'est vrai pour u₀ = 2, et si uₙ > 0 alors uₙ + 1 > 0 donc uₙ₊₁ est bien défini et positif. La suite est donc bien définie et à valeurs positives. Si elle converge vers ℓ, alors ℓ = (ℓ + 3)/(ℓ + 1), soit ℓ² = 3, donc ℓ = √3.",
            solution: "1) Bonne définition et positivité (récurrence). Posons P(n) : « uₙ existe et uₙ > 0 ».\n• Initialisation : u₀ = 2 > 0.\n• Hérédité : si uₙ > 0, alors uₙ + 1 > 0, donc uₙ₊₁ = (uₙ + 3)/(uₙ + 1) est bien définie ; de plus uₙ + 3 > 0, donc uₙ₊₁ > 0.\nPar récurrence, (uₙ) est bien définie et uₙ > 0 pour tout n.\n\n2) Limite éventuelle. La fonction f : x ↦ (x + 3)/(x + 1) est continue sur ]0 ; +∞[. Si uₙ → ℓ ≥ 0, alors ℓ = (ℓ + 3)/(ℓ + 1), soit ℓ(ℓ + 1) = ℓ + 3, d'où ℓ² = 3. Comme ℓ ≥ 0, la seule limite possible est ℓ = √3.\n\nRemarque : ce calcul suppose la convergence. On l'établit en écrivant uₙ₊₁ − √3 = (1 − √3)(uₙ − √3)/(uₙ + 1) ; le rapport (√3 − 1)/(uₙ + 1) étant < 1, la suite est contractante et converge vers √3."
        ),
        DuelExercise(
            id: "physique-rc",
            subject: "Physique",
            context: "Un circuit RC série est soumis à un échelon de tension E à t = 0, le condensateur étant initialement déchargé.",
            questions: [
                DuelExercise.Question(id: "equation", prompt: "Établir l'équation différentielle vérifiée par u_C(t).", label: nil),
                DuelExercise.Question(id: "resolution", prompt: "Résoudre cette équation différentielle.", label: nil),
                DuelExercise.Question(id: "constante-temps", prompt: "Donner la constante de temps ainsi que l'allure de u_C(t).", label: nil),
            ],
            opponentProduction: "On applique la loi des mailles : E = R·i + u_C avec i = C·du_C/dt, donc RC·du_C/dt + u_C = E. En effet le courant traverse R et charge C. La solution est la somme d'un terme en e^(−t/τ) et de la solution particulière u_C = E. Comme le condensateur est déchargé à t = 0, on trouve finalement u_C(t) = E·(1 − e^(−t/τ)), avec τ = RC la constante de temps : la tension part de 0 et tend vers E.",
            solution: "1) Mise en équation. Loi des mailles : E = u_R + u_C = R·i + u_C, avec i = C·(du_C/dt) (le même courant traverse R et charge C). D'où :\nRC·(du_C/dt) + u_C = E.\n\n2) Résolution. Solution générale = solution homogène + solution particulière :\n• homogène : u_C,h(t) = A·e^(−t/RC) ;\n• particulière (régime permanent) : u_C,p = E.\nDonc u_C(t) = E + A·e^(−t/RC). Condition initiale : le condensateur est déchargé, u_C(0) = 0, d'où A = −E.\nu_C(t) = E·(1 − e^(−t/τ)), avec τ = RC.\n\n3) Constante de temps et allure. τ = RC (en secondes). u_C part de 0, croît de façon exponentielle et tend vers E. À t = τ, u_C ≈ 0,63·E ; le régime permanent (u_C ≈ E) est pratiquement atteint au bout de 5τ."
        ),
        DuelExercise(
            id: "chimie-dosage",
            subject: "Chimie",
            context: "On dose 20,0 mL d'acide éthanoïque de concentration inconnue par de la soude à 0,10 mol/L. L'équivalence est atteinte pour 15,0 mL versés.",
            questions: [
                DuelExercise.Question(id: "concentration", prompt: "Déterminer la concentration de l'acide.", label: nil),
                DuelExercise.Question(id: "ph-demi-equivalence", prompt: "Déterminer le pH à la demi-équivalence (pKa = 4,8).", label: nil),
            ],
            opponentProduction: "À l'équivalence, tout l'acide a réagi, donc n(acide) = n(soude) versée : C·20,0 = 0,10 × 15,0, d'où C = 0,075 mol/L. Comme il s'agit d'un acide faible dosé par une base forte, à la demi-équivalence on a [AH] = [A⁻], donc le pH = pKa = 4,8. On conclut C = 0,075 mol/L et pH = 4,8 à la demi-équivalence.",
            solution: "1) Concentration de l'acide. La réaction de dosage acide faible / base forte est totale et de stœchiométrie 1:1. À l'équivalence, les réactifs ont été introduits en proportions stœchiométriques : n(AH)initial = n(OH⁻) versé = C_b·V_éq = 0,10 × 15,0×10⁻³ = 1,5×10⁻³ mol.\nD'où C_a = n(AH)/V_a = 1,5×10⁻³ / 20,0×10⁻³ = 7,5×10⁻² mol/L, soit 0,075 mol/L.\n\n2) pH à la demi-équivalence. À la demi-équivalence, la moitié de l'acide a été transformée en sa base conjuguée : [AH] = [A⁻]. La relation pH = pKa + log([A⁻]/[AH]) donne alors pH = pKa = 4,8.\n\nConclusion : C_a = 0,075 mol/L et pH = 4,8 à la demi-équivalence."
        ),
        DuelExercise(
            id: "info-tri",
            subject: "Informatique",
            context: nil,
            questions: [
                DuelExercise.Question(id: "est-triee", prompt: "Écrire une fonction qui teste si une liste d'entiers est triée par ordre croissant, et en donner la complexité.", label: nil),
                DuelExercise.Question(id: "tri-insertion", prompt: "Proposer un tri par insertion.", label: nil),
                DuelExercise.Question(id: "complexite-pire-cas", prompt: "Justifier sa complexité dans le pire cas.", label: nil),
            ],
            opponentProduction: "def est_triee(t):\n    for i in range(len(t) - 1):\n        if t[i] > t[i+1]:\n            return False\n    return True\nCette fonction parcourt la liste une fois, donc sa complexité est en O(n). Le tri par insertion est en O(n²) dans le pire cas car chaque élément peut être comparé à tous les précédents.",
            solution: "1) Test de tri (parcours simple).\ndef est_triee(t):\n    for i in range(len(t) - 1):\n        if t[i] > t[i + 1]:\n            return False\n    return True\nLa fonction effectue au plus n − 1 comparaisons : complexité O(n).\n\n2) Tri par insertion.\ndef tri_insertion(t):\n    for i in range(1, len(t)):\n        x = t[i]\n        j = i - 1\n        while j >= 0 and t[j] > x:\n            t[j + 1] = t[j]\n            j = j - 1\n        t[j + 1] = x\n    return t\n\n3) Complexité au pire cas. Le pire cas est une liste triée par ordre décroissant : à l'étape i, l'élément inséré est comparé et décalé sur les i précédents. Le nombre total d'opérations vaut 1 + 2 + … + (n − 1) = n(n − 1)/2, soit une complexité en O(n²)."
        ),
        DuelExercise(
            id: "francais-philo-desir",
            subject: "Français-Philosophie",
            context: "Dissertation express : « Faut-il se méfier de ses désirs ? »",
            questions: [
                DuelExercise.Question(id: "problematique", prompt: "Dégage une problématique claire.", label: nil),
                DuelExercise.Question(id: "plan", prompt: "Propose un plan argumenté en deux ou trois parties.", label: nil),
            ],
            opponentProduction: "Le désir naît d'un manque : il semble d'abord une servitude, car il nous rend dépendants de ce que nous n'avons pas. En effet, un désir illimité peut asservir. Problématique : faut-il fuir le désir pour être libre, ou l'assumer comme moteur de l'existence ? On peut ainsi opposer les dangers du désir illimité à l'idée que tout projet humain suppose de désirer. On conclut qu'il faut moins éteindre le désir que l'ordonner par la raison.",
            solution: "Analyse du sujet. « Se méfier » suppose un danger possible du désir ; « ses » désirs engage le rapport à soi. L'enjeu est de savoir si le désir est une menace pour le sujet ou la source même de son existence.\n\nProblématique. Le désir, parce qu'il naît d'un manque et peut nous asservir, doit-il être tenu en suspicion, ou faut-il y reconnaître le moteur légitime de toute vie humaine ?\n\nPlan proposé.\nI. Il faut se méfier de ses désirs : illimités, ils engendrent souffrance et servitude (le tonneau percé des Danaïdes chez Platon ; la critique des passions chez Épicure et les stoïciens).\nII. Mais le désir est constitutif de l'homme : sans lui, ni action, ni projet, ni joie (Spinoza : le désir est « l'essence même de l'homme »).\nIII. Dépassement : il s'agit moins d'éteindre le désir que de l'éduquer par la raison, en distinguant les désirs qui accroissent notre puissance d'agir de ceux qui nous aliènent.\n\nConclusion : se méfier non du désir en soi, mais de son excès et de son aveuglement."
        ),
        DuelExercise(
            id: "anglais-social-media",
            subject: "Anglais",
            context: "Essay (about 150 words): 'Social media does more harm than good to teenagers.'",
            questions: [
                DuelExercise.Question(id: "essay", prompt: "Discuss both sides and give your own opinion in a short conclusion.", label: nil),
            ],
            opponentProduction: "Social media clearly has downsides for teenagers, because it can damage self-esteem and encourage constant comparison with others. However, it also helps them stay connected with friends and access useful information quickly. Therefore, the effect is not the same for everyone. In conclusion, I believe the impact depends far more on how it is used than on the technology itself.",
            solution: "Model answer (~150 words).\nSocial media plays a central role in teenagers' lives, and its effects are widely debated. On the one hand, it can be harmful: constant exposure to idealised images fuels anxiety, lowers self-esteem and encourages endless comparison. Cyberbullying and screen addiction are also serious concerns.\nOn the other hand, social media has clear benefits. It helps young people stay in touch with friends, discover new interests, and access information or support they might not find elsewhere. It can even give a voice to those who feel isolated.\nIn my opinion, social media is neither good nor bad in itself. What matters is how it is used: with balance and critical thinking, it becomes a useful tool; used excessively and uncritically, it can indeed do more harm than good. Education and self-awareness are therefore the keys to making it a positive force."
        ),
        DuelExercise(
            id: "esh-croissance",
            subject: "ESH",
            context: "Dans quelle mesure la croissance économique est-elle compatible avec la préservation de l'environnement ?",
            questions: [
                DuelExercise.Question(id: "problematique", prompt: "Dégage une problématique.", label: nil),
                DuelExercise.Question(id: "plan", prompt: "Propose un plan structuré.", label: nil),
            ],
            opponentProduction: "La croissance repose historiquement sur une consommation croissante d'énergie et de ressources, si bien qu'elle entre en tension avec l'environnement, car elle génère des externalités négatives comme la pollution. Problématique : peut-on découpler la croissance de la dégradation écologique ? On peut ainsi opposer la croissance destructrice à une croissance verte portée par l'innovation et la régulation publique. On conclut qu'un découplage n'est possible que sous conditions.",
            solution: "Analyse du sujet. La croissance désigne l'augmentation durable de la production, généralement mesurée par le PIB réel. La préservation de l'environnement suppose de maintenir les écosystèmes, le climat et les ressources naturelles dans un état compatible avec les besoins présents et futurs. Le terme « compatible » n'impose donc ni une opposition absolue ni une harmonie spontanée. Enfin, « dans quelle mesure » invite à identifier les conditions et les limites d'une éventuelle conciliation.\n\nProblématique. Alors que la croissance s'est historiquement construite sur l'exploitation croissante des ressources et des énergies fossiles, le progrès technique et l'action publique peuvent-ils la rendre soutenable, ou les limites planétaires imposent-elles de renoncer à l'objectif même d'une hausse continue de la production ?\n\nI. La croissance économique exerce spontanément une forte pression sur l'environnement.\n\nA. Produire davantage accroît en principe les prélèvements et les rejets. L'environnement étant en partie un bien commun sans prix, les entreprises et les consommateurs ne supportent pas tout le coût social de leurs décisions : ce sont des externalités négatives. L'industrialisation fondée sur le charbon puis le pétrole illustre ce lien entre hausse du PIB, émissions de gaz à effet de serre et pollution.\n\nB. La croissance se heurte à des limites physiques. Certaines ressources sont épuisables, tandis que les écosystèmes n'absorbent les déchets que jusqu'à un certain seuil. Le rapport Meadows, Les Limites à la croissance (1972), montre qu'une progression exponentielle de la production et de la population ne peut se poursuivre indéfiniment dans un monde fini. L'urgence climatique et l'érosion de la biodiversité confirment que le capital naturel n'est pas toujours substituable par du capital technique.\n\nTransition. Ce constat historique ne prouve toutefois pas qu'une unité supplémentaire de PIB doive toujours provoquer autant de dommages : la composition de la croissance et les techniques employées peuvent évoluer.\n\nII. L'innovation et la transformation de l'économie peuvent réduire l'empreinte écologique de la croissance.\n\nA. Le progrès technique améliore l'efficacité énergétique et matérielle. Les énergies renouvelables, l'isolation des bâtiments, l'électrification des usages ou l'économie circulaire permettent de produire une même valeur avec moins de ressources et d'émissions. On parle de découplage relatif lorsque l'impact environnemental augmente moins vite que le PIB, et de découplage absolu lorsqu'il diminue alors que le PIB progresse.\n\nB. La tertiarisation et l'innovation peuvent orienter la création de valeur vers des activités moins matérielles. La courbe environnementale de Kuznets suggère qu'au-delà d'un certain niveau de revenu, la demande de qualité environnementale, la réglementation et les technologies propres peuvent faire diminuer certaines pollutions. Plusieurs économies avancées ont ainsi réduit leurs émissions territoriales tout en continuant à croître.\n\nTransition. Ces améliorations ne suffisent pourtant pas à établir une compatibilité globale : elles peuvent être annulées par l'augmentation des volumes consommés ou masquer le transfert des activités polluantes à l'étranger.\n\nIII. La compatibilité n'est possible que sous des conditions politiques exigeantes et demeure incertaine.\n\nA. Les pouvoirs publics doivent corriger les défaillances du marché. Une taxe carbone inspirée du principe pollueur-payeur internalise l'externalité ; des quotas échangeables fixent un plafond global ; les normes interdisent les techniques les plus nocives. L'État peut également financer la recherche et orienter l'innovation, car les entreprises privées n'en captent pas tous les bénéfices collectifs.\n\nB. Il faut juger le découplage à l'échelle mondiale et en tenant compte de l'effet rebond. Un gain d'efficacité qui réduit le coût d'un usage peut en accroître la consommation ; de plus, les émissions importées ne figurent pas dans les inventaires territoriaux. La croissance verte n'est donc crédible que si la baisse de l'empreinte totale est assez rapide pour respecter les limites planétaires. À défaut, la sobriété, la modification des modes de consommation et le recours à des indicateurs complémentaires au PIB deviennent indispensables.\n\nConclusion. La croissance n'est pas spontanément compatible avec la préservation de l'environnement. Une conciliation reste envisageable si un découplage absolu, rapide et mondial est organisé par l'innovation, la réglementation et la sobriété. Elle doit cependant être évaluée à partir de l'empreinte écologique réelle, et non de la seule hausse du PIB."
        ),
        DuelExercise(
            id: "hgg-frontieres",
            subject: "HGG",
            context: "La mondialisation conduit-elle à l’effacement des frontières ?",
            questions: [
                DuelExercise.Question(id: "problematique", prompt: "Dégage une problématique.", label: nil),
                DuelExercise.Question(id: "plan", prompt: "Propose un plan structuré.", label: nil),
            ],
            opponentProduction: "La mondialisation intensifie les flux de marchandises, de capitaux, d'informations et de personnes, ce qui rend certaines frontières plus faciles à franchir. Pourtant, les États continuent de contrôler leurs territoires et renforcent parfois leurs frontières face aux crises migratoires ou géopolitiques. Problématique : la multiplication des flux fait-elle disparaître les frontières ou transforme-t-elle leurs fonctions ? On peut montrer qu'elles s'ouvrent de manière sélective, puis qu'elles restent des instruments majeurs de souveraineté et de différenciation.",
            solution: "Analyse du sujet. La mondialisation désigne l'intensification et la mise en réseau des échanges à l'échelle mondiale. Une frontière est à la fois une limite juridique de souveraineté, un dispositif de contrôle et une interface entre deux territoires. Parler d'« effacement » suppose donc davantage qu'une simple hausse des flux : il faudrait que les limites étatiques perdent leur fonction. Il faut distinguer la disparition des frontières de leur ouverture, de leur déplacement ou de leur transformation.\n\nProblématique. L'accélération des flux transnationaux rend-elle les frontières étatiques obsolètes, ou renforce-t-elle au contraire leur rôle de filtre en les recomposant selon les territoires, les acteurs et la nature des circulations ?\n\nI. La mondialisation donne d'abord l'image d'un monde plus ouvert, dans lequel les frontières s'atténuent.\n\nA. La libéralisation des échanges réduit de nombreux obstacles. Les accords du GATT puis l'OMC ont abaissé les droits de douane, tandis que les firmes transnationales organisent des chaînes de valeur qui traversent plusieurs États. Un bien peut ainsi être conçu aux États-Unis, assemblé en Chine avec des composants asiatiques, puis vendu dans le monde entier : la frontière ne bloque plus la production, elle devient un point de passage.\n\nB. Les intégrations régionales et les réseaux numériques relativisent aussi la distance frontalière. Dans l'espace Schengen, les contrôles aux frontières intérieures ont été supprimés pour les personnes, tandis que le marché unique facilite la circulation des biens, des services et des capitaux. Internet et les flux financiers fonctionnant en temps réel nourrissent l'idée d'un « village global » formulée par Marshall McLuhan.\n\nTransition. Cependant, la fluidité ne concerne ni tous les flux ni tous les espaces. L'ouverture observée pour les capitaux ou les marchandises ne vaut pas nécessairement pour les personnes, et elle repose toujours sur des décisions politiques réversibles.\n\nII. Les frontières restent des instruments majeurs de souveraineté et peuvent même être renforcées.\n\nA. Les États continuent de sélectionner les entrées sur leur territoire. Les politiques de visas, les contrôles migratoires et les dispositifs douaniers montrent que la frontière conserve une fonction de filtrage. La frontière entre les États-Unis et le Mexique laisse circuler d'immenses flux commerciaux dans le cadre de l'ACEUM, tout en étant fortement sécurisée contre certaines migrations : elle est ouverte et fermée à la fois selon le flux considéré.\n\nB. Les crises réactivent la frontière comme outil de protection. Les contrôles réintroduits au sein de Schengen lors de crises migratoires, sanitaires ou sécuritaires révèlent la persistance de la souveraineté nationale. Les tensions commerciales, les sanctions et la volonté de sécuriser les approvisionnements stratégiques montrent également que les États utilisent encore la frontière pour protéger leurs intérêts économiques et géopolitiques.\n\nTransition. La mondialisation ne produit donc ni un monde sans frontières ni un simple retour à des barrières étanches. Elle transforme plutôt la localisation et le fonctionnement des contrôles.\n\nIII. Les frontières se recomposent en dispositifs mobiles, sélectifs et profondément inégaux.\n\nA. Le contrôle peut être externalisé ou déterritorialisé. L'Union européenne confie une partie de la surveillance de ses marges à Frontex et coopère avec des pays de transit ; les compagnies aériennes vérifient les documents avant même le départ. La frontière n'est alors plus seulement une ligne sur une carte : elle devient un ensemble de contrôles exercés en amont, dans les gares, les ports, les aéroports ou les bases de données.\n\nB. Les frontières hiérarchisent les acteurs et les territoires. Elles sont très perméables pour les capitaux, les touristes aisés ou les travailleurs qualifiés, mais beaucoup plus contraignantes pour les réfugiés et les migrants pauvres. Certaines sont des interfaces dynamiques, comme la Northern Range européenne, tandis que d'autres prennent la forme de murs ou de zones militarisées. La mondialisation multiplie ainsi les discontinuités autant qu'elle intensifie les connexions.\n\nConclusion. La mondialisation ne conduit pas à l'effacement général des frontières. Elle atténue certains obstacles, mais maintient la souveraineté des États et transforme les frontières en filtres sélectifs, parfois déplacés loin de leur tracé officiel. Leur franchissement devient plus facile pour certains flux et plus difficile pour d'autres."
        ),
        DuelExercise(
            id: "philosophie-liberte",
            subject: "Philosophie",
            context: "Dissertation express : « Sommes-nous responsables de ce que nous sommes ? »",
            questions: [
                DuelExercise.Question(id: "problematique", prompt: "Dégage une problématique.", label: nil),
                DuelExercise.Question(id: "plan", prompt: "Propose un plan argumenté.", label: nil),
            ],
            opponentProduction: "Nous héritons d'un caractère et de conditions sociales que nous n'avons pas choisis, car nul ne choisit sa naissance, si bien que notre identité semble d'abord subie. Problématique : sommes-nous responsables de ce que nous sommes, puisque tant de choses nous déterminent ? On peut ainsi opposer le poids des déterminismes à l'idée que la liberté consiste à se ressaisir de son passé. On conclut que la responsabilité de soi se conquiert plus qu'elle ne se constate.",
            solution: "Analyse du sujet. « Ce que nous sommes » désigne notre identité (caractère, valeurs, personnalité) ; « responsables » suppose que nous en soyons l'auteur et puissions en répondre. Or beaucoup de ce que nous sommes semble subi : hérédité, éducation, société.\n\nProblématique. Si notre identité est largement déterminée par ce que nous n'avons pas choisi, en quel sens pouvons-nous en être tenus pour responsables ?\n\nPlan proposé.\nI. Nous semblons non responsables de ce que nous sommes : poids de l'inné, de l'inconscient (Freud) et des déterminismes sociaux (Bourdieu).\nII. Mais la liberté engage notre responsabilité : pour Sartre, « l'existence précède l'essence » — nous nous faisons par nos choix et sommes responsables de qui nous devenons.\nIII. Dépassement : être responsable de soi, c'est se ressaisir de son passé et de ses déterminations pour en faire quelque chose ; la responsabilité se conquiert plus qu'elle ne se constate.\n\nConclusion : nous ne choisissons pas nos points de départ, mais nous sommes responsables de ce que nous en faisons."
        ),
        DuelExercise(
            id: "si-second-ordre",
            subject: "Sciences de l’ingénieur",
            context: "Un système du second ordre est soumis à un échelon.",
            questions: [
                DuelExercise.Question(id: "forme-canonique", prompt: "Donner la forme canonique de sa fonction de transfert.", label: nil),
                DuelExercise.Question(id: "parametres", prompt: "Définir la pulsation propre et le facteur d'amortissement.", label: nil),
                DuelExercise.Question(id: "reponse", prompt: "Décrire la réponse selon la valeur de l'amortissement.", label: nil),
            ],
            opponentProduction: "La fonction de transfert d'un second ordre s'écrit H(p) = K / (1 + 2ξ·p/ω₀ + p²/ω₀²), où ω₀ est la pulsation propre et ξ le facteur d'amortissement. Comme la nature de la réponse dépend de ξ, on distingue trois cas : si ξ > 1 le régime est apériodique, si ξ = 1 il est critique, et si ξ < 1 la réponse est pseudo-périodique avec dépassement, car l'amortissement est faible. On conclut ainsi que ξ fixe la rapidité et la stabilité du système.",
            solution: "1) Forme canonique. La fonction de transfert d'un système linéaire du second ordre s'écrit :\nH(p) = K / (1 + (2ξ/ω₀)·p + p²/ω₀²),\noù K est le gain statique, ω₀ la pulsation propre (rad/s) et ξ le facteur d'amortissement (sans dimension).\n\n2) Définitions. ω₀ fixe la rapidité intrinsèque du système ; ξ caractérise l'importance de l'amortissement, donc la présence ou non d'oscillations.\n\n3) Réponse indicielle selon ξ.\n• ξ > 1 (deux pôles réels) : régime apériodique, pas de dépassement, réponse lente.\n• ξ = 1 : régime critique, réponse la plus rapide sans dépassement.\n• 0 < ξ < 1 : régime pseudo-périodique, dépassement et oscillations amorties, de pseudo-pulsation ω = ω₀·√(1 − ξ²) ; le dépassement est d'autant plus grand que ξ est petit.\n• ξ = 0 : oscillations entretenues à ω₀ (système non amorti).\n\nConclusion : ω₀ règle la rapidité, ξ règle la stabilité et le dépassement."
        ),
    ]

    /// Exo générique, quand aucune matière ne correspond. `{subject}` et
    /// `{focus}` sont remplacés au moment du tirage (voir `pickDuelExercise`).
    static let GENERIC_DUEL_EXERCISE: DuelExercise = DuelExercise(
        id: "generic",
        subject: "*",
        context: nil,
        questions: [
            DuelExercise.Question(id: "resolution", prompt: "Traite un exercice de colle de {subject}{focus} : pose clairement les hypothèses et mène le raisonnement étape par étape, aussi loin que le temps le permet.", label: nil),
        ],
        opponentProduction: "Je commence par poser les hypothèses et les notations. Je mène ensuite le raisonnement étape par étape, en justifiant chaque passage, puis je vérifie la cohérence du résultat avant de conclure.",
        solution: "Corrigé type. On commence par énoncer clairement les hypothèses et les notations. On mène ensuite le raisonnement étape par étape, en justifiant chaque passage par une définition, un théorème ou une loi du cours. On vérifie enfin la cohérence du résultat (ordre de grandeur, homogénéité, cas particuliers) avant de conclure explicitement en répondant à la question posée."
    )

    /// Options du tirage d'un défi (`pickDuelExercise`).
    struct PickOptions {
        /// Graine du match : les deux joueurs tirent le même exo.
        var seed: Int
        /// Exercices d'entraînement du chapitre tiré ; absents = énoncé générique.
        var exercices: [ChallengeExerciseEntry]? = nil
        /// Intitulé du chapitre, pour l'énoncé générique de secours.
        var focus: String? = nil
    }

    /// Tirage déterministe d'un exercice parmi une liste, par identifiant
    /// stable : la même graine — partagée par les deux joueurs — désigne le même
    /// exo des deux côtés (`pickChallengeExerciseEntry`).
    static func pickChallengeExerciseEntry(
        _ exercices: [ChallengeExerciseEntry],
        seed: Int
    ) -> ChallengeExerciseEntry? {
        if exercices.isEmpty { return nil }
        let ordered = exercices.sorted { $0.id < $1.id }
        let index = seed % ordered.count
        guard ordered.indices.contains(index) else { return nil }
        return ordered[index]
    }

    /// Choisit l'exo du défi parmi les énoncés du chapitre tiré, sinon un exo
    /// intégré de la matière, sinon l'exo générique (`pickDuelExercise`).
    static func pickDuelExercise(subject: String, options: PickOptions) -> DuelExercise {
        if let exercices = options.exercices, !exercices.isEmpty,
           let picked = pickChallengeExerciseEntry(exercices, seed: options.seed) {
            return chapterItemAsDuelExercise(picked, subject)
        }

        if let builtIn = DUEL_EXERCISES.first(where: { $0.subject == subject }) {
            return builtIn
        }

        let focus = options.focus ?? ""
        let suffix = focus.isEmpty ? "" : " sur « \(focus) »"
        var resolved = GENERIC_DUEL_EXERCISE
        resolved.questions = GENERIC_DUEL_EXERCISE.questions.map { question in
            var copy = question
            copy.prompt = (question.prompt ?? "")
                .replacingOccurrences(of: "{subject}", with: subject)
                .replacingOccurrences(of: "{focus}", with: suffix)
            return copy
        }
        return resolved
    }
}
