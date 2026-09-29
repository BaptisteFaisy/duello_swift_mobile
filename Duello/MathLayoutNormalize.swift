//
//  MathLayoutNormalize.swift
//  Duello
//
//  Port de `src/utils/mathLayout.ts` (RN) — `normalizeMathText` : remet en
//  notation mathématique ce que l'OCR a mis à plat.
//
//  Volontairement conservateur : une réponse de colle mélange du français et des
//  formules, et abîmer la prose coûterait plus cher que laisser un `<=` en clair.
//  On ne touche donc qu'aux raccourcis ASCII sans ambiguïté.
//
//  Cible : iOS 16. Aucune dépendance externe.
//

import Foundation

extension MathLayout {

    /// `SUPERSCRIPT_DIGITS` de la source.
    static let superscriptDigits = "⁰¹²³⁴⁵⁶⁷⁸⁹"
    /// `SUBSCRIPT_DIGITS` de la source.
    static let subscriptDigits = "₀₁₂₃₄₅₆₇₈₉"

    /// `normalizeMathText` : notation mathématique d'un texte OCR.
    ///
    /// Les exposants et indices se lisent en entier : `x^12` vaut x¹², pas x¹2.
    static func normalizeMathText(_ raw: String) -> String {
        var text = raw
        text = StmtRegex.replaceAll("<\\s*=\\s*>", in: text, template: "⇔")
        text = StmtRegex.replaceAll("=\\s*>", in: text, template: "⇒")
        text = StmtRegex.replaceAll("<\\s*=", in: text, template: "≤")
        text = StmtRegex.replaceAll(">\\s*=", in: text, template: "≥")
        text = StmtRegex.replaceAll("!=|=/=", in: text, template: "≠")
        text = StmtRegex.replaceAll("-{1,2}>", in: text, template: "→")
        text = StmtRegex.replaceAll("\\+/-|\\+-", in: text, template: "±")
        text = StmtRegex.replaceAll(
            "\\bsqrt\\s*\\(", in: text, options: [.caseInsensitive], template: "√(")
        text = StmtRegex.replaceAll("\\bpi\\b", in: text, template: "π")
        text = StmtRegex.replaceAll(
            "\\b(?:infty|infini)\\b", in: text, options: [.caseInsensitive], template: "∞")
        text = StmtRegex.replaceAll(
            "([0-9a-zA-Z)\\]])\\s*\\*\\s*([0-9a-zA-Z(\\[])", in: text, template: "$1×$2")
        text = StmtRegex.replaceAll("\\^\\(?-\\s*1\\)?", in: text, template: "⁻¹")
        text = StmtRegex.replaceAll("\\^T\\b", in: text, template: "ᵀ")
        text = StmtRegex.replaceAll("\\^n\\b", in: text, template: "ⁿ")
        text = StmtRegex.replaceMatches("\\^\\(?(\\d+)\\)?", in: text) { match, source in
            enChiffres(source.substring(with: match.range(at: 1)), superscriptDigits)
        }
        text = StmtRegex.replaceMatches("_\\(?(\\d+)\\)?", in: text) { match, source in
            enChiffres(source.substring(with: match.range(at: 1)), subscriptDigits)
        }
        text = StmtRegex.replaceAll("_n\\b", in: text, template: "ₙ")
        text = StmtRegex.replaceAll("_k\\b", in: text, template: "ₖ")
        text = StmtRegex.replaceAll("_i\\b", in: text, template: "ᵢ")
        text = StmtRegex.replaceAll(
            "[ \\t]+$", in: text, options: [.anchorsMatchLines], template: "")
        text = StmtRegex.replaceAll("\\n{3,}", in: text, template: "\n\n")
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// `enChiffres` : chaque chiffre du groupe prend sa forme Unicode.
    static func enChiffres(_ digits: String, _ table: String) -> String {
        let tableChars = Array(table)
        return digits.compactMap { caractere in
            guard let valeur = caractere.wholeNumberValue, valeur < tableChars.count else {
                return nil
            }
            return String(tableChars[valeur])
        }.joined()
    }
}
