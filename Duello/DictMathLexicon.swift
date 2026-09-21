//
//  DictMathLexicon.swift
//  Duello
//
//  Portage de `src/utils/speechMath.ts` : types de symbole et tables lexicales.
//
//  Le module `speechMath.ts` réécrit une phrase dictée en LaTeX, mais seulement
//  pour ses passages réellement mathématiques. Ce fichier ne contient que les
//  déclarations (`DictGenre`, `DictSymbole`, `DictAtome`, `DictMot`) et les
//  tables de correspondance mot → LaTeX ; la logique vit dans les fichiers
//  `DictMathLexer`, `DictMathWordReader`, `DictMathAnalyzer`,
//  `DictMathFormula`, `DictMathAtom`, `DictMathSeries` et `DictMathParser`.
//
//  Cible : iOS 16. Aucune dépendance externe.
//

import Foundation

/// Rôle d'un symbole dans la formule — `Genre` de `speechMath.ts`.
enum DictGenre: Equatable {
    /// Une valeur : nombre, lettre, lettre grecque, ensemble.
    case operande
    /// Opérateur binaire, ou unaire en tête de formule pour `+` et `-`.
    case binaire
    /// Relation : égalité, comparaison, appartenance, implication.
    case relation
    case ouvrante
    case fermante
    /// Suffixe qui s'attache à la valeur précédente : `^{2}`, `'`, `!`.
    case suffixe
    /// « puissance », « exposant » : consomme la valeur suivante.
    case puissance
    /// « indice ».
    case indice
    /// « racine de », « racine carrée de ».
    case racine
    /// « valeur absolue de », « norme de ».
    case entoure
    /// Fonction usuelle appliquée à la valeur suivante.
    case fonction
    /// « sur » : construit une fraction avec la valeur précédente.
    case fraction
    /// « demis », « tiers », « quarts » : dénominateur fixe.
    case partage
    /// Grand opérateur : intégrale, somme, produit, limite.
    case grandOperateur
    /// « de » : borne basse d'un grand opérateur, ou application `f(x)`.
    case lien
    /// « à » : borne haute d'un grand opérateur.
    case borne
    /// Élément différentiel `dx` qui clôt une intégrale.
    case differentielle
    /// Mot ordinaire : il interrompt la formule.
    case mot
}

/// Un symbole analysé — `Symbole` de `speechMath.ts`.
struct DictSymbole {
    var genre: DictGenre
    /// Rendu LaTeX, vide pour un mot de prose.
    var latex: String
    /// Mots d'origine, restitués tels quels si la formule est refusée.
    var brut: String
    /// Marqueur décisif : sans lui, le passage reste de la prose.
    var fort: Bool
    /// Ponctuation collée à la fin : elle clôt toujours la formule.
    var ponctuation: String
    /// Mot d'origine normalisé, vide pour une locution : « un » se relit plus tard.
    var cle: String
    /// Aucune espace ne le séparait du précédent : « un+ » en donne deux.
    var colle: Bool
}

/// Un atome rendu et l'index du premier symbole non consommé — `Atome`.
struct DictAtome {
    var latex: String
    var suivant: Int
}

/// Un mot découpé et normalisé — `Mot` de `speechMath.ts`.
struct DictMot {
    var brut: String
    /// Minuscules sans accent : la table de correspondance y est insensible.
    var cle: String
    /// Original en minuscules, accents conservés : distingue « à » de « a ».
    var minuscule: String
    /// Mot sans sa ponctuation, casse d'origine : `R` reste `R`, pas `r`.
    var noyau: String
    var ponctuation: String
    var prefixe: String
    /// Détaché du mot précédent sans espace : « un+ » donne « un » puis « + ».
    var colle: Bool
}

/// Tables lexicales reprises telles quelles de `src/utils/speechMath.ts`.
enum DictMathLexicon {
    /// Nombres dictés en toutes lettres. Au-delà, le moteur rend déjà des chiffres.
    static let nombres: [String: String] = [
        "zero": "0", "un": "1", "une": "1", "deux": "2", "trois": "3", "quatre": "4",
        "cinq": "5", "six": "6", "sept": "7", "huit": "8", "neuf": "9", "dix": "10",
        "onze": "11", "douze": "12", "treize": "13", "quatorze": "14", "quinze": "15",
        "seize": "16", "vingt": "20", "trente": "30", "quarante": "40", "cinquante": "50",
        "soixante": "60", "cent": "100", "mille": "1000",
    ]

    static let lettresGrecques: [String: String] = [
        "alpha": "\\alpha", "beta": "\\beta", "gamma": "\\gamma", "delta": "\\delta",
        "epsilon": "\\varepsilon", "zeta": "\\zeta", "eta": "\\eta", "theta": "\\theta",
        "iota": "\\iota", "kappa": "\\kappa", "lambda": "\\lambda", "mu": "\\mu", "nu": "\\nu",
        "xi": "\\xi", "pi": "\\pi", "rho": "\\rho", "sigma": "\\sigma", "tau": "\\tau",
        "phi": "\\varphi", "chi": "\\chi", "psi": "\\psi", "omega": "\\omega",
    ]

    static let ensembles: [String: String] = [
        "reels": "\\mathbb{R}", "entiers": "\\mathbb{Z}", "naturels": "\\mathbb{N}",
        "rationnels": "\\mathbb{Q}", "complexes": "\\mathbb{C}",
    ]

    static let fonctions: [String: String] = [
        "sinus": "\\sin", "cosinus": "\\cos", "tangente": "\\tan", "sin": "\\sin",
        "cos": "\\cos", "tan": "\\tan", "ln": "\\ln", "log": "\\log", "arctangente": "\\arctan",
        "arctan": "\\arctan", "ch": "\\cosh", "sh": "\\sinh",
    ]

    /// Caractères mathématiques que le moteur écrit lui-même.
    static let symboles: [String: (DictGenre, String, Bool)] = [
        "+": (.binaire, "+", true),
        "-": (.binaire, "-", true),
        "−": (.binaire, "-", true),
        "×": (.binaire, "\\times", true),
        "*": (.binaire, "\\times", true),
        "÷": (.binaire, "\\div", true),
        "±": (.binaire, "\\pm", true),
        "/": (.fraction, "", true),
        "=": (.relation, "=", true),
        "<": (.relation, "<", true),
        ">": (.relation, ">", true),
        "≤": (.relation, "\\leq", true),
        "≥": (.relation, "\\geq", true),
        "≠": (.relation, "\\neq", true),
        "≈": (.relation, "\\approx", true),
        "∈": (.relation, "\\in", true),
        "⊂": (.relation, "\\subset", true),
        "→": (.relation, "\\to", true),
        "⇒": (.relation, "\\Rightarrow", true),
        "⇔": (.relation, "\\Leftrightarrow", true),
        "^": (.puissance, "", true),
        "√": (.racine, "", true),
        "∞": (.operande, "\\infty", true),
        "π": (.operande, "\\pi", true),
        "(": (.ouvrante, "(", false),
        ")": (.fermante, ")", false),
    ]

    /// Lettres qui indicent une suite ou une famille.
    static let indices: Set<String> = ["n", "k", "p", "i", "j", "m", "q"]

    /// Lettres qui portent une suite dictée d'un bloc, comme « vn ».
    static let porteuses: Set<String> = ["a", "b", "c", "s", "t", "u", "v", "w", "x", "y", "z"]

    /// Mots français que le motif « lettre + indice » attraperait à tort.
    static let faussesSuites: Set<String> = ["an", "un", "ai", "ci", "si"]

    /// Le mot que le moteur rend quand une suite uₙ est dictée lettre à lettre.
    static let suiteSoudee: Set<String> = ["un", "une"]

    /// Décalage d'indice absorbé maximal — `DECALAGE_MAX`.
    static let decalageMax = 2

    /// Locutions reconnues avant les mots isolés, de la plus longue à la plus courte.
    static let locutions: [(String, DictGenre, String, Bool)] = [
        ("est strictement inferieur a", .relation, "<", true),
        ("est strictement superieur a", .relation, ">", true),
        ("strictement inferieur a", .relation, "<", true),
        ("strictement superieur a", .relation, ">", true),
        ("est inferieur ou egal a", .relation, "\\leq", true),
        ("est superieur ou egal a", .relation, "\\geq", true),
        ("inferieur ou egal a", .relation, "\\leq", true),
        ("superieur ou egal a", .relation, "\\geq", true),
        ("plus petit ou egal a", .relation, "\\leq", true),
        ("plus grand ou egal a", .relation, "\\geq", true),
        ("est inferieur a", .relation, "<", true),
        ("est superieur a", .relation, ">", true),
        ("inferieur a", .relation, "<", true),
        ("superieur a", .relation, ">", true),
        ("est different de", .relation, "\\neq", true),
        ("different de", .relation, "\\neq", true),
        ("est egal a", .relation, "=", true),
        ("est egale a", .relation, "=", true),
        ("egal a", .relation, "=", true),
        ("egale a", .relation, "=", true),
        ("equivaut a", .relation, "\\Leftrightarrow", true),
        ("est equivalent a", .relation, "\\sim", true),
        ("equivalent a", .relation, "\\sim", true),
        ("si et seulement si", .relation, "\\Leftrightarrow", true),
        ("appartient a", .relation, "\\in", true),
        ("est inclus dans", .relation, "\\subset", true),
        ("inclus dans", .relation, "\\subset", true),
        ("tend vers", .relation, "\\to", true),
        ("implique que", .relation, "\\Rightarrow", true),
        ("au carre", .suffixe, "^{2}", true),
        ("au cube", .suffixe, "^{3}", true),
        ("puissance moins", .puissance, "-", true),
        ("exposant moins", .puissance, "-", true),
        ("d'indice", .indice, "", true),
        ("indice inferieur", .indice, "", true),
        ("en indice", .indice, "", true),
        ("racine carree de", .racine, "", true),
        ("racine carree", .racine, "", true),
        ("racine de", .racine, "", true),
        ("valeur absolue de", .entoure, "|", true),
        ("module de", .entoure, "|", true),
        ("norme de", .entoure, "\\|", true),
        ("l'integrale de", .grandOperateur, "\\int", true),
        ("integrale de", .grandOperateur, "\\int", true),
        ("la somme pour", .grandOperateur, "\\sum", true),
        ("la somme de", .grandOperateur, "\\sum", true),
        ("somme pour", .grandOperateur, "\\sum", true),
        ("somme de", .grandOperateur, "\\sum", true),
        ("le produit de", .grandOperateur, "\\prod", true),
        ("produit de", .grandOperateur, "\\prod", true),
        ("la limite quand", .grandOperateur, "\\lim", true),
        ("la limite de", .grandOperateur, "\\lim", true),
        ("limite quand", .grandOperateur, "\\lim", true),
        ("limite de", .grandOperateur, "\\lim", true),
        ("un demi", .operande, "\\frac{1}{2}", true),
        ("un tiers", .operande, "\\frac{1}{3}", true),
        ("deux tiers", .operande, "\\frac{2}{3}", true),
        ("un quart", .operande, "\\frac{1}{4}", true),
        ("trois quarts", .operande, "\\frac{3}{4}", true),
        ("multiplie par", .binaire, "\\times", true),
        ("divise par", .binaire, "\\div", true),
        ("plus ou moins", .binaire, "\\pm", true),
        ("plus l'infini", .operande, "+\\infty", true),
        ("moins l'infini", .operande, "-\\infty", true),
        ("pour tout", .operande, "\\forall", true),
        ("quel que soit", .operande, "\\forall", true),
        ("il existe", .operande, "\\exists", true),
        ("l'ensemble vide", .operande, "\\emptyset", true),
        ("ensemble vide", .operande, "\\emptyset", true),
        ("exponentielle de", .fonction, "\\exp", true),
        ("logarithme neperien de", .fonction, "\\ln", true),
        ("logarithme neperien", .fonction, "\\ln", true),
        ("logarithme de", .fonction, "\\log", true),
        ("parenthese ouvrante", .ouvrante, "(", false),
        ("parenthese fermante", .fermante, ")", false),
        ("ouvre la parenthese", .ouvrante, "(", false),
        ("ferme la parenthese", .fermante, ")", false),
    ]

    /// Mots isolés. Le genre décide de leur rôle dans la formule.
    static let mots: [String: (DictGenre, String, Bool)] = [
        "plus": (.binaire, "+", true),
        "moins": (.binaire, "-", true),
        "fois": (.binaire, "\\times", true),
        "egal": (.relation, "=", true),
        "egale": (.relation, "=", true),
        "egalent": (.relation, "=", true),
        "vaut": (.relation, "=", true),
        "donc": (.relation, "\\Rightarrow", true),
        "implique": (.relation, "\\Rightarrow", true),
        "sur": (.fraction, "", true),
        "puissance": (.puissance, "", true),
        "exposant": (.puissance, "", true),
        "indice": (.indice, "", true),
        "prime": (.suffixe, "'", true),
        "seconde": (.suffixe, "''", true),
        "factorielle": (.suffixe, "!", true),
        "demi": (.partage, "2", true),
        "demis": (.partage, "2", true),
        "tiers": (.partage, "3", true),
        "quart": (.partage, "4", true),
        "quarts": (.partage, "4", true),
        "infini": (.operande, "\\infty", true),
        "integrale": (.grandOperateur, "\\int", true),
        "somme": (.grandOperateur, "\\sum", true),
        "produit": (.grandOperateur, "\\prod", true),
        "limite": (.grandOperateur, "\\lim", true),
        "de": (.lien, "", false),
        "jusqu'a": (.borne, "", false),
    ]

    /// Éléments différentiels admis.
    static let differentielles: Set<String> = ["dx", "dt", "dy", "dz", "ds", "dr", "dn", "dv", "dw"]

    /// Pronoms après lesquels « a » est le verbe avoir, jamais une inconnue.
    static let pronoms: Set<String> = ["on", "il", "elle", "ils", "elles", "y", "qui", "n", "ca"]

    /// Ponctuation collée à la fin d'un mot — `PONCTUATION_FINALE`.
    static let ponctuationFinale: Set<Character> = [".", ",", ";", ":", "!", "?", ")", "»"]

    /// Ponctuation collée au début d'un mot — `PONCTUATION_INITIALE`.
    static let ponctuationInitiale: Set<Character> = ["(", "«", "\"", "'"]
}
