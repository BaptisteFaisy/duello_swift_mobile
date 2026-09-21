//
//  DictMathWordReader.swift
//  Duello
//
//  Portage de `src/utils/speechMath.ts` : lecture d'un mot isolé (`lireMot`),
//  avec ses formes soudées (`x²`, `vn`, `2x`) et l'ambiguïté « un »/uₙ.
//
//  Cible : iOS 16. Aucune dépendance externe.
//

import Foundation

/// Lecture d'un mot vers un symbole — `lireMot` de `speechMath.ts`.
enum DictMathWordReader {
    /// Lit un mot et lui donne son genre et son rendu.
    static func lireMot(_ mot: DictMot, precedent: DictMot?) -> DictSymbole {
        if let symbole = DictMathLexicon.symboles[mot.cle] {
            return DictMathSymbole.symboleDe(mot, symbole)
        }
        if DictMathSymbole.estNombre(mot.cle) {
            return DictMathSymbole.operande(mot.cle.replacingOccurrences(of: ",", with: "."), mot)
        }
        if DictMathLexicon.differentielles.contains(mot.cle) {
            return DictMathSymbole.differentielle(mot)
        }
        if estInconnue(mot, precedent: precedent) {
            return DictMathSymbole.operande(mot.noyau, mot)
        }
        // Seul « à » accentué borne une intégrale : « a » est une inconnue ou le
        // verbe avoir, et le confondre avec une borne effacerait un mot.
        if mot.minuscule == "à" {
            return DictMathSymbole.symboleDe(mot, (.borne, "", false))
        }
        if let nombre = DictMathLexicon.nombres[mot.cle] {
            return DictMathSymbole.operande(nombre, mot)
        }
        if let grecque = DictMathLexicon.lettresGrecques[mot.cle] {
            return DictMathSymbole.operande(grecque, mot)
        }
        if let ensemble = DictMathLexicon.ensembles[mot.cle] {
            return DictMathSymbole.operande(ensemble, mot)
        }
        if let fonction = DictMathLexicon.fonctions[mot.cle] {
            return DictMathSymbole.symboleDe(mot, (.fonction, fonction, true))
        }
        if let connu = DictMathLexicon.mots[mot.cle] {
            return DictMathSymbole.symboleDe(mot, connu)
        }
        return lireMotForme(mot)
    }

    /// Formes que le moteur écrit d'un bloc : `x²`, `vn`, `2x`.
    static func lireMotForme(_ mot: DictMot) -> DictSymbole {
        if let puissance = puissanceSoudee(mot.noyau) {
            return DictMathSymbole.operande(puissance, mot, fort: true)
        }
        if let suite = suiteSoudee(mot) {
            return DictMathSymbole.operande(suite, mot, fort: true)
        }
        if let facteur = facteurSoude(mot) {
            return DictMathSymbole.operande(facteur, mot)
        }
        return DictMathSymbole.symboleDe(mot, (.mot, "", false))
    }

    /// Une lettre seule est une inconnue, sauf quand le français en fait un mot.
    static func estInconnue(_ mot: DictMot, precedent: DictMot?) -> Bool {
        let caracteres = Array(mot.minuscule)
        guard caracteres.count == 1 else { return false }
        guard let scalaire = caracteres[0].unicodeScalars.first,
              (0x61...0x7A).contains(scalaire.value) else { return false }
        // « à » porte son accent : c'est une borne, pas la variable a.
        if mot.minuscule != mot.cle { return false }
        if mot.cle == "a" || mot.cle == "y" {
            guard let precedent else { return true }
            return !DictMathLexicon.pronoms.contains(precedent.cle)
        }
        return true
    }

    /// « vn », « uk » : une suite que le moteur a rendue d'un seul tenant.
    static func suiteSoudee(_ mot: DictMot) -> String? {
        let caracteres = Array(mot.minuscule)
        guard caracteres.count == 2,
              estMinuscule(caracteres[0]), estMinuscule(caracteres[1]) else { return nil }
        if DictMathLexicon.faussesSuites.contains(mot.cle) { return nil }
        guard DictMathLexicon.porteuses.contains(String(caracteres[0])),
              DictMathLexicon.indices.contains(String(caracteres[1])) else { return nil }
        let porteur = mot.noyau.first.map { String($0) } ?? String(caracteres[0])
        return "\(porteur)_{\(caracteres[1])}"
    }

    /// « x² » : le moteur a déjà posé l'exposant, il reste à le structurer.
    static func puissanceSoudee(_ noyau: String) -> String? {
        let caracteres = Array(noyau)
        guard caracteres.count == 2 else { return nil }
        guard let scalaire = caracteres[0].unicodeScalars.first, estLettreOuGrec(scalaire) else { return nil }
        switch caracteres[1] {
        case "²": return "\(caracteres[0])^{2}"
        case "³": return "\(caracteres[0])^{3}"
        default: return nil
        }
    }

    /// « 2x » : le facteur et l'inconnue sont revenus soudés.
    static func facteurSoude(_ mot: DictMot) -> String? {
        let caracteres = Array(mot.minuscule)
        guard caracteres.count >= 2 else { return nil }
        let chiffres = caracteres.prefix { $0.isASCII && $0.isNumber }
        guard !chiffres.isEmpty, chiffres.count == caracteres.count - 1,
              estMinuscule(caracteres[caracteres.count - 1]) else { return nil }
        let inconnue = mot.noyau.last.map { String($0) } ?? String(caracteres[caracteres.count - 1])
        return String(chiffres) + inconnue
    }

    /// Le caractère est-il une lettre ASCII minuscule ?
    static func estMinuscule(_ caractere: Character) -> Bool {
        guard let scalaire = caractere.unicodeScalars.first else { return false }
        return (0x61...0x7A).contains(scalaire.value)
    }

    /// Lettre ASCII ou grecque minuscule — `[A-Za-zα-ω]` de la source.
    static func estLettreOuGrec(_ scalaire: Unicode.Scalar) -> Bool {
        switch scalaire.value {
        case 0x41...0x5A, 0x61...0x7A, 0x3B1...0x3C9:
            return true
        default:
            return false
        }
    }
}
