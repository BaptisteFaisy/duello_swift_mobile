import Foundation

/// Lecture structurée d'une expression LaTeX : repérage des commandes, des
/// groupes `{…}` imbriqués et des environnements `\begin`/`\end`. Élargis de
/// `private` à `internal` parce que lus par `LatexToUnicodeRendering` (et
/// `LatexToUnicodeMatrix`) — aucun membre n'est renommé.
extension LatexToUnicode {
    // MARK: Lecture structurée

    static func estEspace(_ c: Character) -> Bool {
        c == " " || c == "\t" || c == "\n" || c == "\r"
    }

    /// Lit `{...}` en respectant l'imbrication, ou le seul caractère qui suit.
    static func lireGroupe(_ latex: [Character], _ depart: Int) -> (contenu: String, suivant: Int) {
        var index = depart
        while index < latex.count && estEspace(latex[index]) { index += 1 }
        guard index < latex.count else { return ("", index) }

        if latex[index] != "{" {
            // `x^2` ou `x^\alpha` : l'argument est le caractère, ou la commande.
            if latex[index] == "\\" {
                let suite = String(latex[index...])
                if let commande = lireCommande(suite) {
                    return (commande, index + commande.count)
                }
            }
            return (String(latex[index]), index + 1)
        }

        var profondeur = 0
        var position = index
        while position < latex.count {
            let c = latex[position]
            if c == "\\" {
                position += 2
                continue
            }
            if c == "{" { profondeur += 1 }
            if c == "}" {
                profondeur -= 1
                if profondeur == 0 {
                    return (String(latex[(index + 1)..<position]), position + 1)
                }
            }
            position += 1
        }
        // Accolade jamais refermée : on prend le reste plutôt que d'abandonner.
        return (String(latex[(index + 1)...]), latex.count)
    }

    /// `\begin{...}` ou `\end{...}` : lit le nom entre accolades.
    static func lireNomEnvironnement(_ latex: [Character], _ apres: Int) -> (nom: String, suivant: Int) {
        let groupe = lireGroupe(latex, apres)
        return (groupe.contenu.trimmingCharacters(in: .whitespacesAndNewlines), groupe.suivant)
    }

    /// Trouve la fermeture d'un environnement, y compris imbriqué.
    static func lireEnvironnement(_ latex: [Character], _ depart: Int, _ nomRecherche: String) -> (contenu: String, suivant: Int)? {
        var profondeur = 1
        var index = depart
        while index < latex.count {
            guard latex[index] == "\\" else { index += 1; continue }
            let suite = String(latex[index...])
            guard suite.hasPrefix("\\begin") || suite.hasPrefix("\\end") else { index += 2; continue }
            let estDebut = suite.hasPrefix("\\begin")
            let apresMot = index + (estDebut ? 6 : 4)
            let (nom, suivant) = lireNomEnvironnement(latex, apresMot)
            if nom == nomRecherche {
                profondeur += estDebut ? 1 : -1
                if profondeur == 0 {
                    return (String(latex[depart..<index]), suivant)
                }
            }
            index = suivant
        }
        return nil
    }

    /// `\frac{a}{b}` : lit une commande après une position donnée.
    static func lireCommande(_ suite: String) -> String? {
        guard suite.hasPrefix("\\") else { return nil }
        let chars = Array(suite)
        guard chars.count > 1 else { return nil }
        var fin = 1
        while fin < chars.count, chars[fin].isLetter, chars[fin].isASCII { fin += 1 }
        if fin > 1 { return String(chars[0..<fin]) }
        return String(chars[0...1])
    }
}
