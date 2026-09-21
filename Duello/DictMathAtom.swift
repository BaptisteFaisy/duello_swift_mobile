//
//  DictMathAtom.swift
//  Duello
//
//  Portage de `src/utils/speechMath.ts` : lecture d'un atome (`lireAtome`) et
//  de ses formes à argument — unaire, parenthèse, racine, valeur absolue,
//  fonction usuelle.
//
//  Cible : iOS 16. Aucune dépendance externe.
//

import Foundation

/// Lecture d'un atome et de ses suffixes — `lireAtome` de `speechMath.ts`.
enum DictMathAtom {
    /// Regroupe un opérande et tout ce qui s'y accroche : exposant, indice, prime.
    ///
    /// `applique` autorise la lecture de « f de x » comme `f(x)`. Les bornes
    /// d'un grand opérateur la refusent.
    static func lireAtome(_ passage: [DictSymbole], _ depart: Int, applique: Bool = true) -> DictAtome? {
        guard depart < passage.count else { return nil }
        let symbole = passage[depart]
        var latex: String
        var position = depart + 1

        switch symbole.genre {
        case .operande:
            latex = symbole.latex
        case .binaire:
            guard let atome = atomeBinaire(passage, depart) else { return nil }
            latex = atome.latex
            position = atome.suivant
        case .ouvrante:
            let atome = atomeOuvrante(passage, depart)
            latex = atome.latex
            position = atome.suivant
        case .racine:
            guard let atome = atomeRacine(passage, depart) else { return nil }
            latex = atome.latex
            position = atome.suivant
        case .entoure:
            guard let atome = atomeEntoure(passage, depart) else { return nil }
            latex = atome.latex
            position = atome.suivant
        case .fonction:
            guard let atome = atomeFonction(passage, depart) else { return nil }
            latex = atome.latex
            position = atome.suivant
        case .grandOperateur:
            return DictMathSeries.lireGrandOperateur(passage, depart)
        default:
            return nil
        }

        return DictMathSeries.accrocherSuffixes(passage, DictAtome(latex: latex, suivant: position), applique)
    }

    /// Unaire : « moins x ».
    static func atomeBinaire(_ passage: [DictSymbole], _ depart: Int) -> DictAtome? {
        let symbole = passage[depart]
        guard symbole.latex == "+" || symbole.latex == "-" else { return nil }
        guard let suite = lireAtome(passage, depart + 1) else { return nil }
        return DictAtome(latex: "\(symbole.latex)\(suite.latex)", suivant: suite.suivant)
    }

    /// Parenthèse mathématique, refermée si possible.
    static func atomeOuvrante(_ passage: [DictSymbole], _ depart: Int) -> DictAtome {
        let contenu = DictMathSeries.lireSuite(passage, depart + 1, { $0.genre == .fermante })
        let latex = "\\left(\(contenu.latex)\\right)"
        let ferme = contenu.suivant < passage.count && passage[contenu.suivant].genre == .fermante
        return DictAtome(latex: latex, suivant: ferme ? contenu.suivant + 1 : contenu.suivant)
    }

    /// Racine d'un argument.
    static func atomeRacine(_ passage: [DictSymbole], _ depart: Int) -> DictAtome? {
        guard let argument = lireAtome(passage, depart + 1) else { return nil }
        return DictAtome(latex: "\\sqrt{\(argument.latex)}", suivant: argument.suivant)
    }

    /// Valeur absolue ou norme d'un argument.
    static func atomeEntoure(_ passage: [DictSymbole], _ depart: Int) -> DictAtome? {
        let symbole = passage[depart]
        guard let argument = lireAtome(passage, depart + 1) else { return nil }
        return DictAtome(
            latex: "\(symbole.latex)\(argument.latex)\(symbole.latex)",
            suivant: argument.suivant
        )
    }

    /// Fonction usuelle : « sinus de x » comme « sinus x ».
    static func atomeFonction(_ passage: [DictSymbole], _ depart: Int) -> DictAtome? {
        let symbole = passage[depart]
        let debut = (depart + 1 < passage.count && passage[depart + 1].genre == .lien) ? depart + 2 : depart + 1
        guard let argument = lireAtome(passage, debut) else { return nil }
        let latex = symbole.latex == "\\exp"
            ? "e^{\(argument.latex)}"
            : "\(symbole.latex)\\left(\(argument.latex)\\right)"
        return DictAtome(latex: latex, suivant: argument.suivant)
    }
}
