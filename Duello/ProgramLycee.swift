// [ProgramLycee] Programme du lycée : mathématiques par niveau (2de, 1re, Terminale), porté de `src/data/tracks.ts`.
// [ProgramLycee] Dérogation : `lyceeSubjects` (26 lignes) et `withExpertesAdditions` (5 lignes) ne font que retourner un catalogue statique de chapitres — exception « données statiques volumineuses » des règles de complexité Duello.
import Foundation

extension DuelloProgram {

    // MARK: Lycée (tronc commun de 2de, spécialité de 1re, options de terminale)

    /// `lyceeProgram` (`src/data/tracks.ts`, `scienceProgram` → branche
    /// `programTrack === 'Lycée'`) : le lycée n'a qu'une matière, les
    /// mathématiques, dont le programme dépend de la spécialité suivie.
    ///
    /// Le niveau est déduit de la spécialité, jamais de `year` : vide en 2de,
    /// paire « Maths + X » en 1re, intitulé d'option en terminale. La terminale
    /// peut cumuler la spécialité et les maths expertes — les deux programmes
    /// sont alors hydratés ensemble.
    static func lyceeSubjects(specialty: String) -> [TrackSubject] {
        let option = Self.normalize(specialty)
        let chapters: [TrackChapter]
        if option.contains("expertes") {
            chapters = option.contains("specialite")
                ? withExpertesAdditions(LyceeMaths.taleSpe)
                : LyceeMaths.taleExpertes
        } else if option.contains("complementaires") {
            chapters = LyceeMaths.taleComplementaires
        } else if option.contains("+") {
            chapters = LyceeMaths.premiereSpe
        } else if option.isEmpty {
            chapters = LyceeMaths.seconde
        } else {
            chapters = LyceeMaths.taleSpe
        }
        return [
            TrackSubject(
                id: "maths",
                name: "Mathématiques",
                fullName: specialty.isEmpty ? "Mathématiques" : specialty,
                icon: "function",
                chapters: chapters
            ),
        ]
    }

    /// `withExpertesAdditions` : complète le programme de spécialité avec les
    /// chapitres d'expertes manquants (cumul de terminale).
    static func withExpertesAdditions(_ chapters: [TrackChapter]) -> [TrackChapter] {
        let known = Set(chapters.map(\.id))
        return chapters + LyceeMaths.taleExpertes.filter { !known.contains($0.id) }
    }

    // MARK: Catalogues de chapitres

    /// Programmes officiels de mathématiques du lycée (`SECONDE_MATHS`,
    /// `PREMIERE_SPE_MATHS`, `TALE_SP_CHAPTERS`, `TALE_EXPERTES_CHAPTERS`,
    /// `TALE_COMPLEMENTAIRES_CHAPTERS`). Les identifiants de chapitres sont les
    /// clés utilisées par le serveur pour l'appariement des défis : ils restent
    /// identiques à ceux de l'app Expo.
    enum LyceeMaths {

        /// `SECONDE_MATHS` — tronc commun de seconde (programme 2026).
        static let seconde: [TrackChapter] = [
                chapter("vocabulaire-ensembliste-logique", "Vocabulaire ensembliste et logique", domain: "Fondements"),
                chapter("automatismes-seconde", "Automatismes : calcul, proportions, lecture graphique", domain: "Fondements"),
                chapter("nombres-et-calculs", "Nombres et calculs : ensembles, intervalles, valeur absolue", domain: "Algèbre"),
                chapter("calcul-litteral-identites", "Calcul littéral et identités remarquables", domain: "Algèbre"),
                chapter("arithmetique-seconde", "Arithmétique : multiples, diviseurs, parité, fractions", domain: "Algèbre"),
                chapter("equations-inequations-seconde", "Équations et inéquations du premier degré", domain: "Algèbre"),
                chapter("generalites-fonctions", "Généralités sur les fonctions : images, antécédents, courbes", domain: "Analyse"),
                chapter("fonctions-reference", "Fonctions de référence : affines, carré, inverse, racine carrée, cube", domain: "Analyse"),
                chapter("variations-extremums-seconde", "Variations, extremums et tableaux de signes", domain: "Analyse"),
                chapter("configurations-planes", "Configurations du plan : Pythagore, Thalès", domain: "Géométrie"),
                chapter("vecteurs-du-plan", "Vecteurs du plan : coordonnées, somme, déterminant, colinéarité", domain: "Géométrie"),
                chapter("geometrie-reperee-droites-seconde", "Géométrie repérée et équations de droites", domain: "Géométrie"),
                chapter("trigonometrie-seconde", "Trigonométrie dans le triangle rectangle", domain: "Géométrie"),
                chapter("statistique-probabilites", "Statistiques : moyenne, médiane, quartiles, écart-type", domain: "Probabilités"),
                chapter("proportions-evolutions", "Proportions, pourcentages et évolutions", domain: "Probabilités"),
                chapter("tableaux-croises-frequences", "Tableaux croisés et fréquences conditionnelles/marginales", domain: "Probabilités"),
                chapter("probabilites-conditionnelles-seconde", "Probabilités conditionnelles et arbres pondérés", domain: "Probabilités"),
                chapter("echantillonnage-loi-grands-nombres", "Échantillonnage et loi des grands nombres", domain: "Probabilités"),
                chapter("algorithmique-seconde", "Algorithmique et programmation (Python : variables, boucles, fonctions)", domain: "Informatique"),
        ]

        /// `PREMIERE_SPE_MATHS` — spécialité mathématiques de première (2026).
        static let premiereSpe: [TrackChapter] = [
                chapter("logique-premiere", "Logique : ensembles, implication, réciproque, contraposée, quantificateurs", domain: "Fondements"),
                chapter("automatismes-premiere", "Automatismes", domain: "Fondements"),
                chapter("second-degre", "Second degré : formes canonique/factorisée, discriminant, racines et signe", domain: "Algèbre"),
                chapter("suites-premiere", "Suites : explicite, récurrence, arithmétiques et géométriques, variations et sommes", domain: "Algèbre"),
                chapter("suites-limites-intuitives", "Suites : limites intuitives et modélisation", domain: "Algèbre"),
                chapter("derivation-premiere", "Dérivation : nombre dérivé, tangente, approximation affine", domain: "Analyse"),
                chapter("derivation-variations", "Dérivation et variations : signe de la dérivée et extremums", domain: "Analyse"),
                chapter("fonction-exponentielle", "Fonction exponentielle et fonctions t ↦ e^{at}", domain: "Analyse"),
                chapter("fonctions-parite-valeur-absolue", "Parité, fonctions paires/impaires et valeur absolue", domain: "Analyse"),
                chapter("trigonometrie-premiere", "Trigonométrie : cercle, radian, enroulement et valeurs remarquables", domain: "Analyse"),
                chapter("produit-scalaire-premiere", "Produit scalaire : projection, bilinéarité, Al-Kashi", domain: "Géométrie"),
                chapter("geometrie-repere-premiere", "Géométrie repérée : équations de droites, vecteurs normaux, cercles", domain: "Géométrie"),
                chapter("probabilites-conditionnelles-premiere", "Probabilités conditionnelles, indépendance et probabilités totales", domain: "Probabilités"),
                chapter("variables-aleatoires-premiere", "Variables aléatoires : loi, espérance, variance, écart-type (König-Huygens)", domain: "Probabilités"),
                chapter("bernoulli-premiere", "Répétition d’épreuves de Bernoulli indépendantes (n ≤ 4)", domain: "Probabilités"),
                chapter("experimentations-simulation", "Expérimentations : simulation d’échantillons et estimation de l’espérance", domain: "Probabilités"),
                chapter("algorithmique-premiere", "Algorithmique et programmation (Python : listes, boucles, fonctions)", domain: "Informatique"),
        ]

        /// `TALE_SP_CHAPTERS` — spécialité mathématiques de terminale.
        static let taleSpe: [TrackChapter] = [
                chapter("suites-recurrence-limites", "Suites : récurrence et limites", domain: "Analyse"),
                chapter("limites-continuite-tvi", "Limites de fonctions, continuité et TVI", domain: "Analyse"),
                chapter("derivation-convexite", "Compléments sur la dérivation et convexité", domain: "Analyse"),
                chapter("logarithme-exponentielle", "Fonctions logarithme népérien et exponentielle", domain: "Analyse"),
                chapter("fonctions-trigonometriques", "Fonctions trigonométriques", domain: "Analyse"),
                chapter("primitives-equations-differentielles", "Primitives et équations différentielles", domain: "Analyse"),
                chapter("calcul-integral", "Calcul intégral", domain: "Analyse"),
                chapter("combinatoire-denombrement", "Combinatoire et dénombrement", domain: "Algèbre"),
                chapter("vecteurs-geometrie-espace", "Vecteurs et géométrie dans l'espace", domain: "Géométrie"),
                chapter("droites-plans-espace", "Droites et plans de l'espace", domain: "Géométrie"),
                chapter("produit-scalaire-espace", "Produit scalaire dans l'espace", domain: "Géométrie"),
                chapter("probabilites-conditionnelles", "Probabilités conditionnelles et indépendance", domain: "Probabilités"),
                chapter("variables-aleatoires-lois", "Variables aléatoires et lois", domain: "Probabilités"),
                chapter("concentration-loi-grands-nombres", "Concentration, loi des grands nombres", domain: "Probabilités"),
                chapter("algorithmique-python", "Algorithmique et programmation (Python)", domain: "Informatique"),
                chapter("automatismes", "Automatismes", domain: "Synthèse"),
        ]

        /// `TALE_EXPERTES_CHAPTERS` — option mathématiques expertes de terminale.
        static let taleExpertes: [TrackChapter] = [
                chapter("complexes-algebrique", "Nombres complexes : point de vue algébrique", domain: "Algèbre"),
                chapter("arithmetique", "Arithmétique", domain: "Algèbre"),
                chapter("complexes-geometrique", "Nombres complexes : point de vue géométrique", domain: "Géométrie"),
                chapter("graphes-matrices", "Graphes et matrices", domain: "Géométrie"),
        ]

            /// `TALE_COMPLEMENTAIRES_CHAPTERS` — option mathématiques
        /// complémentaires de terminale (aucune banque d'exercices montée : la
        /// liste s'affiche sans sujets).
        static let taleComplementaires: [TrackChapter] = [
                chapter("vocabulaire-ensembliste-logique-complementaires", "Vocabulaire ensembliste et logique", domain: "Fondements"),
                chapter("complementaires-suites-modeles-discrets", "Suites numériques et modèles discrets", domain: "Analyse"),
                chapter("complementaires-fonctions-continuite-limites", "Fonctions : continuité, dérivabilité, limites et représentation graphique", domain: "Analyse"),
                chapter("complementaires-primitives-equations-differentielles", "Primitives et équations différentielles", domain: "Analyse"),
                chapter("complementaires-fonctions-convexes", "Fonctions convexes", domain: "Analyse"),
                chapter("complementaires-integration", "Intégration et calculs d’aires", domain: "Analyse"),
                chapter("complementaires-lois-discretes", "Lois discrètes", domain: "Probabilités"),
                chapter("complementaires-lois-a-densite", "Lois à densité et temps d’attente", domain: "Probabilités"),
                chapter("complementaires-statistique-deux-variables", "Statistique à deux variables quantitatives : corrélation et causalité", domain: "Probabilités"),
                chapter("complementaires-algorithmique-python", "Algorithmique et programmation (Python)", domain: "Informatique"),
        ]
    }
}
