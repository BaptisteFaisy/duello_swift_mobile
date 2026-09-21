//
//  DictMathSymbole.swift
//  Duello
//
//  Portage de `src/utils/speechMath.ts` : fabriques de symboles partagées par
//  la lecture des mots (`DictMathWordReader`) et l'analyse des passages.
//
//  Cible : iOS 16. Aucune dépendance externe.
//

import Foundation

/// Construction des symboles — `operande`/`symboleDe`/`estNombre` de la source.
enum DictMathSymbole {
    /// Une valeur : nombre, lettre, lettre grecque, ensemble.
    static func operande(_ latex: String, _ mot: DictMot, fort: Bool = false) -> DictSymbole {
        DictSymbole(
            genre: .operande, latex: latex, brut: mot.brut, fort: fort,
            ponctuation: mot.ponctuation, cle: mot.cle, colle: mot.colle
        )
    }

    /// Construit le symbole d'un mot dont le genre et le rendu sont connus.
    static func symboleDe(_ mot: DictMot, _ connu: (DictGenre, String, Bool)) -> DictSymbole {
        DictSymbole(
            genre: connu.0, latex: connu.1, brut: mot.brut, fort: connu.2,
            ponctuation: mot.ponctuation, cle: mot.cle, colle: mot.colle
        )
    }

    /// Élément différentiel `dx` qui clôt une intégrale.
    static func differentielle(_ mot: DictMot) -> DictSymbole {
        let lettres = Array(mot.cle)
        let inconnue = lettres.count > 1 ? String(lettres[1]) : "x"
        return DictSymbole(
            genre: .differentielle, latex: "\\,d\(inconnue)", brut: mot.brut, fort: true,
            ponctuation: mot.ponctuation, cle: mot.cle, colle: mot.colle
        )
    }

    /// Un mot est-il un nombre — `^-?\d+([.,]\d+)?$` de la source ?
    static func estNombre(_ texte: String) -> Bool {
        var caracteres = Array(texte)
        if caracteres.first == "-" { caracteres.removeFirst() }
        guard !caracteres.isEmpty else { return false }

        var index = 0
        var entiers = 0
        while index < caracteres.count, caracteres[index].isASCII, caracteres[index].isNumber {
            entiers += 1
            index += 1
        }
        guard entiers > 0 else { return false }

        if index < caracteres.count, caracteres[index] == "." || caracteres[index] == "," {
            index += 1
            var decimales = 0
            while index < caracteres.count, caracteres[index].isASCII, caracteres[index].isNumber {
                decimales += 1
                index += 1
            }
            guard decimales > 0 else { return false }
        }
        return index == caracteres.count
    }
}
