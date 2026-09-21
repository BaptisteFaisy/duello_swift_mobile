//
//  DictMathParser.swift
//  Duello
//
//  Portage de `src/utils/speechMath.ts` : point d'entrée `spokenMathToLatex`.
//
//  Dictée d'une formule : du français parlé vers LaTeX. Le moteur rend des mots
//  — « x au carré plus un égale zéro ». Ce module relit cette phrase et n'en
//  réécrit que les passages réellement mathématiques, en `$...$` :
//  `$x^{2} + 1 = 0$`. La prose est restituée caractère pour caractère.
//
//  Aucun module natif ici : la conversion est testable en isolation.
//
//  Cible : iOS 16. Aucune dépendance externe.
//

import Foundation

/// Conversion d'une phrase dictée en LaTeX — `spokenMathToLatex` de la source.
enum DictMathParser {
    /// Convertit les formules dictées d'une phrase française en LaTeX.
    ///
    /// Rend la phrase inchangée quand elle ne contient aucune formule : c'est le
    /// cas le plus fréquent, et le plus important à ne pas abîmer.
    static func spokenToLatex(_ spoken: String) -> String {
        let phrase = spoken.trimmingCharacters(in: .whitespacesAndNewlines)
        if phrase.isEmpty { return spoken }

        let symboles = DictMathAnalyzer.analyser(DictMathLexer.decouper(phrase))
        var sorties: [(texte: String, colle: Bool)] = []
        var passage: [DictSymbole] = []

        for symbole in symboles {
            if symbole.genre == .mot {
                vider(&passage, &sorties)
                sorties.append((symbole.brut, symbole.colle))
                continue
            }
            passage.append(symbole)
            // La ponctuation ferme la formule : « x plus 1, donc… » s'arrête à la virgule.
            if !symbole.ponctuation.isEmpty { vider(&passage, &sorties) }
        }
        vider(&passage, &sorties)
        return assembler(sorties)
    }

    /// Convertit le passage courant et l'ajoute aux sorties, ou le restitue tel quel.
    static func vider(_ passage: inout [DictSymbole], _ sorties: inout [(texte: String, colle: Bool)]) {
        if passage.isEmpty { return }

        let parts = DictMathFormula.elaguer(passage)
        let latex = DictMathFormula.estFormule(parts.formule) ? rendre(parts.formule) : ""
        if latex.isEmpty {
            sorties.append((proseDe(passage), passage[0].colle))
            passage = []
            return
        }

        // Seul le dernier symbole d'un passage peut porter une ponctuation : elle
        // suit donc la formule quand rien ne la suit.
        let ponctuation = parts.apres.isEmpty ? parts.formule[parts.formule.count - 1].ponctuation : ""
        if !parts.avant.isEmpty { sorties.append((proseDe(parts.avant), parts.avant[0].colle)) }
        sorties.append(("$\(latex)$\(ponctuation)", parts.formule[0].colle))
        if !parts.apres.isEmpty { sorties.append((proseDe(parts.apres), parts.apres[0].colle)) }
        passage = []
    }

    /// Rassemble les segments en respectant les espaces d'origine.
    static func assembler(_ sorties: [(texte: String, colle: Bool)]) -> String {
        var sortie = ""
        for (index, piece) in sorties.enumerated() {
            sortie += (index > 0 && !piece.colle) ? " \(piece.texte)" : piece.texte
        }
        return sortie
    }

    /// Rend un passage en LaTeX, ou une chaîne vide s'il ne produit rien.
    static func rendre(_ passage: [DictSymbole]) -> String {
        DictMathSeries.lireSuite(passage, 0, { _ in false }).latex
            .trimmingCharacters(in: .whitespaces)
    }

    /// Restitue le passage tel qu'il a été entendu, symboles recollés compris.
    static func proseDe(_ passage: [DictSymbole]) -> String {
        var sortie = ""
        for (index, symbole) in passage.enumerated() {
            sortie += (index > 0 && symbole.colle) ? symbole.brut : " \(symbole.brut)"
        }
        while sortie.hasPrefix(" ") { sortie.removeFirst() }
        return sortie
    }
}
