//
//  DictMathSeries.swift
//  Duello
//
//  Portage de `src/utils/speechMath.ts` : rendu d'une suite de symboles
//  (`lireSuite`), accrochage des suffixes et du décalage d'indice
//  (`accrocherSuffixes`, `lireDecalage`) et grands opérateurs bornés
//  (`lireGrandOperateur`).
//
//  Cible : iOS 16. Aucune dépendance externe.
//

import Foundation

/// Rendu d'une suite de symboles — `lireSuite`/`lireGrandOperateur` de la source.
enum DictMathSeries {
    /// Rend une suite d'atomes reliés par des opérateurs, jusqu'à `arret`.
    ///
    /// « sur » se résout ici : la fraction a besoin de l'atome déjà rendu à sa
    /// gauche, ce qu'une lecture strictement atome par atome ne saurait pas faire.
    static func lireSuite(
        _ passage: [DictSymbole],
        _ depart: Int,
        _ arret: (DictSymbole) -> Bool,
        applique: Bool = true
    ) -> DictAtome {
        var morceaux: [String] = []
        var dernierAtome = -1
        var position = depart

        while position < passage.count {
            let symbole = passage[position]
            if arret(symbole) { break }

            if symbole.genre == .fraction {
                let denominateur = position + 1 < passage.count
                    ? DictMathAtom.lireAtome(passage, position + 1, applique: applique)
                    : nil
                if let denominateur, dernierAtome != -1 {
                    morceaux[dernierAtome] = "\\frac{\(morceaux[dernierAtome])}{\(denominateur.latex)}"
                    position = denominateur.suivant
                    continue
                }
                position += 1
                continue
            }

            if symbole.genre == .binaire || symbole.genre == .relation {
                if dernierAtome != -1 || symbole.genre == .relation {
                    morceaux.append(symbole.latex)
                    position += 1
                    continue
                }
            }

            if let atome = DictMathAtom.lireAtome(passage, position, applique: applique) {
                morceaux.append(atome.latex)
                dernierAtome = morceaux.count - 1
                position = atome.suivant
            } else {
                position += 1
            }
        }

        return DictAtome(latex: morceaux.joined(separator: " "), suivant: position)
    }

    /// Exposants, indices, primes et applications `f(x)` collés à la valeur.
    static func accrocherSuffixes(_ passage: [DictSymbole], _ atome: DictAtome, _ applique: Bool) -> DictAtome {
        var latex = atome.latex
        var suivant = atome.suivant

        while suivant < passage.count {
            let symbole = passage[suivant]

            if let decalage = lireDecalage(passage, suivant, latex) {
                latex = decalage.latex
                suivant = decalage.suivant
                continue
            }
            if symbole.genre == .suffixe {
                latex += symbole.latex
                suivant += 1
                continue
            }
            // « trois demis » : le dénominateur est porté par le mot lui-même.
            if symbole.genre == .partage {
                latex = "\\frac{\(latex)}{\(symbole.latex)}"
                suivant += 1
                continue
            }
            if symbole.genre == .puissance || symbole.genre == .indice {
                guard suivant + 1 < passage.count,
                      let argument = DictMathAtom.lireAtome(passage, suivant + 1) else { break }
                // « puissance moins » porte déjà le signe : `x^{-1}`.
                let signe = symbole.latex == "-" ? "-" : ""
                latex += symbole.genre == .puissance
                    ? "^{\(signe)\(argument.latex)}"
                    : "_{\(signe)\(argument.latex)}"
                suivant = argument.suivant
                continue
            }
            // « f de x », ou « f(x) » que le moteur a écrit tel quel : application.
            let argumente = symbole.genre == .lien || (symbole.genre == .ouvrante && symbole.colle)
            if applique, argumente, estLettrePrimaire(latex) {
                let depart = symbole.genre == .lien ? suivant + 1 : suivant
                guard let argument = DictMathAtom.lireAtome(passage, depart) else { break }
                latex += symbole.genre == .lien ? "\\left(\(argument.latex)\\right)" : argument.latex
                suivant = argument.suivant
                continue
            }
            break
        }

        return DictAtome(latex: latex, suivant: suivant)
    }

    /// Le décalage d'une récurrence appartient à l'indice — `lireDecalage`.
    static func lireDecalage(_ passage: [DictSymbole], _ position: Int, _ latex: String) -> DictAtome? {
        guard let indice = indiceFinal(latex), DictMathLexicon.indices.contains(indice) else { return nil }
        guard position < passage.count else { return nil }

        let operateur = passage[position]
        guard operateur.genre == .binaire, operateur.latex == "+" || operateur.latex == "-" else { return nil }
        if !operateur.ponctuation.isEmpty { return nil }
        guard position + 1 < passage.count else { return nil }

        let decalage = passage[position + 1]
        guard decalage.genre == .operande, estChiffres(decalage.latex),
              let nombre = Int(decalage.latex), nombre <= DictMathLexicon.decalageMax else { return nil }

        let conclut = position + 2 >= passage.count
            && passage[0..<position].contains(where: { $0.genre == .relation })
        if conclut { return nil }

        let rendu = String(latex.dropLast(indice.count + 3))
            + "_{\(indice)\(operateur.latex)\(decalage.latex)}"
        return DictAtome(latex: rendu, suivant: position + 2)
    }

    /// Intégrale, somme, produit et limite, avec leurs bornes dictées.
    static func lireGrandOperateur(_ passage: [DictSymbole], _ depart: Int) -> DictAtome? {
        let symbole = passage[depart]
        var position = depart + 1
        var bas = ""
        var haut = ""

        // Une locution comme « intégrale de » a déjà consommé son « de ».
        if position < passage.count, passage[position].genre == .lien { position += 1 }
        let finDeBorne: (DictSymbole) -> Bool = { $0.genre == .borne || $0.genre == .lien }

        if symbole.latex == "\\lim" {
            let condition = lireSuite(passage, position, finDeBorne, applique: false)
            bas = condition.latex
            position = condition.suivant
        } else {
            let debut = lireSuite(passage, position, finDeBorne, applique: false)
            bas = debut.latex
            position = debut.suivant
            if position < passage.count, passage[position].genre == .borne {
                let fin = lireSuite(passage, position + 1, { $0.genre == .lien }, applique: false)
                haut = fin.latex
                position = fin.suivant
            }
        }

        if position < passage.count, passage[position].genre == .lien { position += 1 }

        // Le corps court jusqu'à la différentielle ou la fin du passage.
        let corps = lireSuite(passage, position, { $0.genre == .differentielle })
        var latex = symbole.latex
        if !bas.isEmpty { latex += "_{\(bas)}" }
        if !haut.isEmpty { latex += "^{\(haut)}" }
        if !corps.latex.isEmpty { latex += " \(corps.latex)" }
        position = corps.suivant

        if position < passage.count, passage[position].genre == .differentielle {
            latex += passage[position].latex
            position += 1
        }
        return DictAtome(latex: latex, suivant: position)
    }

    /// Une valeur qui se termine par un indice d'une seule lettre : uₙ, vₖ.
    static func indiceFinal(_ latex: String) -> String? {
        guard latex.hasSuffix("}"), latex.count >= 4 else { return nil }
        let caracteres = Array(latex)
        guard caracteres[caracteres.count - 4] == "_",
              caracteres[caracteres.count - 3] == "{",
              caracteres[caracteres.count - 1] == "}" else { return nil }
        let lettre = caracteres[caracteres.count - 2]
        guard let scalaire = lettre.unicodeScalars.first, (0x61...0x7A).contains(scalaire.value) else { return nil }
        return String(lettre)
    }

    /// Une chaîne n'est faite que de chiffres — `^\d+$`.
    static func estChiffres(_ texte: String) -> Bool {
        !texte.isEmpty && texte.allSatisfy { $0.isASCII && $0.isNumber }
    }

    /// Une valeur d'une seule lettre, suivie au plus d'apostrophes — `^[a-z]'*$`.
    static func estLettrePrimaire(_ texte: String) -> Bool {
        let caracteres = Array(texte)
        guard let premier = caracteres.first, let scalaire = premier.unicodeScalars.first,
              (0x61...0x7A).contains(scalaire.value) else { return false }
        return caracteres.dropFirst().allSatisfy { $0 == "'" }
    }
}
