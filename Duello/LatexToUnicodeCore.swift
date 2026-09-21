import Foundation

/// LaTeX vers notation mathématique lisible — port fidèle de
/// `src/utils/latexToUnicode.ts` de l'app Expo.
///
/// La réponse d'un duel se rédige dans un champ de texte, et un champ de texte
/// n'affiche pas de math composée : `$\int_{0}^{1} x^{2}\,dx$` y reste du code.
/// Ce module rend la même formule en caractères réels — `∫₀¹ x² dx` — comme le
/// fait l'app Expo sur l'écran du défi (`MathStatementText` compose les mêmes
/// conversions). Ce qu'Unicode ne sait pas empiler — fraction, matrice — est
/// rendu en ligne (`(x + 1)/2`) plutôt que laissé en LaTeX brut.
///
/// Découpage en modules (aucun type ni membre renommé) : ce fichier déclare le
/// type `LatexToUnicode` et son point d'entrée ; les tables de correspondance
/// vivent dans `LatexToUnicodeTables`, les exposants/indices dans
/// `LatexToUnicodeScripts`, la lecture structurée dans `LatexToUnicodeParsing`,
/// les matrices dans `LatexToUnicodeMatrix`, la normalisation dans
/// `LatexToUnicodeNormalization` et le rendu d'une expression dans
/// `LatexToUnicodeRendering`.
enum LatexToUnicode {
    /// Remplace chaque formule LaTeX d'un texte par sa notation mathématique.
    /// La prose autour n'est pas touchée, et le contenu des blocs de code
    /// Markdown reste strictement identique (transcriptions photo).
    static func toUnicodeMath(_ texte: String) -> String {
        var rendu = ""
        var position = texte.startIndex

        for range in codeBlockRanges(in: texte) {
            rendu += convertirHorsBlocsDeCode(String(texte[position..<range.lowerBound]))
            rendu += String(texte[range])
            position = range.upperBound
        }
        rendu += convertirHorsBlocsDeCode(String(texte[position...]))
        return rendu
    }

    // MARK: Conversion hors blocs de code

    /// Les délimiteurs `$`, `$$`, `\( \)` et `\[ \]` encadrent les formules.
    private static let formuleRegex = try! NSRegularExpression(
        pattern: "\\$\\$([\\s\\S]*?)\\$\\$|\\\\\\[([\\s\\S]*?)\\\\\\]|\\\\\\(([\\s\\S]*?)\\\\\\)|\\$([^\\$]*)\\$"
    )

    private static func convertirHorsBlocsDeCode(_ texte: String) -> String {
        let texteNormalise = normaliserGlyphesPrivesPdf(texte)

        if !texteNormalise.contains("$") && !contientLatexNonDelimite(texteNormalise) {
            return texteNormalise
        }

        var avecFormulesConverties = ""
        var position = texteNormalise.startIndex
        let full = NSRange(texteNormalise.startIndex..., in: texteNormalise)
        for match in formuleRegex.matches(in: texteNormalise, range: full) {
            guard let matchRange = Range(match.range, in: texteNormalise) else { continue }
            avecFormulesConverties += String(texteNormalise[position..<matchRange.lowerBound])
            // Groupes : 1 = $$…$$, 2 = \[…\], 3 = \(…\), 4 = $…$
            var formule = ""
            for group in 1...4 {
                let ns = match.range(at: group)
                if ns.location != NSNotFound, let range = Range(ns, in: texteNormalise) {
                    formule = String(texteNormalise[range])
                    break
                }
            }
            avecFormulesConverties += nettoyerFormuleConvertie(convertirExpression(formule))
            position = matchRange.upperBound
        }
        avecFormulesConverties += String(texteNormalise[position...])

        if !contientLatexNonDelimite(avecFormulesConverties) {
            return avecFormulesConverties
        }

        // Dans les banques historiques, `ℝ \ {0}` désigne une différence
        // d'ensembles et non l'espacement LaTeX `\ `. On rend le signe.
        let latexNormalise = avecFormulesConverties.replacingOccurrences(
            of: "\\\\\\s+(?=\\{)",
            with: "\\\\setminus ",
            options: .regularExpression
        )
        return convertirExpression(latexNormalise, preserverAccoladesLitterales: true)
    }
}
