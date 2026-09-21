//
//  DictMathAnalyzer.swift
//  Duello
//
//  Portage de `src/utils/speechMath.ts` : de la suite de mots à la suite de
//  symboles — locutions, fusion des indices, résolution de la suite soudée
//  « un » → uₙ et calage des grands opérateurs (`analyser`).
//
//  Cible : iOS 16. Aucune dépendance externe.
//

import Foundation

/// Analyse d'une suite de mots — `analyser` de `speechMath.ts`.
enum DictMathAnalyzer {
    /// Reconnaît une locution à partir de `depart`, ou rend `nil`.
    static func lireLocution(_ mots: [DictMot], _ depart: Int) -> (symbole: DictSymbole, longueur: Int)? {
        for (expression, genre, latex, fort) in DictMathLexicon.locutions {
            let morceaux = expression.split(separator: " ").map { String($0) }
            if depart + morceaux.count > mots.count { continue }

            let candidats = Array(mots[depart..<(depart + morceaux.count)])
            // Une ponctuation à l'intérieur coupe la locution : « de plus, on a »
            // ne doit jamais se lire comme une seule expression.
            if candidats.dropLast().contains(where: { !$0.ponctuation.isEmpty }) { continue }
            if !candidats.enumerated().allSatisfy({ $0.element.cle == morceaux[$0.offset] }) { continue }

            let symbole = DictSymbole(
                genre: genre, latex: latex,
                brut: candidats.map { $0.brut }.joined(separator: " "),
                fort: fort, ponctuation: candidats[candidats.count - 1].ponctuation,
                cle: "", colle: candidats[0].colle
            )
            return (symbole, morceaux.count)
        }
        return nil
    }

    /// Un grand opérateur sans bornes n'en est pas un.
    static func calerGrandsOperateurs(_ symboles: [DictSymbole]) -> [DictSymbole] {
        symboles.enumerated().map { index, symbole in
            guard symbole.genre == .grandOperateur else { return symbole }

            var borne = false
            var position = index + 1
            while position < symboles.count {
                let candidat = symboles[position]
                // La recherche s'arrête au premier mot de prose.
                if candidat.genre == .mot { break }
                if symbole.latex == "\\lim" ? candidat.latex == "\\to" : candidat.genre == .borne {
                    borne = true
                    break
                }
                if !candidat.ponctuation.isEmpty { break }
                position += 1
            }
            return borne
                ? symbole
                : DictSymbole(
                    genre: .mot, latex: symbole.latex, brut: symbole.brut, fort: false,
                    ponctuation: symbole.ponctuation, cle: symbole.cle, colle: symbole.colle
                )
        }
    }

    /// Une lettre seule, donc candidate à porter un indice.
    static func estLettreSeule(_ symbole: DictSymbole) -> Bool {
        guard symbole.genre == .operande else { return false }
        let latex = symbole.latex
        guard latex.count == 1, let scalaire = latex.unicodeScalars.first else { return false }
        return (0x41...0x5A).contains(scalaire.value) || (0x61...0x7A).contains(scalaire.value)
    }

    /// Ce qui suit une lettre isolée sans opérateur est son indice.
    static func estIndiceDe(_ porteur: DictSymbole, _ indice: DictSymbole?, precedent: DictSymbole?) -> String? {
        guard estLettreSeule(porteur), porteur.ponctuation.isEmpty, let indice else { return nil }
        guard indice.genre == .operande else { return nil }

        if estLettreSeule(indice) {
            let lettre = indice.latex.lowercased()
            if !DictMathLexicon.indices.contains(lettre) || porteur.latex.lowercased() == lettre {
                return nil
            }
            return lettre
        }
        let chiffres = indice.latex
        guard !chiffres.isEmpty, chiffres.count <= 2,
              chiffres.allSatisfy({ $0.isASCII && $0.isNumber }) else { return nil }
        if DictMathFormula.estValeur(precedent) { return nil }
        return chiffres
    }

    /// Fusionne un porteur et son indice — `fusionnerIndices`.
    static func fusionnerIndices(_ symboles: [DictSymbole]) -> [DictSymbole] {
        var rendus: [DictSymbole] = []
        var index = 0

        while index < symboles.count {
            let porteur = symboles[index]
            let indice: DictSymbole? = index + 1 < symboles.count ? symboles[index + 1] : nil
            guard let lettre = estIndiceDe(porteur, indice, precedent: rendus.last), let indice else {
                rendus.append(porteur)
                index += 1
                continue
            }
            rendus.append(DictSymbole(
                genre: .operande, latex: "\(porteur.latex)_{\(lettre)}",
                brut: "\(porteur.brut)\(indice.colle ? "" : " ")\(indice.brut)",
                fort: true, ponctuation: indice.ponctuation, cle: "", colle: porteur.colle
            ))
            index += 2
        }
        return rendus
    }

    /// « un » : le nombre 1, ou la suite uₙ que le moteur a soudée ?
    static func resoudreSuiteSoudee(_ symboles: [DictSymbole]) -> [DictSymbole] {
        var rendus = symboles
        var debut = 0

        for index in 0..<rendus.count {
            if rendus[index].genre == .mot {
                trancherSuiteSoudee(&rendus, debut, index)
                debut = index + 1
                continue
            }
            if !rendus[index].ponctuation.isEmpty {
                trancherSuiteSoudee(&rendus, debut, index + 1)
                debut = index + 1
            }
        }
        trancherSuiteSoudee(&rendus, debut, rendus.count)
        return rendus
    }

    /// Décide, sur un passage, si les « un » sont des uₙ (récurrence).
    static func trancherSuiteSoudee(_ rendus: inout [DictSymbole], _ debut: Int, _ fin: Int) {
        var occurrences: [Int] = []
        for index in stride(from: debut, to: fin, by: 1)
        where DictMathLexicon.suiteSoudee.contains(rendus[index].cle) {
            occurrences.append(index)
        }
        guard occurrences.count >= 2 else { return }
        let enTete = occurrences.allSatisfy { $0 == debut || rendus[$0 - 1].genre == .relation }
        guard enTete else { return }
        for index in occurrences {
            rendus[index].latex = "u_{n}"
            rendus[index].fort = true
        }
    }

    /// Rend la suite de symboles complète d'une phrase — `analyser`.
    static func analyser(_ mots: [DictMot]) -> [DictSymbole] {
        var symboles: [DictSymbole] = []
        var index = 0

        while index < mots.count {
            if let locution = lireLocution(mots, index) {
                symboles.append(locution.symbole)
                index += locution.longueur
                continue
            }
            symboles.append(DictMathWordReader.lireMot(mots[index], precedent: index > 0 ? mots[index - 1] : nil))
            index += 1
        }
        return calerGrandsOperateurs(resoudreSuiteSoudee(fusionnerIndices(symboles)))
    }
}
