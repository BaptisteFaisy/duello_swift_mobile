//
//  DictMathFormula.swift
//  Duello
//
//  Portage de `src/utils/speechMath.ts` : décision « ce passage est-il une
//  formule ? » (`estFormule`), élagage des bords (`elaguer`) et prédicats de
//  voisinage (`estValeur`, `ouvreValeur`, `estUnaire`).
//
//  Le pari est celui du « si besoin » : une copie de prépa est d'abord du
//  français, et un passage n'est converti que s'il porte un marqueur décisif
//  correctement entouré d'opérandes.
//
//  Cible : iOS 16. Aucune dépendance externe.
//

import Foundation

/// Décisions de conversion — `estFormule`/`elaguer` de `speechMath.ts`.
enum DictMathFormula {
    /// Un symbole qui produit une valeur : de quoi nourrir un opérateur à sa gauche.
    static func estValeur(_ symbole: DictSymbole?) -> Bool {
        guard let symbole else { return false }
        switch symbole.genre {
        case .operande, .fermante, .suffixe, .partage, .differentielle:
            return true
        default:
            return false
        }
    }

    /// Un symbole qui ouvre une valeur : de quoi nourrir un opérateur à sa droite.
    static func ouvreValeur(_ symbole: DictSymbole?) -> Bool {
        guard let symbole else { return false }
        switch symbole.genre {
        case .operande, .ouvrante, .racine, .entoure, .fonction, .grandOperateur, .binaire:
            return true
        default:
            return false
        }
    }

    /// `+` et `-` en tête de passage sont unaires : « moins x » se lit `-x`.
    static func estUnaire(_ passage: [DictSymbole], _ position: Int) -> Bool {
        guard position == 0, position < passage.count else { return false }
        let symbole = passage[position]
        let suivant = position + 1 < passage.count ? passage[position + 1] : nil
        return symbole.genre == .binaire
            && (symbole.latex == "+" || symbole.latex == "-")
            && ouvreValeur(suivant)
    }

    /// Le passage mérite-t-il d'être écrit en LaTeX ?
    static func estFormule(_ passage: [DictSymbole]) -> Bool {
        if !passage.contains(where: { $0.genre == .operande }) { return false }

        // Un signe unaire isolé ne fait pas une formule, sans quoi « au moins
        // deux heures » deviendrait `-2`.
        let decisif = passage.enumerated().contains { position, symbole in
            symbole.fort && !estUnaire(passage, position)
        }
        if !decisif { return false }

        // Bornes et différentielles n'ont de sens qu'au service d'un grand opérateur.
        let grandOperateur = passage.firstIndex(where: { $0.genre == .grandOperateur }) ?? -1
        let orpheline = passage.enumerated().contains { position, symbole in
            (symbole.genre == .borne || symbole.genre == .differentielle)
                && (grandOperateur == -1 || grandOperateur > position)
        }
        if orpheline { return false }

        return passage.enumerated().allSatisfy { position, symbole in
            let relie = symbole.genre == .binaire
                || symbole.genre == .relation
                || symbole.genre == .fraction
            if !relie { return true }
            let suivant = position + 1 < passage.count ? passage[position + 1] : nil
            if !ouvreValeur(suivant) { return false }
            let precedent = position - 1 >= 0 ? passage[position - 1] : nil
            return estValeur(precedent) || estUnaire(passage, position)
        }
    }

    /// Ramène le passage à ce qui peut réellement commencer et finir une formule.
    static func elaguer(_ passage: [DictSymbole])
        -> (avant: [DictSymbole], formule: [DictSymbole], apres: [DictSymbole]) {
        var debut = 0
        var fin = passage.count

        while debut < fin && !ouvreValeur(passage[debut]) { debut += 1 }
        while fin > debut && !estValeur(passage[fin - 1]) { fin -= 1 }

        return (
            avant: Array(passage[0..<debut]),
            formule: Array(passage[debut..<fin]),
            apres: Array(passage[fin..<passage.count])
        )
    }
}
